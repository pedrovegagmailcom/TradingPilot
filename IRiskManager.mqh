#ifndef __IRISKMANAGER_MQH__
#define __IRISKMANAGER_MQH__

#include "TradeEntity.mqh"
#include "RiskDecision.mqh"

// Interfaz para la gestión del riesgo
class IRiskManager
  {
public:
   virtual void Init() = 0;
   // Método principal (nuevo) para evaluar riesgo monetario por trade.
   virtual RiskDecision Evaluate(const string symbol,
                                 const ENUM_ORDER_TYPE orderType,
                                 const double entryPrice,
                                 const double stopLossPrice,
                                 const string strategyId) = 0;
   // Legacy: mantener firma para compatibilidad con código existente.
   // Calcula el tamaño de la posición basado en el porcentaje de riesgo y otros parámetros
   virtual double CalculateLotSize(double riskPercent, double stopLossPips) = 0;
   // Valida si el riesgo actual permite abrir nuevas operaciones
   virtual bool ValidateTrade(TradeEntity* trade) = 0;
   virtual double GetCloseProfitPercent() = 0; 
  };

#endif // __IRISKMANAGER_MQH__
