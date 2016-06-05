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
// b = Buffer.alloc(s, 4096, 1);
// b.sine1(1.0/[1,2,3,4,5,6], true, true, true).plot;
// (1.0/[1,2,3,4,5,6]).plot;
//
// a = Harmonics.new(16);
// [
//     a.decay(1.0),
//     a.geom(1.2),
//     a.formant(6, 8)
// ].plot;
//
// d = 16
// 0.1.linlin(0, 1, 0, d).trunc.round(1)
//
// (
// SynthDef(\sr__e__harm, {
//     arg bufnum=0, inbus=30, route=20,
//     amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
//     ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, elevation=0, velocity=0.5,
//     gx=0.1, gy=0.1, gz=0.1, gAzimuth=0, gDistance=0.5, gElevation=0.5,
//     offset=36;
//     var harmSize=16, base, freq, center, width,
//     wavetable, in, out, signal;
//     base = Harmonics.new(16);
//     center = 6;
//     width = 6;
//     center = ax.linlin(0, 1, 0, harmSize).trunc.round(1);
//     // width = velocity.linlin(0, 1, 0, harmSize * 0.5).floor;
//     freq = (offset * base.formant(center, width)).midicps;
//     wavetable = Buffer.alloc(s, base.size, 1).sine1(
//         base.formant(1.0, width), true, true, true
//     );
//     in = Osc.ar(wavetable.bufnum, freq, 0, 0.2);
//     signal = Mix.ar(in) * amp;
//     out = signal * master * EnvGen.kr(
//     Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
//     Out.ar(route, Pan2.ar(out));
// }).play(s, [\route, 0, \bufnum, b.bufnum]);
// )
//
// (
// fork {
//     var n = 32;
//     50.do { |i|
//         s.sendMsg("/n_set", 1002, \offset, 20+i);
//         // b.sine1(Array.rand(n,0,1).cubed, true, true, true);
//         0.25.wait;
//     };
// };
// )



(
SynthDef(\sr__e__harm, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, elevation=0, velocity=0.5,
        gx=0.1, gy=0.1, gz=0.1, gAzimuth=0, gDistance=0.5, gElevation=0.5;
    var freq, feedback, in, out, signal;
    freq = [400, 301];
    feedback = [0.1, 2.5];
    in = Osc.ar(bufnum, freq, 0, 0.2);
    // in = SinOscFB.ar(freq, feedback, 0.3);
    out = in;
    Out.ar(route, Pan2.ar(out));
}).add;

// ORIG:
// {Out.ar(0,Pan2.ar(FreeVerb.ar(0.5*TermanWang.ar(2.0+ SinOsc.ar(MouseX.kr(10,10000,'exponential'),0,MouseY.kr(0.1,100.0,'exponential')),Impulse.kr(MouseX.kr(1,10000, 'exponential')),0.01,0.01,1.0,1.0,1.0,MouseX.kr(0.4,1.2), MouseY.kr(2.0,4.0)),0.5)))}.play;
SynthDef(\sr__e__neural, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, velocity=0.5,
        offset=36, cutoff=0, threshold=0.7, scope=12;
    var in, out, signal;
    var rq;
    var freq, trig, timer, mul, add;
    // Conversion.
    mul = velocity.linlin(0, 1, 1850, 2350);
    add = distance.linlin(0, 1, 2250, 5800);
    trig = velocity > 0.33; // high velocity causes sharp switch
    timer = Timer.kr(trig);
    freq = TRand.kr(trig:Delay2.kr(Dust.kr(velocity.linexp(0.01, 1, 0.5, 10))));
    cutoff = SelectX.kr(BinaryOpUGen('<', cutoff, 0) * 2,
        [ // Positive cutoff falls at the freq range 500..5000
            TWChoose.kr((timer > 0.25) * trig,
                [
                    LFNoise0.ar(freq, mul, add),
                    LFNoise1.ar(freq, mul, add),
                    LFNoise2.ar(freq).clip2 * mul + add // quadratic interpolation can push beyond [-1..1]
                ],
                [0.1, 0.3, 0.6]
            ),
            5666 // zero or negative cutoff means constant
        ]
    );
    rq = SelectX.kr(BinaryOpUGen('==', cutoff, 5666) * 2,
        [ // If cutoff is variable, RQ depends on az.
            velocity.linlin(0, 1, 0.8, 0.2),
            0.1 // constant cutoff means constant RQ
        ]
    );
    // Synthesis.
    in = TermanWang.ar(
        2.0 + SinOsc.ar(az.linexp(0.01, 1, 10, 10000), 0, az.linexp(0.01, 1, 0.1, 100.0)),
        Impulse.kr(distance.linexp(0.01, 1, 1, 10000)),
        0.01, 0.01, 1.0, 1.0, 1.0,
        ax.linlin(0, 1, 0.4, 1.2), ay.linlin(0, 1, 2.0, 4.0)
    ) * 0.2;
    in = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    signal = Compander.ar(in, in, 0.1, slopeBelow: 1, slopeAbove: 0.5,
        clampTime: 0.01, relaxTime: 0.01, mul: amp);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, Pan2.ar(out));
}).add;

SynthDef(\sr__e__buzzow, {
    arg bufnum=0, inbus=30, route=20,
    amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, velocity=0.5,
    offset=36, cutoff=0;
    var note, in, out, signal;
    // Conversion.
    note = (DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 15), 12, 1, offset)
        + LFNoise1.kr([3, 3], 0.04)).midicps;    // add some low freq stereo detuning
    // Synthesis.
    in = LFSaw.ar((1..5) * note, abs(velocity * 2), velocity)
    + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
    in = Mix.ar(in) * amp * 0.1;
    signal = RLPF.ar(in, LinLin.kr(velocity, 0, 1, 80, 30).midicps, velocity);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, Pan2.ar(out));
}).send(s);

SynthDef(\sr__e__hammond, {
    arg bufnum=0, inbus=30, route=20,
    amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, velocity=0.5,
    offset=44, cutoff=0;
    var freq, scale, scaleBase, harmonics,
    env, signal, out;
    scaleBase = [0, 12, 17, 24, 29, 32]; // ["C1", "C2", "F2", "C3", "F3", "G#3"]
    // scale = [ -20, -15, -8, -3, 0, 12, 17, 24, 29, 32, 44, 56, 61, 68, 73, 76 ]
    scale = (scaleBase - scaleBase.last)[1..scaleBase.lastIndex-1]
    ++ scaleBase
    ++ (scaleBase[1] + scaleBase.maxItem + scaleBase);
    freq = (scale + offset).clip(0, 127);
    harmonics = Harmonics.new(scale.size).formant(4, 9);
    signal = Mix.ar(SinOsc.ar(freq.midicps, 0, harmonics) * 0.112) * amp;
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, Pan2.ar(out));
}).send(s);

SynthDef(\sr__e__pipe, {
    arg bufnum=0, inbus=30, route=20,
    amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, velocity=0.5,
    offset=36, cutoff=0;
    var note, in, out, signal;
    var cutOff, rq, azThresh=0.7;
    var scale = FloatArray[0,1,4,5,7,8,10];
    // Conversion.
    cutOff = distance.linexp(0.0, 1.0, 500, 10000); // different from arg!
    rq = distance.linlin(0, 2.sqrt, 0.5, 1);
    note = (DegreeToKey.kr(LocalBuf.newFrom(scale), az.linlin(0,1, 0,24), 12, 1, offset)
        + LFNoise1.kr([3, 3], 0.04)).midicps;
    // Synthesis.
    in = GVerb.ar(
        (Saw.ar(freq: (1..5) * note,
            mul:velocity,
            add:LFPar.ar(velocity.linexp(0,1, 0.01,100), 0.5,
                LFNoise2.ar(LFNoise2.ar(mul:9, add:20), 0.2, 0.5))
            )
            + Pulse.ar(freq: LFNoise2.ar((1..5), 2).exprange(0.1, 1) * note,
                mul:velocity.scurve)
        ) / 16,
        roomsize: distance.linlin(0,1, 2,80),
        revtime: distance.linlin(0,1, 0.2,2)
    );
    signal = Mix.ar(in);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, Pan2.ar(out));
}).add;

SynthDef(\sr__e__growl, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=0.5, elevation=0, velocity=0.5,
        gx=0.1, gy=0.1, gz=0.1, gAzimuth=0, gDistance=0.5, gElevation=0.5,
        offset=6, cutoff=0;
    var in, out, signal;
    var cutOff, rq, rate, pitches, trig, freq, mul, add, detune, lag,
        note=offset,
        meloThresh=0.5,
        tones=10,
        noOfSynths=20;

    // Conversion.
    freq = velocity.linexp(0, 1, 0.5, 5);
    mul = velocity.lincurve(0, 1, 400, 2000, 4);
    add = velocity.lincurve(0, 1, 600, 10000, 4);
    rq = velocity.lincurve(0, 1, 0.5, 0.1, 4);
    cutOff = LFNoise2.ar(freq).clip2 * mul + add;
    cutOff.poll;
    rate = velocity.linlin(0, 1, 2, 4).round;
    trig = Impulse.kr(0) + Dust2.kr(rate);
    lag = velocity.lincurve(0, 1, 0.5, 0.05, -4);
    detune = velocity.lincurve(0, 1, 0.1, 0.5, 4);
    note = DegreeToKey.kr(bufnum,
        // guide params for fine control of pitch and threshold
        Gate.kr(gz.linlin(0, 1, 0, 15), gDistance - meloThresh),
        12, 1, offset
    ).min(124);

    // Synthesis.
    in = Mix.fill(tones,
        { |index|
            pitches = Lag.kr(
                Select.kr(
                    Demand.kr(trig, 0, Drand([0, 1, 2], inf)),
                    DegreeToKey.kr(bufnum, index.linlin(0, tones, 0, 6), 12, 1, note)
                )
                + TRand.kr(detune.neg, detune, trig),
                lag * Rand(0.8, 1.2)
            ).min(127).midicps;

            Blip.ar(
                SinOsc.kr(0.5, 0, LFDNoise1.kr(1.5), pitches),
                100,
                SelectX.kr(BinaryOpUGen('<', ay, 0.5),
                    [
                        velocity.scurve,
                        amp * Lag.kr(TRand.kr(0.8, 1.0, trig), lag * Rand(0.8, 1.2))
                    ]
                )
            )
            * (if(index < noOfSynths, 1, 0));
        }
    );
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutOff, rq), cutOff, rq);
    in = Limiter.ar(MidEQ.ar(in, [200, 1400], 0.7, 8), amp * 0.3);
    signal = Mix.ar(in);

    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, Pan2.ar(out));
}).add;

SynthDef(\sr__e__plane, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0, rq=0.1;
    var note, in, out, signal;
    // Conversion.
    note = (DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 15), 12, 1, offset)
        + LFNoise1.kr([3, 3], 0.04)).midicps;    // add some low freq stereo detuning
    // Synthesis.
    in = LFSaw.ar((1..5) * note, abs(velocity * 2), velocity)
         + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
    in = Mix.ar(in) * amp * attenuate;
    signal = RLPF.ar(in,
        freq:LinLin.kr(velocity, 0, 1, 830, 30),
        rq:LFNoise1.kr(velocity.linexp(0, 1, 0.2, 500),
            velocity.linlin(0, 1, 0.0005, 0.75),
            velocity.linlin(0, 1, 0.0005, 1.25),
        ),
    );
    // Envelope.
    out = signal * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, Pan2.ar(out));
}).add;

SynthDef(\sr__e__probe, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.5, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0,

        phaseL=2pi.rand, phaseR=2pi.rand;
    var note, in, out, signal;
    var rate=1, dtl=0.01, dtr=0.05;
    // Conversion.
    rate = (velocity * 5).max(0.1) * exprand(3, 8);
    note = DegreeToKey.kr(bufnum, az * 15, 24, 1, 15);
    // Synthesis.
    in = LPZ2.ar(
        LFPulse.ar(
            note.midicps, 2pi.rand, 0.1,
            (
                Mix.ar(SinOsc.ar(rate * [0.1, 1], [pi, 1.35pi], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand])).abs
            )
        )
    );
    2.do({in = AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, amp * attenuate)});
    signal = Mix(in);
    // Envelope.
    out = signal * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, Pan2.ar(out));
}).add;
)

(
var names = [\sr__e__probe, \sr__e__plane,  \sr__e__harm, \sr__e__neural, \sr__e__buzzow, \sr__e__hammond, \sr__e__pipe, \sr__e__growl];
var nodeL, nodeR;
var synL, synR;
var sNew, sOff, sNext, nSet;
var clipInc = { |in=0, step=1, lo=0, hi=inf|
    // Increments `in` until `in + step` reaches `hi`, then resets to `lo`.
    ((in + step).clip(lo, hi) % hi).clip(lo, hi)
};
var synths;

g = s.nextNodeID;
s.sendMsg("/g_new", g);
nodeL = s.nextNodeID;
nodeR = s.nextNodeID;
#synL, synR = names[..1];

l = FloatArray[ 0, 1, 4, 5, 7, 9, 10 ];
b = 10;
s.sendMsg("/b_alloc", b, l.size, ["/b_set", b] ++ l);

sNew = { |syn, route=0|
    var node = s.nextNodeID;
    s.sendMsg("/s_new", syn, node, 0, g, \route, route, \bufnum, b);
    node
};
sOff = { |node, rel=1|
    s.sendMsg("/n_set", node, \gate, 0, \rel, rel)
};
sNext = { |node, syn, next=1, route=0|
    i = clipInc.(names.indexOf(syn), next, 0, names.size-1);
    sOff.(node);
    [sNew.(names[i], route), names[i]]
};
nSet = { |node, name, val|
    [name, val].postln;
    s.sendMsg("/n_set", node, name, val)
};

MIDIIn.connectAll;
MIDIIn.control = { |scr, chan, num, val|
    [chan, num, val, val].postln;
    num.switch(
        //
        // LEFT
        //
        24, { nSet.(nodeL, \az, \midinote.asSpec.unmap(val)) }, // Knob 1 Left
        25, { nSet.(nodeL, \phaseL, \midinote.asSpec.unmap(val).linlin(0, 1, 0, 2pi)) }, // Knob 2 Left
        26, { nSet.(nodeL, \phaseR, \midinote.asSpec.unmap(val).linlin(0, 1, 0, 2pi)) }, // Knob 3 Left
        12, { nSet.(nodeL, \amp, \midinote.asSpec.unmap(val)) }, // Pitch fader Left

        27, { nSet.(nodeL, \offset, val) }, // Knob Hi Left
        28, { nSet.(nodeL, \cutoff, \freq.asSpec.map(\midinote.asSpec.unmap(val))) }, // Knob Mid Left ControlSpec
        29, { nSet.(nodeL, \rq, \rq.asSpec.map(\midinote.asSpec.unmap(val))) }, // Knob Low Left
        11, { nSet.(nodeL, \velocity, \midinote.asSpec.unmap(val)) }, // Volume fader Left
        //
        // RIGHT
        //
        34, { nSet.(nodeR, \offset, val) }, // Knob Hi Right
        35, { nSet.(nodeR, \cutoff, \freq.asSpec.map(\midinote.asSpec.unmap(val))) }, // Knob Mid Right
        36, { nSet.(nodeR, \rq, \rq.asSpec.map(\midinote.asSpec.unmap(val))) }, // Knob Low Right
        14, { nSet.(nodeR, \amp, \midinote.asSpec.unmap(val)) }, // Volume fader Right

        31, { nSet.(nodeR, \ax, \midinote.asSpec.unmap(val)) }, // Knob 1 Right
        32, { nSet.(nodeR, \ay, \midinote.asSpec.unmap(val)) }, // Knob 2 Right
        33, { nSet.(nodeR, \az, \midinote.asSpec.unmap(val)) }, // Knob 3 Right
        15, { nSet.(nodeR, \velocity, \midinote.asSpec.unmap(val)) } // Pitch fader Right
    )
};

MIDIIn.noteOn = { |scr, chan, num, val|
	[chan, num, val].postln;
    num.switch(
        70, { nodeL = sNew.(synL, route:0) }, // Start/Pause Left
        69, { nodeR = sNew.(synR, route:2)  }, // Start/Pause Right
        58, { sOff.(nodeL) }, // Queue Left
		59, { sOff.(nodeR) }, // Queue Right
        46, { #nodeL, synL = sNext.(nodeL, synL, -1, route:0) }, // Prev Left
        43, { #nodeL, synL = sNext.(nodeL, synL, 1, route:0) }, // Next Left
        56, { #nodeR, synR = sNext.(nodeR, synR, -1, route:2) }, // Prev Right
        57, { #nodeR, synR = sNext.(nodeR, synR, 1, route:2) }, // Next Right
        44, { synL.postln }, // Headphones Left
        45, { synR.postln }, // Headphones Right
    )
};

CmdPeriod.doOnce({
    sOff.(nodeL); sOff.(nodeR);
    b.free;
    MIDIIn.disconnect;
});
)

//// SC 3.5+
//MIDIFunc.cc({ |val, b, c, d| s.sendMsg("/n_set", h, \az, \midinote.asSpec.unmap(val)) }, 24, 0);
//MIDIFunc.noteOn({ |val, b, c, d| s.sendMsg("/s_new", \proba, h, 0, g, \route, 0, \bufnum, b, \offset, 24); }, 70, 0);
MIDIFunc.noteOn({ |val, b, c, d| s.sendMsg("/n_set", h, \gate, 0, \rel, 1) }, 58, 0);