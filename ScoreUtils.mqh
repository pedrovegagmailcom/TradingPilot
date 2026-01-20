#ifndef __SCOREUTILS_MQH__
#define __SCOREUTILS_MQH__

double Clamp01(double value)
{
   if(value < 0.0)
      return 0.0;
   if(value > 1.0)
      return 1.0;
   return value;
}

double ComputeR(double sl_pips, double tp_pips)
{
   if(sl_pips <= 0.0)
      return 0.0;
   return Clamp01(tp_pips / sl_pips);
}

double SpreadPips(const string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   double spreadPoints = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(pip <= 0.0)
      return spreadPoints;
   return (spreadPoints * point) / pip;
}

double ScorePlan(const string symbol, double quality01, double sl_pips, double tp_pips)
{
   double r01 = ComputeR(sl_pips, tp_pips);
   double spread = SpreadPips(symbol);
   return 70.0 * Clamp01(quality01) + 30.0 * r01 - 10.0 * spread;
}

#endif // __SCOREUTILS_MQH__
