//#property strict
#include <Trade\Trade.mqh>

#include "ILogger.mqh"
#include "Logger.mqh"

#include "ZoneEntryStrategy.mqh"
#include "DummyEntryStrategy.mqh"
#include "StrategyRegistry.mqh"
#include "PortfolioSelector.mqh"

#include "IPositionManager.mqh"
#include "PositionManager.mqh"

#include "IRiskManager.mqh"
#include "RiskManager.mqh"
#include "TradeExecutor.mqh"

#include "ZoneManager.mqh"
#include "SR_Zone_1D.mqh"


//-------------------------------------------------------------------
// Parámetros de entrada
input double RiskPercent   = 0.5;   // % de riesgo por operación
input double DrawdownLimit = 10.0;  // Límite máximo de drawdown
input bool UseZoneEntry = true;
input bool UseDummyEntry = false;
input bool   UseDoubleBottom = false;// Activar estrategia Doble Suelo
input bool   UseBreakout     = true;// Activar estrategia Breakout (por implementar)
input int    LogFrequency    = 10;  // Frecuencia de log: cada X ticks
input double InpMinScore     = 50.0;

// Variables globales
ILogger          *g_logger;
StrategyRegistry *g_strategyRegistry;
PortfolioSelector *g_portfolioSelector;
IPositionManager *g_positionManager;
IRiskManager     *g_riskManager;
TradeManager     *g_tradeManager;
ZoneManager       *g_zoneManager;
TradeExecutor     *g_executor;

CTrade trade;             // Objeto para enviar órdenes
int    g_tickCounter = 0; // Contador de ticks

int BaseMagic(const string id)
{
   ulong hash = 5381;
   int len = StringLen(id);
   for(int i = 0; i < len; i++)
     {
       hash = ((hash << 5) + hash) + (uchar)StringGetCharacter(id, i);
     }
   int base = 10000 + (int)(hash % 50000);
   return base;
}

//-------------------------------------------------------------------
// Expert initialization function
//-------------------------------------------------------------------
int OnInit()
{
   // Instanciar logger
   g_logger = new Logger();
   g_logger.Init();
   g_logger.Log("TradingPilot inicializado");

   g_tradeManager = new TradeManager();
   g_zoneManager = new ZoneManager();
   g_strategyRegistry = new StrategyRegistry();
   g_portfolioSelector = new PortfolioSelector(g_strategyRegistry, g_tradeManager);

   if(UseZoneEntry)
   {
      IEntryStrategy *zoneStrategy = new ZoneEntryStrategy(1.0, UseZoneEntry); // threshold=3 pips
      zoneStrategy.Init();
      g_strategyRegistry.Add(zoneStrategy);
   }
   if(UseDummyEntry)
   {
      IEntryStrategy *dummyStrategy = new DummyEntryStrategy(UseDummyEntry);
      dummyStrategy.Init();
      g_strategyRegistry.Add(dummyStrategy);
   }
   // Instanciar gestor de posiciones y de riesgo
   g_positionManager = new PositionManager();
   g_positionManager.Init();

   g_riskManager = new RiskManager();
   g_riskManager.Init();
   g_executor = new TradeExecutor();
   
   DetectZonesOnce();

   return(INIT_SUCCEEDED);
}

//-------------------------------------------------------------------
// Expert deinitialization function
//-------------------------------------------------------------------
void OnDeinit(const int reason)
{
   g_logger.Log("TradingPilot finalizando");
   if(g_logger)         { delete g_logger;         g_logger = NULL; }
   if(g_portfolioSelector) { delete g_portfolioSelector; g_portfolioSelector = NULL; }
   if(g_strategyRegistry)
     {
       g_strategyRegistry.ClearAndDelete();
       delete g_strategyRegistry;
       g_strategyRegistry = NULL;
     }
   if(g_positionManager){ delete g_positionManager;g_positionManager = NULL; }
   if(g_riskManager)    { delete g_riskManager;    g_riskManager = NULL; }
   if(g_tradeManager)   { delete g_tradeManager;   g_tradeManager = NULL; }
   if(g_zoneManager)    { delete g_zoneManager;   g_zoneManager = NULL; }
}

//-------------------------------------------------------------------
// Expert tick function
//-------------------------------------------------------------------
void OnTick() {
    // 1. Gestionar posiciones existentes
    g_positionManager.ManagePositions();
    
    // 2. Generar nueva planificación
    if(g_tradeManager.HasActiveTradeBySymbol(_Symbol))
    {
        PrintFormat("[Portfolio] skip %s: active trade", _Symbol);
        return;
    }

    TradeEntity bestPlan;
    double bestScore = 0.0;
    if(!g_portfolioSelector.SelectBestPlan(_Symbol, bestPlan, bestScore))
        return;
    if(bestScore < InpMinScore)
    {
        PrintFormat("[Portfolio] skip %s: score %.2f < min %.2f", _Symbol, bestScore, InpMinScore);
        return;
    }

    TradeEntity* newTrade = new TradeEntity();
    newTrade.CopyFrom(bestPlan);
    newTrade.tradeId = TradeEntity::NextTradeId();
    int baseMagic = BaseMagic(newTrade.strategyName);
    for(int i = 0; i < newTrade.legs.Total(); i++)
      {
        TradeLeg *leg = (TradeLeg*)newTrade.legs.At(i);
        if(leg == NULL)
           continue;
        leg.legIndex = i;
        leg.magic = (long)(baseMagic + i);
        leg.comment = "TP|" + newTrade.strategyName + "|T" + (string)newTrade.tradeId + "|L" + (string)(i + 1);
      }
    if(g_riskManager.ValidateTrade(newTrade))
    {
        g_executor.Execute(newTrade);
        g_tradeManager.AddTrade(newTrade);
    }
    else
    {
        delete newTrade;
    }
}
