#ifndef __STRATEGYREGISTRY_MQH__
#define __STRATEGYREGISTRY_MQH__

#include <Arrays\ArrayObj.mqh>
#include <Object.mqh>
#include "IEntryStrategy.mqh"

class StrategyRegistry : public CObject
{
private:
   CArrayObj m_strategies;

public:
   StrategyRegistry()
     {
       m_strategies.Clear();
     }

   virtual ~StrategyRegistry()
     {
       ClearAndDelete();
     }

   void Add(IEntryStrategy *strategy)
     {
       if(strategy == NULL)
          return;
       m_strategies.Add(strategy);
     }

   int Total()
     {
       return m_strategies.Total();
     }

   IEntryStrategy* At(int index)
     {
       if(index < 0 || index >= m_strategies.Total())
          return NULL;
       return (IEntryStrategy*)m_strategies.At(index);
     }

   void ClearAndDelete()
     {
       for(int i = m_strategies.Total() - 1; i >= 0; i--)
         {
           IEntryStrategy *strategy = (IEntryStrategy*)m_strategies.At(i);
           delete strategy;
         }
       m_strategies.Clear();
     }

   virtual void Clear() {}
};

#endif // __STRATEGYREGISTRY_MQH__
