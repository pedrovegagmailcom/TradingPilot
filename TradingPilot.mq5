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
#include "RiskDecision.mqh"
#include "TradeExecutor.mqh"

#include "ZoneManager.mqh"
#include "SR_Zone_1D.mqh"


//-------------------------------------------------------------------
// Parámetros de entrada
input double RiskPercent   = 0.5;   // % de riesgo por operación
input double MinSLPoints   = 10.0;  // SL mínimo en puntos
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

double RoundToDigits(const double value, const int digits)
{
   double factor = MathPow(10, digits);
   return MathRound(value * factor) / factor;
}

double CalculateStopLossPrice(const string symbol, const ENUM_ORDER_TYPE type, const double entry, const double slPips)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double pipSize = point * 10.0;
   double offset = slPips * pipSize;
   double sl = (type == ORDER_TYPE_BUY) ? entry - offset : entry + offset;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return RoundToDigits(sl, digits);
}

double CalculateTakeProfitPrice(const string symbol, const ENUM_ORDER_TYPE type, const double entry, const double tpPips)
{
   if(tpPips <= 0.0)
      return 0.0;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double pipSize = point * 10.0;
   double offset = tpPips * pipSize;
   double tp = (type == ORDER_TYPE_BUY) ? entry + offset : entry - offset;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return RoundToDigits(tp, digits);
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

   g_riskManager = new RiskManager(RiskPercent, MinSLPoints);
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
    bool allowed = true;
    double totalApprovedVolume = 0.0;
    double totalRiskMoney = 0.0;
    for(int i = 0; i < newTrade.legs.Total(); i++)
      {
        TradeLeg *leg = (TradeLeg*)newTrade.legs.At(i);
        if(leg == NULL)
           continue;
        double entryPrice = (newTrade.type == ORDER_TYPE_BUY)
           ? SymbolInfoDouble(newTrade.symbol, SYMBOL_ASK)
           : SymbolInfoDouble(newTrade.symbol, SYMBOL_BID);
        double stopLossPrice = CalculateStopLossPrice(newTrade.symbol, newTrade.type, entryPrice, leg.slPips);
        double takeProfitPrice = CalculateTakeProfitPrice(newTrade.symbol, newTrade.type, entryPrice, leg.tpPips);
        leg.slPrice = stopLossPrice;
        leg.tpPrice = takeProfitPrice;
        RiskDecision decision = g_riskManager.Evaluate(newTrade.symbol, newTrade.type, entryPrice, leg.slPrice, newTrade.strategyName);
        double point = SymbolInfoDouble(newTrade.symbol, SYMBOL_POINT);
        double sl_points = (point > 0.0) ? MathAbs(entryPrice - leg.slPrice) / point : 0.0;
        if(!decision.allowed)
          {
           PrintFormat("[Risk][WARN] symbol=%s strategy=%s reason=%s",
                       newTrade.symbol, newTrade.strategyName, decision.reason);
           allowed = false;
           break;
          }
        leg.lotSize = decision.volume;
        totalApprovedVolume += decision.volume;
        totalRiskMoney += decision.risk_money;
        int digits = (int)SymbolInfoInteger(newTrade.symbol, SYMBOL_DIGITS);
        string entryStr = DoubleToString(entryPrice, digits);
        string slStr = DoubleToString(leg.slPrice, digits);
        string tpStr = (leg.tpPrice > 0.0) ? DoubleToString(leg.tpPrice, digits) : "0";
        PrintFormat("[Risk][INFO] symbol=%s strategy=%s entry=%s sl=%s tp=%s sl_points=%.2f volume=%.2f risk_money=%.2f risk_pct=%.2f",
                    newTrade.symbol, newTrade.strategyName, entryStr, slStr, tpStr, sl_points, decision.volume,
                    decision.risk_money, decision.risk_pct);
      }
    if(allowed)
      {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        newTrade.approved_volume = totalApprovedVolume;
        newTrade.approved_risk_money = totalRiskMoney;
        newTrade.approved_risk_pct = (equity > 0.0) ? (totalRiskMoney / equity) * 100.0 : 0.0;
        g_executor.Execute(newTrade);
        g_tradeManager.AddTrade(newTrade);
      }
    else
      {
        delete newTrade;
      }
}
