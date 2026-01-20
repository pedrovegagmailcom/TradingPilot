// Archivo: SR_Zone_1D.mqh
// Detector de Zonas de Trabajo, unificando en un solo set de zonas.

// Asegúrate de tener #include "ZoneManager.mqh" 
// extern ZoneManager *g_zoneManager;  // si está en un header global

// Parámetros globales de detección y dibujado
int      g_lookbackDays = 20;
int      g_swingBars    =2;
int      g_zoneProximityPips = 1;
color    g_highZoneColor = clrRoyalBlue;
color    g_lowZoneColor  = clrCrimson;
double   g_zoneOpacity   = 0.4;
int      g_minTouches    = 20;
int      g_zoneBaseHeightPips = 5;
int      g_heightPerTouchPips = 2;
int      g_labelFontSize = 8;

// Color si deseas para dibujar (ahora uno solo)
color  g_zoneWorkColor        = clrDodgerBlue;

// Estructura local para creación previa a filtrar en zoneManager
struct LocalSZone
{
   double price;
   int    touches;
};

//----------------------------------------------------------------------------
// Función principal: DetectZonesOnce
//  - Copia Rates
//  - Detecta swings (altos y bajos), los mezcla en un array "swingAll"
//  - Crea, filtra y los pasa a g_zoneManager
//  - Dibuja rectángulos (prefijo "ZW_") sin distinguir High/Low
//----------------------------------------------------------------------------
void DetectZonesOnce()
{
   // 1) Copiar datos
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int barsWanted = g_lookbackDays * 86400 / PeriodSeconds(_Period);
   if(barsWanted < 200) barsWanted = 200;

   int copied = CopyRates(_Symbol, _Period, 0, barsWanted, rates);
   if(copied < 2*g_swingBars)
   {
     Print("SR_Zone_1D: Error, datos insuficientes. copied=",copied);
     return;
   }

   // 2) Detectar swings
   double swingHighs[], swingLows[];
   DetectSwings(rates, swingHighs, swingLows);

   // Unificamos en un solo array "swingAll"
   double swingAll[];
   // Insertamos las highs
   for(int i=0; i<ArraySize(swingHighs); i++)
      ArrayInsertSorted(swingAll, swingHighs[i]);
   // Insertamos las lows
   for(int i=0; i<ArraySize(swingLows); i++)
      ArrayInsertSorted(swingAll, swingLows[i]);
   // Con esto tenemos un array "swingAll" con todos los swings mezclados

   // 3) Crear Zonas locales "LocalSZone"
   double proximity = g_zoneProximityPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   LocalSZone zones[];
   CreateZones(zones, swingAll, proximity);

   // 4) Filtrarlas
   FilterZones(zones);

   // 5) Cargar en g_zoneManager
   if(g_zoneManager != NULL)
   {
      g_zoneManager.ClearAll();
      for(int i=0; i<ArraySize(zones); i++)
      {
         g_zoneManager.AddZone(zones[i].price, zones[i].touches);
      }
   }
   else
   {
      Print("SR_Zone_1D: g_zoneManager es NULL, no guardamos zonas");
   }

   // 6) Dibujar
   DeleteOldObjects();
   DrawZones(zones);
}

//----------------------------------------------------------------------------
// DetectSwings
//----------------------------------------------------------------------------
void DetectSwings(MqlRates &rates[], double &highs[], double &lows[])
{
   for(int i=g_swingBars; i<ArraySize(rates)-g_swingBars; i++)
   {
      bool isHigh=true, isLow=true;
      for(int j=1; j<=g_swingBars; j++)
      {
         if(rates[i].high < rates[i-j].high || rates[i].high < rates[i+j].high) isHigh=false;
         if(rates[i].low  > rates[i-j].low  || rates[i].low  > rates[i+j].low ) isLow=false;
      }
      if(isHigh) ArrayInsertSorted(highs, rates[i].high);
      if(isLow)  ArrayInsertSorted(lows,  rates[i].low);
   }
}

//----------------------------------------------------------------------------
// CreateZones : unifica todos los swings en "zones[]"
//----------------------------------------------------------------------------
void CreateZones(LocalSZone &zones[], double &swings[], double proximity)
{
   for(int i=0; i<ArraySize(swings); i++)
   {
      bool merged=false;
      for(int j=0; j<ArraySize(zones); j++)
      {
         if(MathAbs(swings[i] - zones[j].price) <= proximity)
         {
            zones[j].price = (zones[j].price*zones[j].touches + swings[i]) / (zones[j].touches +1);
            zones[j].touches++;
            merged=true;
            break;
         }
      }
      if(!merged)
      {
         int size=ArraySize(zones);
         ArrayResize(zones, size+1);
         zones[size].price   = swings[i];
         zones[size].touches = 1;
      }
   }
}

//----------------------------------------------------------------------------
// FilterZones: descartar las que tengan pocos "touches"
//----------------------------------------------------------------------------
void FilterZones(LocalSZone &zones[])
{
   int count=0;
   for(int i=0; i<ArraySize(zones); i++)
   {
      if(zones[i].touches >= g_minTouches)
         zones[count++] = zones[i];
   }
   ArrayResize(zones, count);
}

//----------------------------------------------------------------------------
// DrawZones : dibuja todas las zonas unificadas 
// sin separar High / Low
//----------------------------------------------------------------------------
void DrawZones(LocalSZone &zones[])
{
   // time1 => hace X días
   datetime time1 = TimeCurrent() - g_lookbackDays*86400;
   // time2 => fecha muy futura
   datetime time2 = D'2100.12.31 23:59:59';

   for(int i=0; i<ArraySize(zones); i++)
   {
      // Calcular "altura" en función de touches
      double heightPips = g_zoneBaseHeightPips + (zones[i].touches -1)* g_heightPerTouchPips / 40.0;
      double heightPoints = heightPips * SymbolInfoDouble(_Symbol,SYMBOL_POINT)*10.0;

      double startPrice = zones[i].price - heightPoints/2.0;
      double endPrice   = zones[i].price + heightPoints/2.0;

      string zoneName = "ZW_" + IntegerToString(i);
      ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, time1, startPrice, time2, endPrice);

      color zoneColor = (color)ColorToARGB(g_zoneWorkColor, (uchar)(255*g_zoneOpacity));
      ObjectSetInteger(0, zoneName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, zoneName, OBJPROP_BACK, false);

      // label con touches
      string labelName = zoneName + "_LABEL";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), zones[i].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, IntegerToString(zones[i].touches));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE,  10);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
   }
}

//----------------------------------------------------------------------------
// DeleteOldObjects : elimina objetos con prefijo "ZW_"
//----------------------------------------------------------------------------
void DeleteOldObjects()
{
   int total = ObjectsTotal(0);
   for(int i= total-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name,"ZW_") == 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//----------------------------------------------------------------------------
// Insertar un double en array, manteniendo orden
//----------------------------------------------------------------------------
void ArrayInsertSorted(double &array[], double value)
{
   int pos = ArraySize(array);
   ArrayResize(array, pos+1);
   array[pos] = value;
   ArraySort(array);
}
