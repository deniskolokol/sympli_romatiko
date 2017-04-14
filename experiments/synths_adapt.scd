// ADAPT THIS EXAMPLE:
// metal impact "http://designingsound.org/2013/04/a-quick-introduction-to-supercollider/"
(
w = Window.new("Metal Impact Tuner", Rect(200, Window.screenBounds.height-700,1055,600)).front ;

SynthDef(\Rate, {|rate=1, out=5|
	~playrate = Impulse.ar(rate, 0, 0.3);
	Out.ar(out, ~playrate)
}).send(s);

SynthDef(\Bank1, {|out=2, freqA1=2000, freqA2=2000, freqA3=2000, freqA4=2000, freqA5=2000, ringA1=2,
        ringA2=2, ringA3=2, ringA4=2, ringA5=2| ~signal1 = DynKlank.ar(`[[Lag.kr(freqA1+40,1),
        Lag.kr(freqA2+40,1), Lag.kr(freqA3+40,1), Lag.kr(freqA4+40,1), Lag.kr(freqA5+40,1)], nil,
        [ringA1, ringA2, ringA3, ringA4, ringA5]], In.ar(5), 0.2, 0, 1).dup*0.4;
	Out.ar(out, ~signal1)
}).send(s);

SynthDef(\Bank2, {|out=3, freqB1=2000, freqB2=2000, freqB3=2000, freqB4=2000, freqB5=2000, ringB1=2,
        ringB2=2, ringB3=2, ringB4=2, ringB5=2| ~signal2 = DynKlank.ar(`[[Lag.kr(freqB1+40,0.3),
        Lag.kr(freqB2+40,0.3), Lag.kr(freqB3+40,0.3), Lag.kr(freqB4+40,0.3), Lag.kr(freqB5+40,0.3)],
        nil, [ringB1, ringB2, ringB3, ringB4, ringB5]], In.ar(5), 0.2, 0, 1).dup*0.4;
	Out.ar(out, ~signal2)
}).send(s);

SynthDef(\Filter, {|out=4, cutoff=1000|
	var output;
	~filtered = HPF.ar(SinOsc.ar(Rand(324,352)) * In.ar(2), Lag.kr(cutoff+20,1), 0.8) +
	HPF.ar(SinOsc.ar(Rand(466,546)) * In.ar(3), Lag.kr(cutoff+20,1), 1);
	~output = Mix.ar(CombL.ar(~filtered, Rand(0.3, 1.8), Array.fill(10,{(0.005).(0.01).rand2 + 0.07}) * 0.06, 0.08));
	Out.ar(out, ~output)
}).send(s);

SynthDef(\Output, {|gain=0.2, revsize=5, revtime=3, revdamp=0.5, revdry=1|
	var output;
	output = Mix.ar(CombL.ar(In.ar(4), Rand(0.3, 1.8), Array.fill(1, 0.07) * 0.06, 0.08));
	2.do({output = AllpassN.ar(output, 0.020, [0.020.rand,0.020.rand], 1, mul:0.9) });
	~reverb = GVerb.ar(In.ar(4), Lag.kr(revsize,0.3), Lag.kr(revtime,0.7), revdamp, 0.5, 15, revdry);

	output = ~reverb.dup*(gain/5);
	output = output.clip2(0.75);
	output = Limiter.ar(output, 0.9, 0.01);
	Out.ar([0,1], output*0.5);

}).send(s);
Synth(\Bank1).autogui(window:w, step:50, vOff: 0, hOff:0, scopeOn:true) ;
Synth(\Rate, addAction:\addToHead).autogui(window:w, step:50, vOff: 0, hOff:830, scopeOn:false) ;
Synth(\Bank2, addAction:\addToTail).autogui(window:w, step:50, vOff: 200, hOff:0, scopeOn:false) ;
Synth(\Filter, addAction:\addToTail).autogui(window:w, step:50, vOff: 400, hOff:0, scopeOn:false) ;
Synth(\Output, addAction:\addToTail).autogui(window:w, step:50, vOff: 400, hOff:360, scopeOn:false) ;
)

// * * *

// ADAPT THIS EXAMPLE:
// KEYWORDS: Osc, Buffer.sineN, Harmonics, SinOscFB
// change the buffer while its playing
b = Buffer.alloc(s, 4096, 1);
b.sine1(1.0/[1,2,3,4,5,6], true, true, true).plot;
(1.0/[1,2,3,4,5,6]).plot;

a = Harmonics.new(16);
[
    a.decay(1.0),
    a.geom(1.2),
    a.formant(6, 8)
].plot;

d = 16
0.1.linlin(0, 1, 0, d).trunc.round(1)

(
SynthDef(\sr__e__harm, {
    arg bufnum=0, inbus=30, route=20,
    amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, elevation=0, velocity=0.5,
    gx=0.1, gy=0.1, gz=0.1, gAzimuth=0, gDistance=0.5, gElevation=0.5,
    offset=36;
    var harmSize=16, base, freq, center, width,
    wavetable, in, out, signal;
    base = Harmonics.new(16);
    center = 6;
    width = 6;
    center = ax.linlin(0, 1, 0, harmSize).trunc.round(1);
    // width = velocity.linlin(0, 1, 0, harmSize * 0.5).floor;
    freq = (offset * base.formant(center, width)).midicps;
    wavetable = Buffer.alloc(s, base.size, 1).sine1(
        base.formant(1.0, width), true, true, true
    );
    in = Osc.ar(wavetable.bufnum, freq, 0, 0.2);
    signal = Mix.ar(in) * amp;
    out = signal * master * EnvGen.kr(
    Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, Pan2.ar(out));
}).play(s, [\route, 0, \bufnum, b.bufnum]);
)

(
fork {
    var n = 32;
    50.do { |i|
        s.sendMsg("/n_set", 1002, \offset, 20+i);
        // b.sine1(Array.rand(n,0,1).cubed, true, true, true);
        0.25.wait;
    };
};
)