#ifndef __TRADEMANAGER_MQH__
#define __TRADEMANAGER_MQH__

#include <Arrays\ArrayObj.mqh>
#include <Object.mqh>
#include "TradeEntity.mqh"

class TradeManager : public CObject
{
private:
   CArrayObj trades;  // Array dinámico para almacenar punteros a TradeEntity
public:
   TradeManager()
     {
       trades.Clear();  // Inicializa el array como vacío
     }
     
   virtual ~TradeManager()
     {
       for(int i = trades.Total()-1; i >= 0; i--)
         {
           TradeEntity *entity = (TradeEntity*) trades.At(i);
           delete entity;
         }
       trades.Clear();
     }
     
   // Agrega una nueva operación al array
   void AddTrade(TradeEntity *entity)
     {
       entity.active = true;
       trades.Add(entity);
       int trades_count = trades.Total();
     }
     
   // Remueve una operación que contenga una "pierna" con el ticket indicado
   void RemoveTrade(long ticket)
     {
       for(int i = 0; i < trades.Total(); i++)
         {
           TradeEntity *entity = (TradeEntity*) trades.At(i);
           for(int j = 0; j < entity.legs.Total(); j++)
             {
               TradeLeg *leg = (TradeLeg*) entity.legs.At(j);
               if(leg.ticket == ticket)
                 {
                   delete entity;
                   trades.Delete(i);
                   return;
                 }
             }
         }
     }
     
   // Retorna la operación que contenga una "pierna" con el ticket dado
   TradeEntity* GetTradeByTicket(long ticket)
     {
       for(int i = 0; i < trades.Total(); i++)
         {
           TradeEntity *entity = (TradeEntity*) trades.At(i);
           for(int j = 0; j < entity.legs.Total(); j++)
             {
               TradeLeg *leg = (TradeLeg*) entity.legs.At(j);
               if(leg.ticket == ticket)
                  return entity;
             }
         }
       return NULL;
     }
     
   // Verifica si existe una operación activa para un símbolo y estrategia específicos
   bool HasActiveTrade(string strategyName, string symbol)
     {
       int trades_count = trades.Total();
       for(int i = 0; i < trades.Total(); i++)
         {
           TradeEntity *entity = (TradeEntity*) trades.At(i);
           if(entity.active && entity.strategyName == strategyName && entity.symbol == symbol)
              return true;
         }
       return false;
     }

   // Verifica si existe una operación activa para un símbolo (regla de 1 trade por símbolo)
   bool HasActiveTradeBySymbol(string symbol)
     {
       for(int i = 0; i < trades.Total(); i++)
         {
           TradeEntity *entity = (TradeEntity*) trades.At(i);
           if(entity.active && entity.symbol == symbol)
              return true;
         }
       return false;
     }
     
   // Actualiza el estado de las operaciones abiertas. 
   // Se registra solo cuando se detecta que una operación ha sido cerrada, y se elimina del array.
   void UpdateTrades()
     {
       // Iteramos de forma inversa para poder eliminar sin afectar el índice
       for(int i = trades.Total()-1; i >= 0; i--)
         {
           TradeEntity *entity = (TradeEntity*) trades.At(i);
           if(!entity.active)  // Si la operación ya está cerrada...
             {
               // Registra el cierre de la operación (se utiliza GetDetails() para mostrar la info)
               Print("TradeManager: Operación cerrada: ", entity.GetDetails());
               delete entity;
               trades.Delete(i);
             }
         }
     }
     
     // En TradeManager.mqh o .cpp
int GetTradeCount()
{
   // trades es tu CArrayObj con punteros a TradeEntity
   return trades.Total();
}

TradeEntity* GetTradeByIndex(int index)
{
   if(index < 0 || index >= trades.Total())
      return NULL;
   // casteo a TradeEntity* si tu array es CArrayObj
   return (TradeEntity*) trades.At(index);
}

void RemoveTradeByIndex(int index)
{
   if(index < 0 || index >= trades.Total())
      return;
   // borramos la posición del array. 
   // Ojo, si usas punteros, quizá debas delete entity si ya no la necesitas
   TradeEntity *entity = (TradeEntity*) trades.At(index);
   if(entity != NULL)
      delete entity;
   trades.Delete(index);
}

     
   virtual void Clear() {}
};

#endif // __TRADEMANAGER_MQH__
