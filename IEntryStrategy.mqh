#ifndef __IENTRYSTRATEGY_MQH__
#define __IENTRYSTRATEGY_MQH__

#include "TradeEntity.mqh"

// Interfaz para estrategias de entrada
class IEntryStrategy
  {
public:
   // Inicializa la estrategia (si es necesario)
   virtual void Init() = 0;
   virtual string Id() = 0;
   virtual int Priority() = 0;
   virtual bool Enabled() = 0;
   virtual bool TryGeneratePlan(const string symbol, TradeEntity &outPlan, double &outScore) = 0;
   
  };

#endif // __IENTRYSTRATEGY_MQH__
