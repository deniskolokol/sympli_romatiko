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
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos, dur);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(Mix.ar(in), distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp;
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
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos + TRand.kr(0, 0.01, clk), dur);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(Mix.ar(in), distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp;
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
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf)
    );
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(Mix.ar(in), distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp;
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
    in = TGrains.ar(2, clk, bufnum, (2 ** WhiteNoise.kr(2)) * rate, BufFrames.ir(bufnum) * pos, dur, 0);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(Mix.ar(in), distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp;
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__g__scratch, { // ~ chunks of sound
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=0, cutoff=0;
    var in, signal, out;
    var rate, ds, pos;
    // Conversion.
    rate = az.linlin(0, 1, 0.1, 1.9);
    ds = distance/3.44;
    pos = ax * BufDur.kr(bufnum);
    // Synthesis.
    in = BufRd.ar(1, bufnum, Lag.ar(K2A.ar(BufFrames.ir(bufnum) * pos), 4), 1);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp;
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).send(s);


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
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp;
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__g__unst, {
    arg bufnum=0, busnum=0, pos=0, amp=1, master=1, gate=1, rate=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist;
    var in, signal, out, ds;
    ds = distance/3.44;
    in = PlayBuf.ar(1, bufnum,
        TWChoose.kr(
            Dust.kr(0.01),
            [
                BufRateScale.kr(bufnum) * TRand.kr(0.8, 1.3, Dust.kr(0.2)),
                BufRateScale.kr(bufnum) * TRand.kr(-0.8, -1.3, Dust.kr(0.2)),
            ],
        [0.8, 0.2]),
        Dust.kr(0.2),
        TRand.kr(0, BufFrames.ir(bufnum), Dust.kr(0.2))
    );
    signal = RLPF.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp;
    //Envelope.
    out = signal * master * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    Out.ar(busnum, out)
}).send(s);


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
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp;
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
    var note, in, out, signal;
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
                Mix.ar(SinOsc.ar(rate * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand])).abs
            )
        )
    );
    2.do({in = AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2)});
    signal = Mix(in) * amp * master;
    //Envelope.
    out = signal * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__cmb, { // CMB ~ "Cosmic Backgroud Radiation"
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, in, out, signal;
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
    var note, in, out, signal;
    // Conversion.
    note = (
        DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 15), 12, 1, offset)
        + LFNoise1.kr([3,3], 0.04)    // add some low freq stereo detuning
    ).midicps;

    // Synthesis.
    in = RLPF.ar(
        LFSaw.ar(note)
        + Impulse.ar(XLine.kr(note, note + 100, 1.5), 0.0)
        + Normalizer.ar(LorenzL.ar(az.linlin(0, 1, 10, SampleRate.ir),
            LFNoise0.kr(1.0.rand, 2, 10), r: LFNoise0.kr(1.0.rand, 20, 38), b: LFSaw.kr(0.2).exp.cubed), 1),
        LFNoise0.kr(0.2, 38, 115).midicps, 0.1,
        mul:(amp * velocity * 0.5).scurve // sigmoid: the faster, the more present
        // mul:velocity // simply the faster the louder
    );
    in = [in, DelayN.ar(in, 0.04, 0.04)];
    4.do({in = AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4)});
    in = Mix.ar(in);
    signal = RLPF.ar(
        FreeVerb.ar(LeakDC.ar(in), distance, distance/3.44, 0.2),
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
    var in, out, signal;
    var fbase, shift;
    // Conversion.
    fbase = (az * distance).linexp(0, 1, 10, 40);
    shift = ((velocity * 30) ** 3).lag(0.01);
    // Synthesis.
    in = (
        Ringz.ar(SinOsc.ar(fbase, shift), distance.linexp(0,1.41, 200,2000), 0.01)
        + RLPF.ar(LFSaw.ar((1..10) * fbase * az, shift, velocity))
    ).softclip;
    5.do({in});
    in = Limiter.ar(MidEQ.ar(Mix.ar(in), 14000, 0.7, 8), amp * 0.2);
    signal = RLPF.ar(
        FreeVerb.ar(in, distance, distance/3.44, 0.2),
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
    var note, in, out, signal;
    var cutOff, rq, azThresh=0.7;
    // Conversion.
    cutOff = distance.linexp(0.0, 1.0, 200, 10000); // different from arg!
    rq = distance.linlin(0, 2.sqrt, 0.5, 1);
    note = SelectX.kr(BinaryOpUGen('<', az, azThresh) * 2,
        [ // go melodic above height threshold
            DegreeToKey.kr(bufnum, (az - azThresh).linlin(0, 1 - azThresh, 0, 12), 12, 1, offset).midicps,
            velocity.linlin(0, 1, 5, 150) // continuos change at the bottom
        ]
    );
    // Synthesis.
    in = Blip.ar(SinOsc.kr(0.5, 0, LFDNoise1.kr(1.5), note), 100, 0.2);
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutOff, rq), cutOff, rq);
    in = Limiter.ar(MidEQ.ar(Mix.ar(in), [200, 14000], 0.7, 8), amp * 0.1);
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
    var note, in, out, signal;
    var rq, azThresh=0.7;
    var freq, trig, timer, mul, add;
    // Conversion.
    mul = 2250; add = 2750;
    trig = velocity > 0.33; // high velocity causes sharp switch
    timer = Timer.kr(trig);
    freq = TRand.kr(trig:Delay2.kr(Dust.kr(1)));
    cutoff = SelectX.kr(BinaryOpUGen('<', cutoff, 0) * 2,
        [ // Positive cutoff falls at the freq range 500..5000
            TWChoose.kr((timer > 0.25) * trig,
                [
                    LFNoise0.ar(freq, mul, add),
                    LFNoise1.ar(freq, mul, add),
                    LFNoise2.ar(freq).clip2 * mul + add // quadratic interpolation can push beyond normal range of +-1
                ],
                [0.1, 0.3, 0.6]
            ),
            5666 // zero or negative cutoff means constant
        ]
    );
    rq = SelectX.kr(BinaryOpUGen('==', cutoff, 5666) * 2,
        [ // If cutoff is variable, RQ depends on distance.
            distance.linlin(0, 2.sqrt, 0.1, 1),
            0.1 // constant cutoff means constant RQ
        ]
    );
    note = SelectX.kr(BinaryOpUGen('<', az, azThresh) * 2,
        [   // Go melodic above height threshold.
            DegreeToKey.kr(bufnum, (az-azThresh).linlin(0, 1-azThresh, 0, 12), 12, 1, offset),
            az.linlin(0, azThresh, (offset-6), offset) // bottom to middle change continuously
        ]
    );
    // Synthesis.
    in = Mix.fill(8, {LFSaw.ar((note + 0.1.rand2).midicps)});
    in = Compander.ar(in, in, 0.002, slopeBelow: 0.33, slopeAbove: 0.5,
        clampTime: 0.01, relaxTime: 0.01, mul: amp);
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__gauss, {
    arg bufnum=0, inbus=30, outbus=20,
    amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
    offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var cutOff, rq, dur, width;
    // Conversion.
    cutOff = distance.linexp(0.0, 1.0, 10000, 200); // different from arg cutoff!
    rq = distance.linexp(0, 2.sqrt, 1, 0.2);
    dur = SinOsc.ar(LinExp.kr(az, 0.001, 1, 0.05, 5000) * [1, 1.1]).range(0.0006, 0.01);
    width = SinOsc.ar(0.5 * [1, 1.1]).range(0.01, 0.3);
    // Synthesis.
    in = LFGauss.ar(dur, width)
        + SinOsc.ar(az.linexp(0, 1, 0.01, 5000) * [1, 1.1],
            mul:(az.clip(0, 1) * velocity).sqrt); // sqrt boosts mul
    in = Mix.fill(10, in);
    in = Compander.ar(in, in, 0.002, slopeBelow: 0.33, slopeAbove: 0.5,
        clampTime: 0.01, relaxTime: 0.01, mul: amp);
    signal = RLPF.ar(RLPF.ar(Mix.ar(in), cutOff, rq), cutOff, rq);
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
    4.do({in = AllpassN.ar(in, 0.5, [0.5.rand, 0.5.rand], 4, amp * 1.5)});
    signal = RLPF.ar(
        FreeVerb.ar(LeakDC.ar(Mix.ar(in) * 0.03), distance, distance/3.44, 0.5),
        distance.linlin(0, 2.sqrt, 10000, 500), 0.5);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__e__entro, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var freq, shift, rq, in, out, signal;
    var options, trig, timer;
    // Conversion.
    rq = distance.linlin(0, 2.sqrt, 0.2, 1);
    freq = velocity.linexp(0, 1, 20, 1000);
    shift = ((velocity ** 0.2 * 30) ** 3).lag(0.5); // boost velocity
    trig = velocity > 0.3;
    timer = Timer.kr(trig);
    in = TChoose.ar((timer > 0.25) * trig, [
        RLPF.ar(Normalizer.ar(LorenzL.ar(az.linlin(0, 1, 10, SampleRate.ir),
            LFNoise0.kr(1, 2, 10), r: LFNoise0.kr(1, 20, 38), b: LFSaw.kr(0.2).exp.cubed), 1),
            LFPulse.kr(LFSaw.ar(0.2).exp.cubed, 0.5, 2500, 3500),
            velocity),
        Saw.ar((1..15) * LFNoise0.kr(5, 10, 50) + SinOsc.ar((6..2) * 0.5))
        ]
    );
    in = Mix.ar(in) * velocity * amp * 0.15; // too loud comparing to the rest, attenuate vol
    signal = RLPF.ar(RLPF.ar(in, shift, rq), shift, rq);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__humm, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0,
        mnote=0, freqBase=36, mod=0; // WARNING! This is obsolete, remove when finishing notes via .kr bus!
    var note, in, out, signal;
    // Conversion.
    note = DegreeToKey.kr(bufnum, az, 24, 1, freqBase).midicps;
    // Synthesis.
    in = LFSaw.ar((1..5) * note, velocity)
         + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
    in = Mix.ar(in) * amp * 0.2;
    signal = RLPF.ar(in, LinLin.kr(velocity, 0, 1, 80, 30).midicps, velocity);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__radio, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var freq, in, out, signal;
    var trig, timer;
    // Conversion.
    freq = (az * (36..72)).midicps;
    trig = velocity > 0.3;
    timer = Timer.kr(trig);
    cutoff = TChoose.ar((timer > 0.25) * trig, [
        LFDClipNoise.ar(az, 450, 650),
        LFNoise2.ar(TRand.kr(trig:Delay2.kr(Dust.kr(0.2))), 450, 550)
        ]
    );
    // Synthesis.
    in = (
        LFSaw.ar(freq, mul:velocity)
        + Impulse.ar(SinOsc.ar(cutoff).exprange(48, 10000), mul:velocity)
        + Formlet.ar(
            Impulse.ar(freq + SinOsc.ar(freq * 0.02).exprange(0.3, cutoff / 3.67)),
            (1..5)
            * SinOsc.ar(velocity).exprange(20, 2000)
            * SinOsc.ar(SinOsc.ar(velocity, 0, 0.1), 0, 0.1, 1), 0.001, 0.0015,
            mul:velocity.scurve
        )
    ) * 0.01;
    signal = RLPF.ar(
        FreeVerb.ar(in, distance, distance/3.44, 0.2),
    distance.linlin(0, 2.sqrt, 10000, 500), 0.5);
    signal = Mix.ar(signal);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__wasp, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var cutOff, rq, azThresh=0.7;
    // Conversion.
    cutOff = distance.linexp(0.0, 1.0, 500, 10000); // different from arg!
    rq = distance.linlin(0, 2.sqrt, 0.5, 1);
    note = DegreeToKey.kr(bufnum, az * 15, 24, 1, offset);
    // Synthesis.
    in = Formlet.ar(
        LPF.ar(Saw.ar((1..5) * LFClipNoise.ar(SinOsc.ar(0.1, 0, 0.5, 1), 10, note))
            + SinOsc.ar((6..2), velocity ** 3).exprange(0.05, 50), 300)
        + Impulse.ar(
            (0..4) + SinOsc.ar(
                (4..8) * 0.02).exprange(0.3, 300)), (1..5)
        // * SinOsc.ar((5..9) * 0.05).exprange(200, 2000)
        // * SinOsc.ar(SinOsc.ar((2..6) * 0.1, 0, 0.1), 0, 0.1, 1),
        * SinOsc.ar((5..9) * az*0.05).exprange(200, 2000)
        * SinOsc.ar(SinOsc.ar((2..6) * az*0.1, 0, 0.1), 0, 0.1, 1),
        velocity.linlin(0, 1, 0.100, 0.0010),
        velocity.linlin(0, 1, 0.015, 0.0015)
    );
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutOff, rq), cutOff, rq);
    in = Compander.ar(in, in, 0.002, slopeBelow: 0.33, slopeAbove: 0.33,
        clampTime: 0.01, relaxTime: 0.01,
        mul:velocity.clip); // sigmoid: the faster, the more present
    signal = Mix.ar(in);
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
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim = [-0.17pi, 0.17pi], speakerElev = 0,
        speakerDist = [2, 2], maxDist = 2, scaleFlag = 1,
        in, signal, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic4, {
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=15;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim = [-0.15pi, -0.7pi, 0.7pi, 0.15pi], speakerElev = [-0.1pi, 0, 0, -0.1pi],
        speakerDist = [2.5, 2.5, 2.5, 2.5], maxDist = 2.5, scaleFlag = 1,
        in, signal, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic6, {
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=15;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim = [-0.25pi, -0.4pi, -0.65pi, 0.65pi, 0.4pi, 0.25pi], speakerElev = [0, 0, 0, 0, 0, 0],
        speakerDist = [8, 3, 4, 4, 3, 8], maxDist = 8, scaleFlag = 1,
        in, signal, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic8, {
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim = [-0.20pi, -0.5pi, -0.70pi, -1pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev = 0,
        speakerDist = [ 8, 8, 8, 8, 8, 8, 8, 8 ], maxDist = 6.3, scaleFlag = 1,
        in, signal, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__vbap4, {
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var speakerAzim = #[-45, -140, 140, 45], speakerElev=0, speakerBuff, spread=0;
    var in, amp, signal, out;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth = azimuth.linlin(-pi, pi, -180, 180);
    elevation = elevation.linlin(-0.5pi, 0.5pi, -90, 90);
    spread = [100, 0, 4].asSpec.map(distance); // the closer the signal, the more speakers involved (welch-like)
    amp = distance.linexp(0.001, 2.sqrt, 1, 0.001); // and the louder it is.
    in = In.ar(inbus, 1) * amp;
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


// MODULATORS
//
SynthDef(\sr__k__sin, {
    arg outbus=0, freq=440, phase=0, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * SinOsc.kr(LFNoise0.kr(freq, mod_mul, mod_add), LFDClipNoise.kr(freq), mul, add);
    Out.kr(outbus, out);
}).add;

SynthDef(\sr__k__saw, {
    arg outbus=0, freq=440, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * Saw.kr(LFNoise0.kr(freq, mod_mul, mod_add), mul, add);
    Out.kr(outbus, Saw.kr(freq, mul, add));
}).add;

SynthDef(\sr__k__tri, {
    arg freq=440, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFTri.kr(freq, phase, mul, add);
    Out.kr(outbus, out);
}).add;

// clip noise
SynthDef(\sr__k__clipnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFDClipNoise.kr(freq, mul, add);
    Out.kr(outbus, out);
}).add;

// step noise
SynthDef(\sr__k__lfnoise0, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFDNoise0.kr(freq, mul, add);
    Out.kr(outbus, out);
}).add;

SynthDef(\sr__k__lfnoise1, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise1.kr(freq, mul, add);
    Out.kr(outbus, out );
}).add;

SynthDef(\sr__k__lfnoise2, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise2.kr(freq).clip2 * mul + add;
    Out.kr(outbus, out );
}).add;

SynthDef(\sr__k__stepnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * TWChoose.kr(
        Dust.ar(1),
        [LFNoise0.kr(freq, mul, add), LFNoise1.kr(freq, mul, add), LFNoise2.kr(freq).clip2 * mul + add],
        [0.1, 0.4, 0.5]
    );
    Out.kr(outbus, out );
}).add;



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

// Stereo mix-node: LPF input, send summary to outbus
SynthDef(\sr__u__mixNode2, {
    arg inbus=0, outbus=2, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 2), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Quad mix-node: LPF input, send summary to outbus
SynthDef(\sr__u__mixNode4, {
    arg inbus=0, outbus=4, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 4), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Pent mix-node: LPF input, send summary to outbus
SynthDef(\sr__u__mixNode5, {
    arg inbus=0, outbus=5, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 5), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Hex mix-node: LPF input, send summary to outbus
SynthDef(\sr__u__mixNode6, {
    arg inbus=0, outbus=6, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 6), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);

// Oct mix-node: LPF input, send summary to outbus
SynthDef(\sr__u__mixNode8, {
    arg inbus=0, outbus=8, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 8), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);