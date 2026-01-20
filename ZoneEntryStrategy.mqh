#ifndef __ZONEENTRYSTRATEGY_MQH__
#define __ZONEENTRYSTRATEGY_MQH__

#include "IEntryStrategy.mqh"
#include "ZoneManager.mqh"
#include "ScoreUtils.mqh"

// Estrategia de entrada que revisa si el precio está cerca
// de una "zona de trabajo" sin distinguir si es soporte/resistencia.
class ZoneEntryStrategy : public IEntryStrategy
{
private:
   double m_thresholdPips; // distancia en pips para considerar "zona alcanzada"
   bool m_enabled;

public:
   // Constructor (ej. threshold por defecto = 3 pips)
   ZoneEntryStrategy(double thresholdPips=1.0, bool enabled=true)
   : m_thresholdPips(thresholdPips),
     m_enabled(enabled)
   {
   }

   // ---------------------------------------------------------------
   // Init(): inicialización si es necesario
   // ---------------------------------------------------------------
   virtual void Init()
   {
      Print("ZoneEntryStrategy Init. ThresholdPips = ", m_thresholdPips);
   }

   virtual string Id()
   {
      return "ZoneEntry";
   }

   virtual int Priority()
   {
      return 10;
   }

   virtual bool Enabled()
   {
      return m_enabled;
   }

   virtual bool TryGeneratePlan(const string symbol, TradeEntity &outPlan, double &outScore)
   {
      double currPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double thresholdPoints = m_thresholdPips * pointSize;

      double nearestDistance = -1.0;
      for(int i = 0; i < g_zoneManager.GetZoneCount(); i++)
        {
          SZone *zone = g_zoneManager.GetZoneByIndex(i);
          if(zone == NULL)
             continue;
          double distance = MathAbs(zone.price - currPrice);
          if(nearestDistance < 0.0 || distance < nearestDistance)
             nearestDistance = distance;
        }

      if(nearestDistance < 0.0)
         return false;

      if(nearestDistance > thresholdPoints)
         return false;

      double proximity_norm = 1.0 - (nearestDistance / thresholdPoints);
      double quality01 = Clamp01(proximity_norm);

      TradeLeg* leg1 = new TradeLeg(
         0.01,
         5,
         10,
         0
      );

      TradeLeg* leg2 = new TradeLeg(
         0.01,
         15,
         50,
         0
      );

      outPlan.strategyName = Id();
      outPlan.symbol = symbol;
      outPlan.type = ORDER_TYPE_BUY;
      outPlan.legs.Add(leg1);
      outPlan.legs.Add(leg2);

      outScore = ScorePlan(symbol, quality01, leg1.slPips, leg1.tpPips);
      return true;
   }
};

#endif // __ZONEENTRYSTRATEGY_MQH__
