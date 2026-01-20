// TradeExecutor.mqh
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Arrays\ArrayObj.mqh>

class TradeExecutor {
private:
    CTrade m_trade;
    
public:
    // Usamos puntero aquí para mantener la semántica actual de propiedad y mutación en ejecución.
    bool Execute(TradeEntity* entity) {
        if(entity == NULL || entity.isExecuted) return false;

        CArrayObj executedLegs;
        for(int i = 0; i < entity.legs.Total(); i++) {
            TradeLeg* leg = (TradeLeg*)entity.legs.At(i);
            string sym = entity.symbol;

            // Validar lote
            double min_lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
            double lot_step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
            leg.lotSize = MathFloor(leg.lotSize / lot_step) * lot_step;
            if(leg.lotSize < min_lot) {
                Print("Lote inválido en pierna ", i);
                return false;
            }

            // Calcular precios
            double price = (entity.type == ORDER_TYPE_BUY) 
                ? SymbolInfoDouble(sym, SYMBOL_ASK) 
                : SymbolInfoDouble(sym, SYMBOL_BID);
                
            double sl = CalculateSL(sym, entity.type, price, leg.slPips);
            double tp = CalculateTP(sym, entity.type, price, leg.tpPips);
            
            double min_stop = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(sym, SYMBOL_POINT);
            if(MathAbs(price - sl) < min_stop || MathAbs(price - tp) < min_stop) {
               Print("Stop demasiado cerca del precio");
               return false;
               }
            m_trade.SetExpertMagicNumber((ulong)leg.magic);
            m_trade.SetComment(leg.comment);
            if(!m_trade.PositionOpen(sym, entity.type, leg.lotSize, price, sl, tp)) {
                Print("Error en pierna ", i, ": ", GetLastError());
                Rollback(executedLegs);
                return false;
            }

            ENUM_POSITION_TYPE posType = (entity.type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            long positionTicket = FindRecentPositionTicket(sym, posType, leg.magic, leg.comment);
            if(positionTicket <= 0)
            {
                Print("Error obteniendo ticket de la posición");
                leg.ticket = 0;
            }
            else
            {
                leg.ticket = positionTicket;
            }
            leg.entryPrice = price;
            PrintFormat("[Exec] opened strategy=%s symbol=%s vol=%.2f magic=%ld comment=%s pos_ticket=%lld",
                        entity.strategyName, sym, leg.lotSize, leg.magic, leg.comment, leg.ticket);

            //executedLegs.Add(leg);
        }

        entity.isExecuted = true;
        entity.active = true;
        return true;
    }

private:
double RoundToDigits(double value, int digits) {
    double factor = MathPow(10, digits);
    return MathRound(value * factor) / factor;
}
double CalculateSL(string sym, ENUM_ORDER_TYPE type, double entry, double pips) {
    double pipSize = SymbolInfoDouble(sym, SYMBOL_POINT) * 10; // 1 pip = 10 puntos
    double offset = pips * pipSize;
    double sl = (type == ORDER_TYPE_BUY) ? entry - offset : entry + offset;
    return RoundToDigits(sl, 5); // Redondear a 5 decimales
}

double CalculateTP(string sym, ENUM_ORDER_TYPE type, double entry, double pips) {
    double pipSize = SymbolInfoDouble(sym, SYMBOL_POINT) * 10;
    double offset = pips * pipSize;
    double tp = (type == ORDER_TYPE_BUY) ? entry + offset : entry - offset;
    return RoundToDigits(tp, 5); // Redondear a 5 decimales
}

    void Rollback(CArrayObj& legs) {
        for(int i = 0; i < legs.Total(); i++) {
            TradeLeg* leg = (TradeLeg*)legs.At(i);
            if(PositionSelectByTicket(leg.ticket)) {
                m_trade.PositionClose(leg.ticket);
            }
        }
    }

    long FindRecentPositionTicket(const string symbol, ENUM_POSITION_TYPE type, long magic, const string comment)
    {
        for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0)
                continue;
            if(!PositionSelectByTicket(ticket))
                continue;
            if(PositionGetString(POSITION_SYMBOL) != symbol)
                continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
                continue;
            if((long)PositionGetInteger(POSITION_MAGIC) != magic)
                continue;
            if(comment != "" && PositionGetString(POSITION_COMMENT) != comment)
                continue;

            return (long)ticket;
        }
        return -1;
    }

    
};
