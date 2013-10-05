/*
Sympli Romatiko SynthDefs

Naming synths:
\sr__<t>__<name>, where:
<t> - type of the synth, where:
    g - granular (\bufnum points to a buffer with a sound file loaded)
    e - electronic (if there is a \bufnum it can point to a buffer with a scale)
    p - percussion
    s - spatialization
    r - recording
    u - utilities
<name> - some meaninful word
*/

// Generators.
//
// - every time a Gen synth is created, its output (mono!) is sent to a chosen bus,
// which feeds into automatically created Spatializing synth.
//
// - some params such as azimuth and distance are sent to both Gen synths, where they
// control parameters of audio, and Spatializing synths, where they determine a
// position and span of the Gen output.


// GRANULAR SYNTHS
//
SynthDef(\sr__g__reg, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=0, cutoff=0;
    var in, out, signal;
    var trate, dur, pos, clk, ds, rate=1;
    // Conversion.
    rate = az.linlin(0, 1, 0.2, 2);
    trate = az.linlin(0, 1, 100, 0.2);
    dur = 4 / trate;
    clk = Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(azimuth));
    ds = distance/3.44;
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos, dur, amp: amp);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(Mix.ar(in), distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__g__drone, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=0, cutoff=0;
    var in, out, signal;
    var trate, dur, pos, clk, ds, rate=1;
    // Conversion.
    rate = az.linlin(0, 1, 0.2, 2);
    trate = SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur = 12 / trate;
    clk = Impulse.kr(trate);
    pos = ax * BufDur.kr(bufnum);
    ds = distance/3.44;
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos + TRand.kr(0, 0.01, clk), dur, amp: amp);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(Mix.ar(in), distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__g__gust, { // ~ gusts of wind
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=0, cutoff=0;
    var in, out, signal;
    var trate, dur, pos, clk, d, zz, ds;
    // Conversion.
    pos = (distance * 0.19 + 0.1).round(0.01);
    trate = az.linlin(0, 1, 0.1, 20);
    clk = Impulse.ar(trate);
    d = {Dwhite(0.1, 0.2, 1)};
    zz = {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    ds = distance/3.44;
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf) * pos + 1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value] * 2, inf) / trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
    );
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(Mix.ar(in), distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__g__slic, { // slicing
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=0, cutoff=0;
    var in, out, signal;
    var trate, dur, pos, clk, rate=1, ds;
    // Conversion.
    rate = az.linlin(0, 1, 0.2, 2);
    trate = az.linlin(0, 1, 1, 100);
    dur = 8 / trate;
    clk = Dust.kr(trate);
    pos = ax * BufDur.kr(bufnum);
    ds = distance/3.44;
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, (2 ** WhiteNoise.kr(2)) * rate, BufFrames.ir(bufnum) * pos, dur, 0, amp);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(Mix.ar(in), distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__g__loop, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=0, cutoff=0;
    var in, out, signal;
    var rate=1, startPos=0, ds;
    // Conversion.
    rate = az.linlin(0, 1, 0.1, 1.9);
    ds = distance/3.44;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, rate * BufRateScale.kr(bufnum),
        Impulse.ar(BufDur.kr(bufnum).reciprocal), BufFrames.ir(bufnum) * startPos);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__g__chunk, { // ~ chunks of sound
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=0, cutoff=0;
    var in, signal, out;
    var rate, ds;
    // Conversion.
    rate = az.linlin(0, 1, 0.1, 1.9);
    ds = distance/3.44;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum,
        rate * BufRateScale.kr(bufnum),
        Dust.kr(0.5),
        TRand.kr(0, BufFrames.ir(bufnum), Dust.kr(0.5))
    );
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).send(s);


// ELECTRONIC SYNTHS
//
SynthDef(\sr__e__lowe, { // the "lowe"st
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var q=0.1, a=2pi, b=400, c=0, dir=[1, 0], frate=1, freq=400, xx=(1..5)*20;
    // Conversion.
    dir = dir.put(1, az.linlin(0, 1, -pi, pi));
    dir = dir.put(0, ax.linlin(0, 1, -pi, pi));
    q = dir[1].atan2(dir[0]) + pi;
    a = frate.linlin(0,2, 2pi, 0);
    b = dir[1].hypot(dir[0]) * 400 + 200;
    c = velocity.linlin(0, 1, 50, 150);
    // Synthesis.
    in = SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp * 0.05);
    signal = RLPF.ar(FreeVerb.ar(Limiter.ar(Mix.ar(in))), distance.linlin(0, 2.sqrt, 500, 10000), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__probe, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var rate=1, dtl=0.01, dtr=0.05;
    // Conversion.
    rate = (velocity * 5).max(0.5) * exprand(3, 8);
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10]);
    note = DegreeToKey.kr(LocalBuf.newFrom(scale), az * 15, 24, 1, 15);
    // Synthesis.
    in = LPZ2.ar(
        LFPulse.ar(
            note.midicps, 2pi.rand, 0.1,
            (
                Mix.ar(SinOsc.ar(rate * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand])).abs
                * (amp * 0.2)
            )
        )
    );
    2.do({in = AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2)});
    signal = Mix(in);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__cmb, { // CMB ~ "Cosmic Backgroud Radiation"
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var rate=1, delayL, delayR, pos=0.0, pulse, mix, n=8;
    // Conversion.
    rate = az.linlin(0, 1, 2, 0.2);
    delayL = az.linlin(0, 1, 0.01, 0.05);
    delayR = ax.linlin(0, 1, 0.01, 0.05);
    pulse = LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
    // Synthesis.
    mix = Klank.ar(
        `[Array.fill(n, {exprand(1.0,20.0)}),
            nil,
            Array.fill(n, {0.2.rand})
        ],
        Blip.ar(pulse, [rrand(2,5), rrand(2,5)], 0.1)
    ).fold2(0.2).cubed * 12;
    in = Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
    in = in.distort * 0.5;
    6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
    in = LeakDC.ar(in * 0.4); // attenuate the volume a bit
    signal = RLPF.ar(FreeVerb.ar(Mix.ar(in), distance, distance/3.44, 0.2),
        distance.linlin(0, 2.sqrt, 10000, 500), 0.5, mul: amp);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__melo, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, scale, in, out, signal;
    // Conversion.
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10]);
    note = DegreeToKey.kr(LocalBuf.newFrom(scale), az * 15, 24, 1, 15).midicps;
    // Synthesis.
    in = RLPF.ar(LFSaw.ar(note)
        + Impulse.ar(XLine.kr(note, note + 100, 1.5), 0.0, 0.7.rand)
        + WhiteNoise.ar(0.8.rand, mul:0.2),
        LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp
    );
    in = [in, DelayN.ar(in, 0.04, 0.04)];
    4.do({in = AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4)});
    signal = RLPF.ar(
        FreeVerb.ar(LeakDC.ar(Mix.ar(in) * 0.03), distance, distance/3.44, 0.2),
        distance.linlin(0, 2.sqrt, 10000, 500), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__ringz, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var scale, in, out, signal;
    var fbase, reso, shift;
    // Conversion.
    fbase = distance.linexp(0, 1, 10, 40);
    reso = distance.linexp(0, 1, 200, 5000);
    shift = ((velocity * 30) ** 3).lag(0.01);
    // Synthesis.
    in = Ringz.ar(SinOsc.ar(fbase, shift, amp * 0.02), reso, 0.01).softclip;
    5.do({in});
    signal = RLPF.ar(
        FreeVerb.ar(LeakDC.ar(Mix.ar(in)), distance, distance/3.44, 0.2),
        distance.linlin(0, 2.sqrt, 10000, 500), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__pulse, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var cutOff, rq, azThresh=0.7;
    // Conversion.
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10]);
    cutOff = distance.linexp(0.0, 1.0, 200, 10000); // different from arg!
    rq = distance.linlin(0, 2.sqrt, 0.5, 1);
    note = SelectX.kr(BinaryOpUGen('<', az, azThresh) * 2,
        [
            DegreeToKey.kr(LocalBuf.newFrom(scale), // go melodic above height threshold
                (az - azThresh).linlin(0, 1 - azThresh, 0, 12), 12, 1, offset
            ).midicps,
            velocity.linlin(0, 1, 5, 150) // continuos change at the bottom
        ]
    );
    // Synthesis.
    in = Blip.ar(SinOsc.kr(0.5, 0, LFDNoise1.kr(1.5), note), 100, 0.2);
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutOff, rq), cutOff, rq, amp);
    in = Compander.ar(in, in, 0.002, slopeBelow: 0.33, slopeAbove: 0.5, clampTime: 0.01, relaxTime: 0.01);
    signal = Mix.ar(in);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__analog, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var scale, note, in, out, signal;
    var rq, azThresh=0.7;
    // Conversion.
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10]);
    cutoff = SelectX.kr(BinaryOpUGen('<', cutoff, 0) * 2,
        [ // Positive cutoff falls at the freq range 200..5000
            SelectX.kr(BinaryOpUGen('<', velocity, 0.33) * 2, [ // high velocity causes sharp switch
                LFDClipNoise.ar(az, 34, 78),
                LFNoise1.ar(TRand.kr(trig:Delay2.kr(Dust.kr(1))), 34, 90)
            ]).midicps,
            5666 // zero or negative cutoff means constant
        ]
    );
    rq = SelectX.kr(BinaryOpUGen('==', cutoff, 5666) * 2,
        [ // If cutoff is variable, RQ depends on distance.
            distance.linlin(0, 2.sqrt, 0.07, 1),
            0.06 // constant cutoff means constant RQ
        ]
    );
    note = SelectX.kr(BinaryOpUGen('<', az, azThresh) * 2,
        [   // Go melodic above height threshold.
            DegreeToKey.kr(LocalBuf.newFrom(scale), (az-azThresh).linlin(0, 1-azThresh, 0, 12), 12, 1, offset),
            az.linlin(0, azThresh, (offset-6), offset) // bottom to middle change continuously
        ]
    );
    // Synthesis.
    in = Mix.fill(8, {LFSaw.ar((note + 0.1.rand2).midicps, mul:0.025)});
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq, amp);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__noisy, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
	var in, out, signal;
    var fbase, shift;
    // Conversion.
    fbase = distance.linexp(0, 1, 10, 40);
    shift = ((velocity * 30) ** 3).lag(0.01);
    // Synthesis.
    in = Formlet.ar(
        WhiteNoise.ar(SinOsc.ar(fbase, shift, 0.5, 1)).min(1) + SinOsc.ar(fbase, shift),
        LFNoise1.ar(TRand.kr(trig:Delay2.kr(Dust.kr(0.5))), 2450, 2550), 0.01, 0.1
    ).softclip;
    in = [in, DelayN.ar(in, 0.04, 0.4)];
    4.do({in = AllpassN.ar(in, 0.5, [0.5.rand, 0.5.rand], 4, amp * 2)});
    signal = RLPF.ar(
        FreeVerb.ar(LeakDC.ar(Mix.ar(in) * 0.03), distance, distance/3.44, 0.5),
        distance.linlin(0, 2.sqrt, 10000, 500), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__e__humm, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0,
        mnote=0, freqBase=85, mod=0; // WARNING! This is obsolete, remove when finishing notes via .kr bus!
    var scale, note, in, out, signal;
    // Synthesis.
    in = LFSaw.ar(mnote + freqBase + mod.linlin(-1, 1, -40, 40), mul: amp * 0.1);
    signal = RLPF.ar(in, LinLin.kr(mod, -1, 1, 80, 30).midicps, 0.1, amp.clip(0.01, 0.99));
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__lfsaw, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0,
        mnote=0, freqBase=85, mod=0; // WARNING! This is obsolete, remove when finishing notes via .kr bus!
    var scale, note, in, out, signal;
    // Conversion.
    in = LFSaw.ar(
        mnote + freqBase + mod.linlin(-1, 1, -50, 0),
        (amp * mod.linlin(-1,1, 0.01, 0.25)).clip(0.01, 0.99)
    );
    signal = RLPF.ar(
        FreeVerb.ar(LeakDC.ar(in), distance, distance/3.44, 0.2),
        distance.linlin(0, 2.sqrt, 10000, 500), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


// DRUMS AND PERCUSSION
// (Warning! Different enveloping.)
//
SynthDef(\sr__p__kick, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr=3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var in, out, signal;
    // Synthesis.
    in = SinOsc.ar([60.742, 57.2532], 0, 0.5);
    in = BPeakEQ.ar(in, 1900, 1, 12.0) + LPF.ar(Decay.ar(WhiteNoise.ar(0.05), 0.3, 0.1), 1000);
    signal = Mix(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.perc(0.05, 1, 1, -6), doneAction:2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__p__hat, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr=3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var in, out, signal;
    var trig=0.5;
    // Synthesis.
    in = LPF.ar(
        WhiteNoise.ar(
            TWChoose.ar(trig, [
                Decay2.ar(trig * LFNoise1.ar(8, 0.5, 0.5), 0.02, 0.1),
                Decay2.ar(trig * LFNoise1.ar(8, 0.5, 0.5), 0.5, 0.1)
            ], [0.8, 0.2])
        ), 6000
    ) * 0.01;
    signal = Mix(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.perc(0.05, 1, 1, -6), doneAction:2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__p__snare, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr=3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var in, out, signal;
    // Synthesis.
    in = LPF.ar(
        Pulse.ar(120),
        EnvGen.ar(Env.perc(0.05, 0.2, 0.2, -4), gate) * 1000 + 30
    ) + BPF.ar(HPF.ar(WhiteNoise.ar, 500), 1500);
    signal = Mix(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.perc(0.05, 1, 1, -6), doneAction:2);
    Out.ar(outbus, out);
}).add;


// SPATIALIZERS
//
// - spatializer has no attack, but longer \rel to ensure that it will be released after corresponding Gen synth,
//   since \rel param is sent to both Gen synth and Spatializer.
//
// Ambisonic notes:
// - distance of the object from the center should always be corrected with respect to field depth.
// - distance artificially moved to 0.5 from the center to eliminate feedback.
//
SynthDef(\sr__s__ambisonic2, {
    arg inbus=20, outbus=0,
        amp=1, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim= [-0.25pi, 0.25pi], speakerElev= 0, speakerDist= [2, 2],
        maxDist=3, scaleFlag=1,
        in, signal, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance, amp);
    out = FMHDecode1.stereo(w, z);
    // out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
    // azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic4, {
    arg inbus=20, outbus=0,
        amp=1, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [2, 2, 2, 2],
        maxDist=3, scaleFlag=1,
        in, signal, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance, amp);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic8, {
    arg inbus=20, outbus=0,
        amp=1, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim=[-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev=0,
        speakerDist=[6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1,
        in, signal, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance, amp);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__vbap4, {
    arg inbus=20, outbus=0,
        amp=1, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var speakerAzim = #[-45, -140, 140, 45], speakerElev=0, speakerBuff, spread=0;
    var in, signal, out;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth = azimuth.linlin(-pi, pi, -180, 180);
    elevation = elevation.linlin(-0.5pi, 0.5pi, -90, 90);
    spread = [50, 0, 4].asSpec.map(distance); // the closer the signal, the more speakers involved (welch-like)
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    out = VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(outbus, out);
}).send(s);


// RECORDING AND AUDIO
//
SynthDef(\sr__r__rec1, { // mono recording
    arg inbus, bufnum=0, amp=1;
    DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).send(s);


SynthDef(\sr__r__rec2, { // stereo recording
    arg inbus, bufnum=0, amp=1;
    DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 2), 0.99, 0.01) );
}).send(s);


SynthDef(\sr__r__buffloop, { // continuous recording into buffer
    arg bufnum, busnum=0, volIn=0.8, loop=1, dur=1, gate=0;
    RecordBuf.ar(
        InFeedback.ar(busnum)
        * EnvGen.kr(
            Env.linen(0.1, dur-0.2, 0.1, volIn, \welch),
            gate: Impulse.kr(gate.reciprocal)
        ),
        bufnum, 0, volIn, 0, 1, loop, 1
    );
}).send(s);


SynthDef(\sr__r__authro, { // audio-through
    arg bufnum=0, inbus=0, outbus=0,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5;
    var in, out, signal;
    var ds;
    // Conversion.
    ds = distance/3.44;
    // Synthesis.
    in = InFeedback.ar(inbus, 1);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    //Envelope.
    out = signal * EnvGen.kr(Env.adsr(att, 0.1, master, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).send(s);


// UTILITIES
//
SynthDef(\sr__u__grain, { //individual grain (can only be sent to audio in).
    arg bufnum=0, busnum=0, amp=1, att=1, rel=1, ca=3, cr= -3,
    pos=0.0, rate=1, dur=0.1;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate, 1, BufFrames.ir(bufnum) * pos, 0);
    //Envelope.
    out = in * (EnvGen.kr(Env.perc(0.01, dur), doneAction:2) - 0.001);
    Out.ar(busnum, out);
}).send(s);

// sample player (can only be sent to audio in).
SynthDef(\sr__u__play, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=1, rel=1, gate=1, ca=3, cr= -3,
    pos=0.0, rate=1, dur=0.1;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate, 1, BufFrames.ir(bufnum) * pos, 1);
    //Envelope.
    out = in * EnvGen.kr(Env.adsr(att, 0.1, master, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(busnum, out);
}).send(s);

SynthDef(\sr__u__mixNode4x1, { // send sum to the 5th channel, LPF, 5th channel goes to sub
    arg inbus=0, outbus=4, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 4), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);