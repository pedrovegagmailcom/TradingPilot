#ifndef __RISKDECISION_MQH__
#define __RISKDECISION_MQH__

struct RiskDecision
  {
   bool   allowed;
   double volume;
   double risk_money;
   double risk_pct;
   string reason;

   RiskDecision()
     {
      allowed = false;
      volume = 0.0;
      risk_money = 0.0;
      risk_pct = 0.0;
      reason = "";
     }
  };

#endif // __RISKDECISION_MQH__
