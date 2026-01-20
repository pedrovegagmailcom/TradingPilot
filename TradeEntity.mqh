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
    bool      active;
    bool      isExecuted;   // Nuevo
    CArrayObj legs;

    TradeEntity() :
        symbol(""), type(ORDER_TYPE_BUY), strategyName(""),
        active(false), isExecuted(false)
    {
        legs.Clear();
    }

    TradeEntity(string _symbol, ENUM_ORDER_TYPE _type, string _strategyName) : 
        symbol(_symbol), type(_type), strategyName(_strategyName), 
        active(false), isExecuted(false) 
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
       active = other.active;
       isExecuted = other.isExecuted;
       ClearLegs();
       for(int i = 0; i < other.legs.Total(); i++)
         {
           TradeLeg *otherLeg = (TradeLeg*)other.legs.At(i);
           if(otherLeg == NULL)
              continue;
           TradeLeg *leg = new TradeLeg(otherLeg.lotSize, otherLeg.slPips, otherLeg.tpPips, otherLeg.trailingStepPips);
           leg.ticket = otherLeg.ticket;
           leg.entryPrice = otherLeg.entryPrice;
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
     
   ~TradeEntity()
     {
       ClearLegs();
     }
};

#endif // __TRADEENTITY_MQH__
