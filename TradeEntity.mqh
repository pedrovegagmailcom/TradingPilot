#ifndef __TRADEENTITY_MQH__
#define __TRADEENTITY_MQH__

#include <Arrays\ArrayObj.mqh>
#include <Object.mqh>
#include "TradeLeg.mqh"

class TradeEntity : public CObject {
public:
    string    symbol;
    ENUM_ORDER_TYPE type;  // Nuevo
    datetime  entryTime;
    string    strategyName;
    int       tradeId;
    bool      active;
    bool      isExecuted;   // Nuevo
    double    approved_volume;
    double    approved_risk_money;
    double    approved_risk_pct;
    CArrayObj legs;

    TradeEntity() :
        symbol(""), type(ORDER_TYPE_BUY), strategyName(""), tradeId(0),
        active(false), isExecuted(false),
        approved_volume(0.0), approved_risk_money(0.0), approved_risk_pct(0.0)
    {
        legs.Clear();
    }

    TradeEntity(string _symbol, ENUM_ORDER_TYPE _type, string _strategyName) : 
        symbol(_symbol), type(_type), strategyName(_strategyName), tradeId(0),
        active(false), isExecuted(false),
        approved_volume(0.0), approved_risk_money(0.0), approved_risk_pct(0.0)
    {
        legs.Clear();
    }
     
   // Método para agregar una nueva "pierna" a la operación
   void AddLeg(TradeLeg *leg)
     {
       legs.Add(leg);
     }

   void ClearLegs()
     {
       for(int i = legs.Total()-1; i >= 0; i--)
         {
           TradeLeg *leg = (TradeLeg*)legs.At(i);
           delete leg;
         }
       legs.Clear();
     }

   void CopyFrom(const TradeEntity &other)
     {
       symbol = other.symbol;
       type = other.type;
       entryTime = other.entryTime;
       strategyName = other.strategyName;
       tradeId = other.tradeId;
       active = other.active;
       isExecuted = other.isExecuted;
       approved_volume = other.approved_volume;
       approved_risk_money = other.approved_risk_money;
       approved_risk_pct = other.approved_risk_pct;
       ClearLegs();
       for(int i = 0; i < other.legs.Total(); i++)
         {
           TradeLeg *otherLeg = (TradeLeg*)other.legs.At(i);
           if(otherLeg == NULL)
              continue;
           TradeLeg *leg = new TradeLeg(otherLeg.lotSize, otherLeg.slPips, otherLeg.tpPips, otherLeg.trailingStepPips);
           leg.ticket = otherLeg.ticket;
           leg.entryPrice = otherLeg.entryPrice;
           leg.magic = otherLeg.magic;
           leg.comment = otherLeg.comment;
           leg.legIndex = otherLeg.legIndex;
           leg.isPartial = otherLeg.isPartial;
           leg.closed = otherLeg.closed;
           legs.Add(leg);
         }
     }
     
   // Método para buscar y retornar una TradeLeg según su ticket
   TradeLeg* GetLeg(long ticket)
     {
       for(int i = 0; i < legs.Total(); i++)
         {
           TradeLeg *leg = (TradeLeg*)legs.At(i);
           if(leg.ticket == ticket)
              return leg;
         }
       return NULL;
     }
     
   // Cierra la operación global y marca todas sus "piernas" como cerradas
   void CloseTrade()
     {
       active = false;
       for(int i = 0; i < legs.Total(); i++)
         {
           TradeLeg *leg = (TradeLeg*)legs.At(i);
           leg.closed = true;
         }
     }
     
   // Método que retorna un string con la información relevante de la operación
   string GetDetails()
     {
       // _Digits es la variable global que indica la cantidad de decimales para el símbolo actual.
       return "Operación abierta: " + symbol + ", Estrategia: " + strategyName;
     }
     
   virtual void Clear() {}

   static int NextTradeId()
     {
       static int nextId = 1;
       return nextId++;
     }
     
   ~TradeEntity()
     {
       ClearLegs();
     }
};

#endif // __TRADEENTITY_MQH__
