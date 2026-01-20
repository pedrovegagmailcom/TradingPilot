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

   bool SelectBestPlan(const string symbol, TradeEntity* &outPlan)
     {
       outPlan = NULL;

       if(m_tradeManager != NULL && m_tradeManager.HasActiveTradeBySymbol(symbol))
         {
           Print("PortfolioSelector: Trade activo para ", symbol, ". No se selecciona plan.");
           return false;
         }

       if(m_registry == NULL || m_registry.Total() == 0)
         {
           Print("PortfolioSelector: Sin estrategias registradas para ", symbol);
           return false;
         }

       double bestScore = -1.0e308;
       int bestPriority = -2147483648;
       string bestStrategyId = "";

       for(int i = 0; i < m_registry.Total(); i++)
         {
           IEntryStrategy *strategy = m_registry.At(i);
           if(strategy == NULL)
              continue;

           if(!strategy.Enabled())
             {
               Print("PortfolioSelector: Estrategia ", strategy.Id(), " deshabilitada para ", symbol);
               continue;
             }

           TradeEntity *candidate = new TradeEntity(symbol, ORDER_TYPE_BUY, strategy.Id());
           double score = 0.0;

           Print("PortfolioSelector: Evaluando estrategia ", strategy.Id(), " para ", symbol);

           if(!strategy.TryGeneratePlan(symbol, candidate, score))
             {
               Print("PortfolioSelector: Estrategia ", strategy.Id(), " descartada: sin plan para ", symbol);
               delete candidate;
               continue;
             }

           Print("PortfolioSelector: Estrategia ", strategy.Id(), " score=", DoubleToString(score, 2));

           bool betterScore = (score > bestScore);
           bool tiePriority = (score == bestScore && strategy.Priority() > bestPriority);

           if(betterScore || tiePriority)
             {
               if(outPlan != NULL)
                  delete outPlan;

               outPlan = candidate;
               bestScore = score;
               bestPriority = strategy.Priority();
               bestStrategyId = strategy.Id();
               Print("PortfolioSelector: Nueva ganadora ", bestStrategyId, " score=", DoubleToString(bestScore, 2), " priority=", bestPriority);
             }
           else
             {
               Print("PortfolioSelector: Estrategia ", strategy.Id(), " descartada por score/prioridad. Mejor actual: ", bestStrategyId);
               delete candidate;
             }
         }

       if(outPlan == NULL)
         {
           Print("PortfolioSelector: Ninguna estrategia generó plan para ", symbol);
           return false;
         }

       Print("PortfolioSelector: Ganadora final ", outPlan.strategyName, " para ", symbol, " score=", DoubleToString(bestScore, 2));
       return true;
     }

   virtual void Clear() {}
};

#endif // __PORTFOLIOSELECTOR_MQH__
