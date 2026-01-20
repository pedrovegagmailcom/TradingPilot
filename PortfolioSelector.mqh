#ifndef __PORTFOLIOSELECTOR_MQH__
#define __PORTFOLIOSELECTOR_MQH__

#include "StrategyRegistry.mqh"
#include "TradeManager.mqh"

class PortfolioSelector : public CObject
{
private:
   StrategyRegistry *m_registry;
   TradeManager *m_tradeManager;

public:
   PortfolioSelector(StrategyRegistry *registry = NULL, TradeManager *tradeManager = NULL)
   : m_registry(registry), m_tradeManager(tradeManager)
   {
   }

   void SetRegistry(StrategyRegistry *registry)
     {
       m_registry = registry;
     }

   void SetTradeManager(TradeManager *tradeManager)
     {
       m_tradeManager = tradeManager;
     }

   bool SelectBestPlan(const string symbol, TradeEntity &outPlan, double &outScore)
     {
       outScore = 0.0;

       if(m_registry == NULL || m_registry.Total() == 0)
         {
           PrintFormat("[Portfolio] sin estrategias para %s", symbol);
           return false;
         }

       double bestScore = -1.0e308;
       int bestPriority = -2147483648;
       string bestStrategyId = "";
       bool hasCandidate = false;

       for(int i = 0; i < m_registry.Total(); i++)
         {
           IEntryStrategy *strategy = m_registry.At(i);
           if(strategy == NULL)
              continue;

           if(!strategy.Enabled())
             {
               PrintFormat("[Portfolio] %s valid=no score=0.00", strategy.Id());
               continue;
             }

           TradeEntity candidate(symbol, ORDER_TYPE_BUY, strategy.Id());
           double score = 0.0;

           bool valid = strategy.TryGeneratePlan(symbol, candidate, score);
           if(!valid)
             {
               PrintFormat("[Portfolio] %s valid=no score=0.00", strategy.Id());
               continue;
             }

           PrintFormat("[Portfolio] %s valid=yes score=%.2f", strategy.Id(), score);

           bool betterScore = (score > bestScore);
           bool tiePriority = (score == bestScore && strategy.Priority() > bestPriority);

           if(betterScore || tiePriority)
             {
               outPlan.CopyFrom(candidate);
               bestScore = score;
               bestPriority = strategy.Priority();
               bestStrategyId = strategy.Id();
               hasCandidate = true;
             }
         }

       if(!hasCandidate)
         {
           PrintFormat("[Portfolio] sin candidato para %s", symbol);
           return false;
         }

       outScore = bestScore;
       PrintFormat("[Portfolio] WINNER %s score=%.2f symbol=%s", bestStrategyId, bestScore, symbol);
       return true;
     }

   virtual void Clear() {}
};

#endif // __PORTFOLIOSELECTOR_MQH__
