//  Listen for all incoming messages on port
OscIn oin;        // make an OSC receiver
6449 => oin.port;  // set port #
oin.listenAll();  //   any message at all

OscMsg msg;   // message holder

Moog moogL => LPF lpf => NRev rev => Pan2 moogLPan => dac;
Bowed bowR => lpf => rev => Pan2 bowRPan => dac;
0.1 => rev.mix;
0.1 => moogLPan.gain;
0.4 => bowRPan.gain;
1.0 => bowR.noteOn;
216 => moogL.freq; // default: 432/2

// BandedWG with a defined preset for DRUM
BandedWG tom => dac;
125 => tom.freq;
2 => tom.preset; // "Uniform Bar"

ModalBar cowbell => HPF hpf => dac;
hpf => Echo delay => hpf;
moogLPan => delay => moogLPan;
7 => cowbell.preset;
second => delay.max;
0.5 => delay.mix;

0.0 => float pan;
432.0 => float freq;
0.5 => float vel;

spork ~ drummIt();
spork ~ moogIt();

while(true)
{
    oin => now;   // wait for any OSC
    while(oin.recv(msg))
    {
        msg.address => string address;
        msg.getFloat(0) => float pan;
        msg.getFloat(1) => float freq;
        msg.getFloat(2) => float vel;

        if (address == "/inst/left") {
            pan => moogLPan.pan;
            freq => moogL.freq;
            vel => moogL.filterQ;
            Std.fabs(pan) => moogL.filterSweepRate;
            Math.max(Math.sqrt(vel)*100, 1) => moogL.vibratoFreq; // slope
            Math.min(Math.sqrt(vel), 1) => moogL.vibratoGain;
        }
        if (address == "/inst/right") {
            pan => bowRPan.pan;
            freq => bowR.freq;
            vel => bowR.bowPressure;
            Std.fabs(pan) => bowR.bowPosition;
            Math.max(Math.sqrt(vel)*100, 1) => bowR.vibratoFreq; // slope
            Math.min(Math.sqrt(vel), 1) => moogL.vibratoGain;
        }
        if (address == "/filt/lpf") {
            freq => lpf.freq;
            vel  => lpf.Q;
            vel::second => delay.delay;
        }
    }
}

fun void drummIt() {
    while (true) {
        1.0 => tom.noteOn;
        Math.random2f(500.0, 3000.0) => hpf.freq;
        Math.random2f(0.3, 0.7) => hpf.Q;
        1.0 => cowbell.noteOn;
        0.5::second => now;
    }
};

fun void moogIt() {
    while (true) {
        1.0 => moogL.noteOn;
        second => now;
    }
};
