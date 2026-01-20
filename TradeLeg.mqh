#ifndef __TRADELEG_MQH__
#define __TRADELEG_MQH__

#include <Object.mqh>

// Clase que representa una "pierna" de la operación

class TradeLeg : public CObject {
public:
    long   ticket;
    double lotSize;
    double entryPrice;   // Nuevo
    double slPips;       // Nuevo: SL en pips
    double tpPips;       // Nuevo: TP en pips
    int    trailingStepPips; // Nuevo: Paso trailing
    bool   isPartial;
    bool   closed;

    // Constructor con parámetros
    TradeLeg(double lots, double sl, double tp, int trailing=0) : 
        lotSize(lots), slPips(sl), tpPips(tp), trailingStepPips(trailing) 
    {
        ticket = 0;
        entryPrice = 0.0;
        isPartial = false;
        closed = false;
    }
    
    virtual void Clear() {}
};

#endif // __TRADELEG_MQH__
