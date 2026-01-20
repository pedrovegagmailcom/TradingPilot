#ifndef __DUMMYENTRYSTRATEGY_MQH__
#define __DUMMYENTRYSTRATEGY_MQH__

#include "IEntryStrategy.mqh"

class DummyEntryStrategy : public IEntryStrategy
{
private:
   bool m_enabled;

public:
   DummyEntryStrategy(bool enabled=false)
   : m_enabled(enabled)
   {
   }

   virtual void Init()
   {
      Print("DummyEntryStrategy Init");
   }

   virtual string Id()
   {
      return "DummyEntry";
   }

   virtual int Priority()
   {
      return 1;
   }

   virtual bool Enabled()
   {
      return m_enabled;
   }

   virtual bool TryGeneratePlan(const string symbol, TradeEntity &outPlan, double &outScore)
   {
      if(!m_enabled)
         return false;

      outPlan.symbol = symbol;
      outPlan.type = ORDER_TYPE_BUY;
      outPlan.strategyName = Id();

      TradeLeg *leg = new TradeLeg(0.01, 5, 10, 0);
      outPlan.legs.Add(leg);

      outScore = 10.0;
      return true;
   }

   virtual void GetSignal()
   {
      Print("DummyEntryStrategy: Señal dummy generada.");
   }
};

#endif // __DUMMYENTRYSTRATEGY_MQH__
