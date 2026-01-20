#ifndef __ZONEMANAGER_MQH__
#define __ZONEMANAGER_MQH__

#include <Arrays\ArrayObj.mqh>
#include <Object.mqh>

//---------------------------------------------------------
// Clase SZone : derivada de CObject para poder 
// almacenarse en CArrayObj
//---------------------------------------------------------
class SZone : public CObject
{
public:
   double price;
   int    touches;

   // Constructor
   SZone(double _price=0.0, int _touches=0)
   : price(_price), touches(_touches)
   {
   }

   // MQL5 exige override de Clear() si heredas de CObject
   virtual void Clear() {}
};

//---------------------------------------------------------
// Clase ZoneManager : un solo array "m_zones" con
// todas las zonas de trabajo, sin distinguir High/Low
//---------------------------------------------------------
class ZoneManager : public CObject
{
private:
   CArrayObj m_zones; // array dinámico de punteros a SZone

public:
   // Constructor
   ZoneManager()
   {
      m_zones.Clear();
   }

   // Destructor
   virtual ~ZoneManager()
   {
      ClearAll();
   }

   // Limpiar todas las zonas (borrar objetos y array)
   void ClearAll()
   {
      for(int i = m_zones.Total()-1; i >= 0; i--)
      {
         SZone *z = (SZone*)m_zones.At(i);
         delete z;
      }
      m_zones.Clear();
   }

   // Agregar una zona de trabajo (sin distinción high/low)
   void AddZone(double price, int touches)
   {
      SZone *z = new SZone(price, touches);
      m_zones.Add(z);
   }

   // Cantidad total de zonas
   int GetZoneCount()
   {
      return m_zones.Total();
   }

   // Obtener zona por índice
   SZone* GetZoneByIndex(int index)
   {
      if(index < 0 || index >= m_zones.Total())
         return NULL;
      return (SZone*) m_zones.At(index);
   }

   // nearZone => true si el precio está dentro de threshold de alguna zona
   bool NearZone(double price, double threshold)
   {
      for(int i=0; i<m_zones.Total(); i++)
      {
         SZone *z = (SZone*) m_zones.At(i);
         if(MathAbs(z.price - price) <= threshold)
            return true;
      }
      return false;
   }

   // Overridden de CObject
   virtual void Clear() {}
};

#endif // __ZONEMANAGER_MQH__
