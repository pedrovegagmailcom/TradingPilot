#ifndef __RISKMANAGER_MQH__
#define __RISKMANAGER_MQH__

#include "IRiskManager.mqh"

class RiskManager : public IRiskManager
  {
private:
   double m_max_risk_per_trade_pct;
   double m_min_sl_points;

   RiskDecision Reject(const string reason)
     {
      RiskDecision decision;
      decision.allowed = false;
      decision.reason = reason;
      return decision;
     }

public:
   RiskManager(const double maxRiskPerTradePct=0.5, const double minSlPoints=10.0)
     {
      m_max_risk_per_trade_pct = maxRiskPerTradePct;
      m_min_sl_points = minSlPoints;
     }

   virtual void Init() { }

   virtual RiskDecision Evaluate(const string symbol,
                                 const ENUM_ORDER_TYPE orderType,
                                 const double entryPrice,
                                 const double stopLossPrice,
                                 const string strategyId)
     {
      (void)strategyId;
      if(stopLossPrice <= 0.0)
         return Reject("Invalid stop-loss price");
      if(entryPrice <= 0.0)
         return Reject("Invalid entry price");

      if(orderType == ORDER_TYPE_BUY && stopLossPrice >= entryPrice)
         return Reject("Invalid stop-loss direction for BUY");
      if(orderType == ORDER_TYPE_SELL && stopLossPrice <= entryPrice)
         return Reject("Invalid stop-loss direction for SELL");

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return Reject("Invalid symbol properties (point/ticksize/tickvalue)");

      double sl_points = MathAbs(entryPrice - stopLossPrice) / point;
      if(sl_points < m_min_sl_points)
        {
         string reason = StringFormat("Stop-loss distance too small (sl_points=%.2f, min=%.2f)",
                                      sl_points, m_min_sl_points);
         return Reject(reason);
        }

      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickValue <= 0.0 || tickSize <= 0.0)
         return Reject("Invalid symbol properties (point/ticksize/tickvalue)");

      double money_per_point_per_lot = (tickValue / tickSize) * point;
      if(money_per_point_per_lot <= 0.0)
         return Reject("Invalid money per point per lot");

      double risk_per_lot = sl_points * money_per_point_per_lot;
      if(risk_per_lot <= 0.0)
         return Reject("Invalid risk per lot");

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0)
         return Reject("Invalid equity");
      if(m_max_risk_per_trade_pct <= 0.0)
         return Reject("MaxRiskPerTradePct inválido");

      double risk_money_target = equity * (m_max_risk_per_trade_pct / 100.0);
      if(risk_money_target <= 0.0)
         return Reject("RiskMoneyTarget inválido");

      double volume_raw = risk_money_target / risk_per_lot;

      double volMin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double volMax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double volStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      int volDigits = (int)SymbolInfoInteger(symbol, SYMBOL_VOLUME_DIGITS);
      if(volStep <= 0.0 || volMax <= 0.0)
         return Reject("Restricciones de volumen inválidas");

      double volume = MathMin(volume_raw, volMax);
      volume = MathFloor(volume / volStep) * volStep;
      volume = NormalizeDouble(volume, volDigits);
      if(volume < volMin)
         return Reject("Volumen menor al mínimo permitido");

      double margin = 0.0;
      if(!OrderCalcMargin(orderType, symbol, volume, entryPrice, margin))
         return Reject("OrderCalcMargin falló");

      double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
      if(freeMargin < margin)
         return Reject("Margin insuficiente");

      double actual_risk_money = volume * risk_per_lot;
      double actual_risk_pct = (actual_risk_money / equity) * 100.0;

      RiskDecision decision;
      decision.allowed = true;
      decision.volume = volume;
      decision.risk_money = actual_risk_money;
      decision.risk_pct = actual_risk_pct;
      decision.reason = "";
      return decision;
     }

   // Legacy: método anterior, usa precio actual para calcular el SL en base a pips.
   virtual double CalculateLotSize(double riskPercent, double stopLossPips)
     {
      string symbol = Symbol();
      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pipSize = point * 10.0;
      double stopLossPrice = price - (stopLossPips * pipSize);
      double previous = m_max_risk_per_trade_pct;
      m_max_risk_per_trade_pct = riskPercent;
      RiskDecision decision = Evaluate(symbol, ORDER_TYPE_BUY, price, stopLossPrice, "legacy");
      m_max_risk_per_trade_pct = previous;
      return decision.volume;
     }

   virtual double GetCloseProfitPercent() override 
   { 
      return 5.0; // Ejemplo: 5% de profit
   }
   
   
  bool ValidateTrade(TradeEntity* entity)
    {
     if(entity == NULL)
        return false;
     double totalRiskMoney = 0.0;
     for(int i = 0; i < entity.legs.Total(); i++)
       {
        TradeLeg* leg = (TradeLeg*)entity.legs.At(i);
        if(leg == NULL)
           continue;
        double entry = (entity.type == ORDER_TYPE_BUY)
           ? SymbolInfoDouble(entity.symbol, SYMBOL_ASK)
           : SymbolInfoDouble(entity.symbol, SYMBOL_BID);
        double point = SymbolInfoDouble(entity.symbol, SYMBOL_POINT);
        double pipSize = point * 10.0;
        double slPrice = (entity.type == ORDER_TYPE_BUY)
           ? entry - (leg.slPips * pipSize)
           : entry + (leg.slPips * pipSize);
        RiskDecision decision = Evaluate(entity.symbol, entity.type, entry, slPrice, entity.strategyName);
        if(!decision.allowed)
           return false;
        leg.lotSize = decision.volume;
        totalRiskMoney += decision.risk_money;
       }
     return (totalRiskMoney > 0.0);
    }
  };

#endif // __RISKMANAGER_MQH__
