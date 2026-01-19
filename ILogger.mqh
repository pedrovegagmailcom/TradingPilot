#ifndef __ILOGGER_MQH__
#define __ILOGGER_MQH__

class ILogger
  {
public:
   virtual void Init() = 0;
   virtual void Log(string message) = 0;  // Se pasa por valor
  };

#endif // __ILOGGER_MQH__
