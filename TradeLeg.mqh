#ifndef __TRADELEG_MQH__
#define __TRADELEG_MQH__

#include <Object.mqh>

// Clase que representa una "pierna" de la operación

class TradeLeg : public CObject {
public:
    long   ticket;
    double lotSize;
    double entryPrice;   // Nuevo
    double slPips;       // Legacy: SL en pips
    double tpPips;       // Legacy: TP en pips
    double slPrice;      // SL en precio (aprobado por riesgo)
    double tpPrice;      // TP en precio (aprobado por riesgo)
    int    trailingStepPips; // Nuevo: Paso trailing
    long   magic;
    string comment;
    int    legIndex;
    bool   isPartial;
    bool   closed;

    // Constructor con parámetros
    TradeLeg(double lots, double sl, double tp, int trailing=0) : 
        lotSize(lots), slPips(sl), tpPips(tp), trailingStepPips(trailing) 
    {
        ticket = 0;
        entryPrice = 0.0;
        slPrice = 0.0;
        tpPrice = 0.0;
        magic = 0;
        comment = "";
        legIndex = -1;
        isPartial = false;
        closed = false;
    }
    
    virtual void Clear() {}
};

#endif // __TRADELEG_MQH__
