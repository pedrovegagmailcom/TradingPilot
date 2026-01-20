#ifndef __RISKMANAGER_MQH__
#define __RISKMANAGER_MQH__

#include "IRiskManager.mqh"

class RiskManager : public IRiskManager
  {
  double riskAmount;
public:
   virtual void Init() { }
   virtual double CalculateLotSize(double riskPercent, double stopLossPips)
  {
    // Ejemplo simplificado:
    // Obtenemos el balance actual y el valor del pip para el símbolo
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    // Cálculo básico del valor en riesgo:
    // (balance * riesgo%) / (stopLossPips * (tickValue / tickSize))
    riskAmount = balance * (riskPercent / 100.0);
    double lotSize = riskAmount / (stopLossPips * (tickValue / tickSize));

    // Ajuste para cumplir con las restricciones del símbolo:
    double volMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Si el lote calculado es menor que el mínimo permitido, usar el mínimo
    if(lotSize < volMin)
       lotSize = volMin;
    
    // Ajustar el tamaño de lote al múltiplo del paso permitido
    lotSize = MathFloor(lotSize / volStep) * volStep;
    
    return(lotSize);
  }

   virtual double GetCloseProfitPercent() override 
   { 
      return 5.0; // Ejemplo: 5% de profit
   }
   
   
  bool ValidateTrade(TradeEntity* entity) {
    double totalRisk = 0;
    for(int i=0; i<entity.legs.Total(); i++) {
        TradeLeg* leg = (TradeLeg*)entity.legs.At(i);
        totalRisk += CalculateLotSize(RiskPercent, leg.slPips);
    }
    return (totalRisk <= riskAmount);
}
  };

#endif // __RISKMANAGER_MQH__
