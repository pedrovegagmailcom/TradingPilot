#ifndef __POSITIONMANAGER_MQH__
#define __POSITIONMANAGER_MQH__

#include "IPositionManager.mqh"
#include "TradeManager.mqh"
#include "IRiskManager.mqh"
#include <Trade\Trade.mqh>
//#include <Dictionary.mqh> // Necesario para CDictionary (si no está, usar Array)

//---------------------------------------------------------
// PositionManager : Gestiona posiciones por pierna
//---------------------------------------------------------
class PositionManager : public IPositionManager
{
private:
    IRiskManager* m_riskManager;
    CTrade        m_tradeOp;
    CArrayObj   m_legCache; // Cache de piernas activas (ticket -> TradeLeg*)

public:
    PositionManager(IRiskManager* riskMgr = NULL) : m_riskManager(riskMgr) {}

    virtual void Init() { /* ... */ }

    // ----------------------------------------
    // Gestión de posiciones (OnTick)
    // ----------------------------------------
    virtual void ManagePositions()
    {
        for(int i = g_tradeManager.GetTradeCount()-1; i >= 0; i--)
        {
            TradeEntity* te = g_tradeManager.GetTradeByIndex(i);
            if(!te || !te.active) continue;

            bool allLegsClosed = true;
            for(int j = 0; j < te.legs.Total(); j++)
            {
                TradeLeg* leg = (TradeLeg*)te.legs.At(j);
                if(leg.closed) continue;

                // 1. Actualizar trailing stop por pierna
                if(leg.trailingStepPips > 0) 
                    ApplyTrailingStop(te, leg);

                // 2. Verificar cierre por TP/SL
                if(CheckAutoClose(te, leg)) 
                    leg.closed = true;

                // 3. Verificar cierre parcial por beneficio
                //CheckPartialByProfit(te);
                
                if(!leg.closed) allLegsClosed = false;
            }

            if(allLegsClosed) {
                te.active = false;
                g_tradeManager.RemoveTradeByIndex(i);
            }
        }
    }

    // ----------------------------------------
    // Control de entradas duplicadas
    // ----------------------------------------
    virtual bool CanEnterTrade(string symbol, string strategyName)
    {
        return !g_tradeManager.HasActiveTradeBySymbol(symbol);
    }

private:
    // ----------------------------------------
    // Cierre Automático por TP/SL
    // ----------------------------------------
    bool CheckAutoClose(TradeEntity* te, TradeLeg* leg)
    {
        if(!PositionSelectByTicket(leg.ticket)) return false;

        double currPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double tp = PositionGetDouble(POSITION_TP);
        double sl = PositionGetDouble(POSITION_SL);

        if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && currPrice >= tp) ||
           (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && currPrice <= tp) ||
           (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && currPrice <= sl) ||
           (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && currPrice >= sl))
        {
            m_tradeOp.PositionClose(leg.ticket);
            return true;
        }
        return false;
    }
    // ----------------------------------------
    // Trailing Stop Dinámico por Pierna
    // ----------------------------------------
    void ApplyTrailingStop(TradeEntity* te, TradeLeg* leg)
    {
        if(!PositionSelectByTicket(leg.ticket)) return;

        double currPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double point = SymbolInfoDouble(te.symbol, SYMBOL_POINT);

        double newSl = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            ? currPrice - (leg.trailingStepPips * 10 * point)
            : currPrice + (leg.trailingStepPips * 10 * point);

        if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && newSl > sl) ||
           (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && newSl < sl))
        {
            m_tradeOp.PositionModify(leg.ticket, newSl, PositionGetDouble(POSITION_TP));
        }
    }

    // ----------------------------------------
    // Cierre Automático por TP/SL
    // ----------------------------------------
   // PositionManager.mqh
void CheckPartialByProfit(TradeEntity* te)
{
    if(!te || !te.active) return;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double profitPerc = m_riskManager.GetCloseProfitPercent();

    for(int j = 0; j < te.legs.Total(); j++)
    {
        TradeLeg* leg = (TradeLeg*)te.legs.At(j);
        if(leg.closed || !PositionSelectByTicket(leg.ticket)) continue;

        double floatProfit = PositionGetDouble(POSITION_PROFIT);
        double profitRatio = floatProfit / balance * 100.0;

        if(profitRatio >= profitPerc)
        {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double partialVolume = volume / 2.0; // Cerrar la mitad

            if(partialVolume >= SymbolInfoDouble(te.symbol, SYMBOL_VOLUME_MIN))
            {
                if(m_tradeOp.PositionClosePartial(leg.ticket, partialVolume))
                {
                    leg.lotSize -= partialVolume; // Actualizar tamaño restante
                    if(leg.lotSize <= 0) leg.closed = true; // Marcar como cerrada si no queda volumen
                }
            }
        }
    }
}

   // PositionManager.mqh
void ForceClosePosition(TradeEntity* te, int indexInManager)
{
    if(!te || !te.active) return;

    bool allLegsClosed = true;

    for(int j = 0; j < te.legs.Total(); j++)
    {
        TradeLeg* leg = (TradeLeg*)te.legs.At(j);
        if(leg.closed) continue;

        // Cerrar la pierna si está activa
        if(PositionSelectByTicket(leg.ticket))
        {
            double volume = PositionGetDouble(POSITION_VOLUME);
            if(volume > 0)
            {
                if(m_tradeOp.PositionClose(leg.ticket))
                {
                    leg.closed = true;
                }
                else
                {
                    Print("Error cerrando pierna: ", GetLastError());
                    allLegsClosed = false;
                }
            }
        }
    }

    // Si todas las piernas están cerradas, marcar la operación como inactiva
    if(allLegsClosed)
    {
        te.active = false;
        g_tradeManager.RemoveTradeByIndex(indexInManager);
    }
}
};

#endif // __POSITIONMANAGER_MQH__
