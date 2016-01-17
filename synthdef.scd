// Sympli Romatikó
// module: SynthDefs
// ---------------
// Naming synths:
// \sr__<t>__<name>, where:
//     <t> - type of the synth, where:
//         g - granular (\bufnum points to a buffer with a sound file loaded)
//         e - electronic (if there is a \bufnum it can point to a buffer with a scale)
//         i - insert (effects)
//         p - percussion
//         s - spatialization
//         r - recording
//         u - utilities
//         k - control
//     <name> - something meaninful
//
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
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        amp=1, attenuate=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3;
    var in, out, signal;
    var trate, dur, pos, clk, ds, rate=1;
    // Conversion.
    ds = distance/3.44;
    rate = az.linlin(0, 1, 0.8, 1.2);
    trate = az.linlin(0, 1, 100, 0.2);
    dur = 4 / trate;
    clk = Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(ds));
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos, dur);
    signal = Mix.ar(in) * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__g__drone, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        amp=1, attenuate=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3;
    var in, out, signal;
    var trate, dur, pos, clk, ds, rate=1;
    // Conversion.
    ds = distance/3.44;
    rate = az.linlin(0, 1, 0.2, 2);
    trate = SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur = 12 / trate;
    clk = Impulse.kr(trate);
    pos = ax * BufDur.kr(bufnum);
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos + TRand.kr(0, 0.01, clk), dur);
    signal = Mix.ar(in) * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__g__gust, { // ~ gusts of wind
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        amp=1, attenuate=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3;
    var in, out, signal;
    var trate, dur, pos, clk, d, zz, ds;
    // Conversion.
    ds = distance/3.44;
    pos = (distance * 0.19 + 0.1).round(0.01);
    trate = az.linlin(0, 1, 0.1, 20);
    clk = Impulse.ar(trate);
    d = {Dwhite(0.1, 0.2, 1)};
    zz = {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf) * pos + 1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value] * 2, inf) / trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf)
    );
    // XXX - add Compander here to smooth out sometimes violent dynamics!
    signal = Mix.ar(in) * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__g__slic, { // slicing
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        amp=1, attenuate=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3;
    var in, out, signal;
    var trate, dur, pos, clk, rate=1, ds;
    // Conversion.
    ds = distance/3.44;
    rate = velocity.linlin(0, 1, 0.2, 2);
    trate = distance.linlin(0, 2.sqrt, 1, 100);
    dur = 8 / trate;
    clk = Dust.kr(trate);
    pos = ax * BufDur.kr(bufnum);
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, (2 ** WhiteNoise.kr(2)) * rate, BufFrames.ir(bufnum) * pos, dur, 0);
    signal = Mix.ar(in) * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__g__scratch, { // ~ chunks of sound
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        amp=1, attenuate=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3;
    var in, signal, out;
    var rate, pos, ds;
    // Conversion.
    ds = distance/3.44;
    rate = velocity.linlin(0, 1, 0.1, 1.9);
    // XXX - for finer control ise gx instead of ax
    pos = ax * BufDur.kr(bufnum);
    // Synthesis.
    in = BufRd.ar(1, bufnum, Lag.ar(K2A.ar(BufFrames.ir(bufnum) * pos), 4), 1);
    signal = in * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).send(s);


SynthDef(\sr__g__loop, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        pos=0, amp=1, attenuate=1, master=1, gate=1, rate=1, att=1, rel=1, ca=3, cr= -3;
    var in, signal, out, ds;
    ds = distance/3.44;
    in = PlayBuf.ar(1, bufnum,
        // slight disturbances of rate
        BufRateScale.kr(bufnum) * (rate + LFNoise1.kr(LFNoise1.ar(1.4, 1, 1.6), 0.15)),
        Impulse.ar(BufDur.kr(bufnum).reciprocal), BufFrames.ir(bufnum) * pos);
    signal = in * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(Env.asr(att, 1, rel, [ca, cr]), gate: gate, doneAction:2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out)
}).send(s);


SynthDef(\sr__g__loopdel, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        pos=0, amp=1, master=1, gate=1, rate=1, att=1, rel=1, ca=3, cr= -3;
    var in, signal, out, ds;
    ds = distance/3.44;
    in = PlayBuf.ar(1, bufnum,
        // slight disturbances of rate
        BufRateScale.kr(bufnum) * (rate + LFNoise1.kr(LFNoise1.ar(1.4, 1, 1.6), 0.15)),
        Impulse.ar(BufDur.kr(bufnum).reciprocal), BufFrames.ir(bufnum) * pos);
    signal = DelayL.ar(in, 0.3, ds) * amp;
    // Envelope.
    out = signal * master * EnvGen.kr(Env.asr(att, 1, rel, [ca, cr]), gate: gate, doneAction:2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out)
}).send(s);


SynthDef(\sr__g__unst, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        pos=0, amp=1, attenuate=1, master=1, gate=1, rate=1, att=1, rel=1, ca=3, cr= -3;
    var in, signal, out, ds;
    ds = distance/3.44;
    in = PlayBuf.ar(1, bufnum,
        TWChoose.kr(
            Dust.kr(0.01),
            [
                BufRateScale.kr(bufnum) * TRand.kr(0.8, 1.1, Dust.kr(2)),
                BufRateScale.kr(bufnum) * TRand.kr(-0.8, -1.1, Dust.kr(2)),
            ],
        [0.6, 0.4]),
        Dust.kr(0.2),
        TRand.kr(0, BufFrames.ir(bufnum), Dust.kr(0.2))
    );
    signal = RLPF.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(Env.asr(att, 1, rel, [ca, cr]), gate: gate, doneAction:2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out)
}).send(s);


SynthDef(\sr__g__chunk, { // ~ chunks of sound
    arg bufnum=0, inbus=30, route=20, trigID=80,
        ax=0, ay=0, az=0, velocity=10, distance=0.5,
        pos=0, amp=1, attenuate=1, master=1, gate=1, rate=1, att=1, rel=1, ca=3, cr= -3;
    var in, signal, out;
    var trate, ds;
    // Conversion.
    ds = distance/3.44;
    trate = velocity.linlin(0, 1, 0.1, 1.9);
    // Synthesis.
    in = PlayBuf.ar(1, bufnum,
        rate * BufRateScale.kr(bufnum),
        Dust.kr(0.5),
        TRand.kr(0, BufFrames.ir(bufnum), Dust.kr(0.5))
    );
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5) * amp * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).send(s);


SynthDef(\sr__g__grain, { //individual grain through ambisonic
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, master=1, att=1, rel=1, ca=3, cr= -3,
        pos=0.0, rate=1, dur=0.1, lag=0;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum,
        Lag.ar(K2A.ar(BufRateScale.kr(bufnum) * rate), lag),
        1, BufFrames.ir(bufnum) * pos, 0);
    // Envelope.
    out = in * amp * master * (EnvGen.kr(Env.perc(0.01, dur), doneAction:2) - 0.001);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).send(s);


// ELECTRONIC SYNTHS
//
SynthDef(\sr__e__silent, {
	arg route=0, gate=1, att=1, rel=1, ca=3, cr= -3;
	Out.ar(route,
        Silent.ar() * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2)
    );
}).add;


SynthDef(\sr__e__lowe, { // the "lowe"st
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.05, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    in = SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp * attenuate);
    signal = RLPF.ar(Limiter.ar(Mix.ar(in)), distance.linlin(0, 2.sqrt, 500, 10000), 0.5);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__probe, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.5, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    2.do({in = AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, amp * attenuate)});
    signal = Mix(in) * master;
    // Envelope.
    out = signal * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__cmb, { // CMB ~ "Cosmic Backgroud Radiation"
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.5, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    signal = LeakDC.ar(in * attenuate);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__melo, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.5, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0;
    var note, in, out, signal;
    // Conversion.
    note = (
        DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 24), 12, 1, offset)
        + LFNoise1.kr([3,3], 0.04)    // add some low freq stereo detuning
    ).midicps;
    // Synthesis.
    in = RLPF.ar(
        LFSaw.ar(note)
        + Impulse.ar(XLine.kr(note, note + 100, 1.5), 0.0)
        + Normalizer.ar(LorenzL.ar(az.linlin(0, 1, 10, SampleRate.ir),
            LFNoise0.kr(1.0.rand, 2, 10), r: LFNoise0.kr(1.0.rand, 20, 38), b: LFSaw.kr(0.2).exp.cubed), 1),
        LFNoise0.kr(0.2, 38, 115).midicps, 0.1,
        mul:(amp * velocity * attenuate).scurve // sigmoid: the faster, the more present
        // mul:velocity // simply the faster the louder
    );
    in = [in, DelayN.ar(in, 0.04, 0.04)];
    4.do({in = AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4)});
    signal = Mix.ar(in);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__ringz, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.2, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    signal = Limiter.ar(MidEQ.ar(Mix.ar(in), 14000, 0.7, 8), amp * attenuate);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__pulse, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    in = Limiter.ar(MidEQ.ar(in, [200, 1400], 0.7, 8), amp * attenuate);
    signal = Mix.ar(in);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__analog, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.05, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0, threshold=0.7, scope=12;
    var note, in, out, signal;
    var rq;
    var freq, trig, timer, mul, add;
    // Conversion.
    mul = velocity.linlin(0, 1, 1850, 2350);
    add = velocity.linlin(0, 1, 2250, 2800);
    trig = velocity > 0.33; // high velocity causes sharp switch
    timer = Timer.kr(trig);
    freq = TRand.kr(trig:Delay2.kr(Dust.kr(1)));

    // XXX - find and remove "dumb" timbre
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
        [ // If cutoff is variable, RQ depends on velocity.
            velocity.linlin(0, 1, 0.5, 0.1),
            0.1 // constant cutoff means constant RQ
        ]
    );
    note = SelectX.kr(BinaryOpUGen('<', az, threshold) * 2,
        [   // Go melodic above height threshold.
            DegreeToKey.kr(bufnum, az.linlin(threshold, 1, 0, scope), 12, 1, offset),
            az.linlin(0, threshold, (offset-6), offset) // bottom to middle change continuously
        ]
    );
    // Synthesis.
    in = Mix.fill(8, { LFSaw.ar((note + 0.1.rand2).midicps) * attenuate });
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


// XXX - to-do:
// - add less obvious elevation based control (az)
// - more effective compander, possibly multiband! don't allow it to burst!
SynthDef(\sr__e__neural, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


// XXX - make it a descent synth.
SynthDef(\sr__e__dempad, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, elevation=0, azimuth= -0.5pi, distance=1, velocity=0.5,
        offset=24, cutoff=0;
    var detune=0.2, // XXX - increase detune on extreme velocities (?)
        lag=0.1, // XXX - make it dependent on param
        rate=3, // XXX - make it dependent on param
        tones=50, // XXX - make it dependent on velocity with curve
        noOfSynths=20;
    var in, out, signal, freq;
    // var freq = offset + #[0, 4, 6, 7, 11]; // XXX - delete after alternative solution is completed Scale

    in = Mix.fill(tones,
        { |index|
            var trig = Impulse.kr(0) + Dust2.kr(rate);
            var pitches = Lag.kr(
                Select.kr(
                    Demand.kr(trig, 0, Drand([0, 1, 2], inf)),
                    // freq // original
                    DegreeToKey.kr(
                        [0,3,5,8,10].as(LocalBuf),
                        elevation.linlin(-0.5pi, 0.5pi, 0, 24),
                        12, 1, offset
                    )
                    // DegreeToKey.kr(bufnum, index.linlin(0, tones, 0, 6), 12, 1, offset)
                )
                + TRand.kr(detune.neg, detune, trig),
                lag * Rand(0.8, 1.2)
            ).midicps;

            SinOscFB.ar(
                pitches,
                Rand(0, 0.8),
                amp * Lag.kr(TRand.kr(0.8, 1.0, trig), lag * Rand(0.8, 1.2))
            )
            * ( if(index < noOfSynths, 1, 0) );
        }
    );
    signal = Mix(in) * (1 / noOfSynths) * Line.kr(0.0, 1.0, 0.3);
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__growl, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.3, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
        gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
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
    rate = velocity.linlin(0, 1, 2, 4).round;
    trig = Impulse.kr(0) + Dust2.kr(rate);
    lag = velocity.lincurve(0, 1, 0.5, 0.05, -4);
    detune = velocity.lincurve(0, 1, 0.1, 0.5, 4);
    note = DegreeToKey.kr(bufnum,
        // guide params for fine control of pitch and threshold
        // XXX - substitute gz with gAzimuth.linlin(0pi, 1pi, 0, 15) - ???
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
            * ( if(index < noOfSynths, 1, 0) );
        }
    );
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutOff, rq), cutOff, rq);
    in = Limiter.ar(MidEQ.ar(in, [200, 1400], 0.7, 8), amp * attenuate);
    signal = Mix.ar(in);

    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__gauss, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.2, master=1, gate=1, att=1, rel=1, ca= -3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var cutOff, rq, dur, width;
    // Conversion.
    cutOff = distance.linexp(0.0, 1.0, 10000, 200); // different from arg cutoff!
    rq = distance.linexp(0, 2.sqrt, 1, 0.2);
    dur = SinOsc.ar(LinExp.kr(az, 0.001, 1, 0.05, 5000) * [1, 1.1]).range(0.0006, 0.01);
    width = SinOsc.ar(0.5 * [1, 1.1]).range(0.01, 0.3);
    // Synthesis.
    in = (
        LFGauss.ar(dur, width)
        + SinOsc.ar(
            az.linexp(0, 1, 0.01, 5000) * [1, 1.1],
            mul:(az.clip(0, 1) * velocity).sqrt // sqrt boosts mul
        )
    );
    in = Limiter.ar(
        MidEQ.ar(Mix.fill(10, in), 14000, velocity.lincurve(0, 1, 0.8, 0.1, 2), 8),
        amp * attenuate);
    signal = RLPF.ar(RLPF.ar(Mix.ar(in), cutOff, rq), cutOff, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__noisy, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.02, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    4.do({in = AllpassN.ar(in, 0.5, [0.5.rand, 0.5.rand], 4, amp)});
    signal = Mix.ar(in) * attenuate;
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).send(s);


SynthDef(\sr__e__entro, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0;
    var freq, shift, rq, in, out, signal;
    var options, trig, timer;
    // Conversion.
    rq = distance.linlin(0, 2.sqrt, 0.2, 1);
    freq = velocity.linexp(0, 1, 20, 1000);
    shift = ((velocity ** 0.2 * 30) ** 3).lag(0.5); // boost velocity
    trig = velocity > 0.2;
    timer = Timer.kr(trig);
    in = TChoose.ar((timer > 0.25) * trig, [
        RLPF.ar(Normalizer.ar(LorenzL.ar(az.linlin(0, 1, 10, SampleRate.ir),
            LFNoise0.kr(1, 2, 10), r: LFNoise0.kr(1, 20, 38), b: LFSaw.kr(0.2).exp.cubed), 1),
            LFPulse.kr(LFSaw.ar(0.2).exp.cubed, 0.5, 2500, 3500),
            velocity.scurve),
        Saw.ar((1..15) * LFNoise0.kr(5, 10, 50) + SinOsc.ar((6..2) * 0.5))
        ]
    );
    in = Mix.ar(in) * velocity * amp * attenuate;
    signal = RLPF.ar(RLPF.ar(in, shift, rq), shift, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__humm, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0;
    var note, in, out, signal;
    // Conversion.
    note = (DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 15), 12, 1, offset)
        + LFNoise1.kr([3, 3], 0.04)).midicps;    // add some low freq stereo detuning
    // Synthesis.
    in = LFSaw.ar((1..5) * note, abs(velocity * 2), velocity)
         + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
    in = Mix.ar(in) * amp * attenuate;
    signal = RLPF.ar(in, LinLin.kr(velocity, 0, 1, 80, 30).midicps, velocity);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__radio, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.06, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    ) * amp * attenuate;
    signal = Mix.ar(in);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__wasp, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.02, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var cutOff, rq, azThresh=0.7;
    // Conversion.
    cutOff = distance.linexp(0.0, 1.0, 500, 10000); // different from arg!
    rq = distance.linlin(0, 2.sqrt, 0.5, 1);
    note = DegreeToKey.kr(bufnum, az * 15, 24, 1, offset);
    // Synthesis.
    in = Formlet.ar(
        in: LPF.ar(
            Saw.ar(
                (1..5)
                * LFClipNoise.ar(
                    SinOsc.ar(0.1, 0, 0.5, 1), 10, note
                )
            )
            + SinOsc.ar((6..2), velocity ** 3).exprange(0.05, 50), 300
        )
        + Impulse.ar(
            (0..4)
            + SinOsc.ar((4..8) * 0.02).exprange(0.3, 300)
        ),
        freq: (1..5)
        * SinOsc.ar((5..9) * az * 0.05).exprange(200, 2000)
        * SinOsc.ar(SinOsc.ar((2..6) * az*0.1, 0, 0.1), 0, 0.1, 1),
        attacktime: velocity.linlin(0, 1, 0.100, 0.0010),
        decaytime: velocity.linlin(0, 1, 0.015, 0.0015),
        mul: amp * attenuate
    );
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutOff, rq), cutOff, rq);
    signal = Mix.ar(in);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__therem, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=1.5, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0;
    var in, out, signal;
    var fbase=50000, shift=5000, freq;
    // Conversion.
    freq = az.linexp(0.5, 1, fbase, fbase + shift);
    // Synthesis.
    in = BPF.ar(
        (SinOsc.ar(fbase, 0, amp) * SinOsc.ar(freq)),
        freq - (fbase - 50),
        0.3
    );
    // 55000 - 16500
    in = MidEQ.ar(in, freq-38500, 0.7, -60);
    signal = FreeVerb.ar(in, 0.65, 0.65, 0.5, (amp * attenuate).clip(0, 1));
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


// XXX
// WARNING! New synths for matrix control!

// XXX - the idea:
//       VOsc3 can be swept smoothly across wavetables (buffers)
//       each buffer is a kind of "cloud" in space
// XXX - advanced: clouds are "stretchy" - if a cloud is being "touched"
//       with a velocity high enough, it stretches towards ... the center?
//       or in the direction of an attractor (hand)? use Delay in choosing
//       the cloud!
// XXX - the further from the center, the higher the inharmonicity, i.e. clouds
//       affect signal in a way that they rip apart partials from the multiples
//       of a fundamental freq.
SynthDef(\sr__e__tbl, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        azimuth= -0.5pi, distance=0.1, elevation=0, velocity=0.5,
        offset=36, cutoff=1000, rq=0.5, scope=12;
    var in, out, signal, freq, detune, stretchFactor, blob;
    // Conversion & Clip.
    cutoff = cutoff.linlin(-1, 1, 10, 20000);
    offset = offset.clip(1, 127);
    freq = offset.midicps;
    blob = distance.linlin(0.0, 1.0, 0, 7);
    // take into consideration growth of the octave distance with pitch
    stretchFactor = ((offset + 12).midicps - freq).max(3);
    detune = velocity.linexp(0, 1, 2, stretchFactor); // XXX - distance should also contribute to detune!
    // Synthesis.
    amp = amp * velocity.scurve;
    in = VOsc3.ar(bufnum+blob, freq, freq+detune, freq-detune, amp); // XXX - add when done with VOsc
    // in = VOsc.ar(bufnum+blob, freq, mul:amp);
    // filter
    signal = Limiter.ar(Mix.ar(attenuate * in));
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__sawy, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.05, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
        offset=36, cutoff= -0.9, rq=0.5, scope=12;
    var note, in, out, signal;
    // Conversion.
    note = DegreeToKey.kr(bufnum, elevation.linlin(-0.5pi, 0.5pi, 0, scope), 12, 1, offset);
    // Clip.
    // cutoff = cutoff.linlin(-1, 1, 10, 20000);
    amp = amp.clip(0, 1);
    note = note.clip(1, 127);
    // Synthesis.
    in = Mix.fill(8, {LFSaw.ar((note + 0.1.rand2).midicps, 0, amp) * attenuate});
    // filter
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;


SynthDef(\sr__e__dust, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.05, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
        offset=36, cutoff=1000, rq=0.5, scope=12;
    var note, in, out, signal;

    // XXX - adapt this!
    // var z = Decay.ar(Dust.ar(1.dup, 0.1), 0.3, WhiteNoise.ar);
    // BufCombC.ar(LocalBuf(SampleRate.ir, 2), z, XLine.kr(0.0001, 0.01, 20), 0.2);
    // }.play

    // Conversion.
    note = (
        DegreeToKey.kr(bufnum, elevation.linlin(-0.5pi, 0.5pi, 0, scope), 12, 1, offset)
        + LFNoise1.kr([3, 3], 0.04) // add some low freq stereo detuning
    );
    // Clip.
    cutoff = cutoff.linlin(-1, 1, 10, 20000);
    amp = amp.clip(0, 1);
    note = note.clip(1, 127).midicps;
    // Synthesis.
    in = LFSaw.ar((1..5) * note, abs(velocity * 2), velocity)
         + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
    in = Mix.ar(in) * amp * attenuate;
    // filter
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).add;

SynthDef(\sr__e__wind, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=1, attenuate=0.05, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
        offset=36, cutoff=1000, rq=0.5, scope=12;
	var in, out, signal;
    var fbase, shift;
    // Conversion.
    fbase = offset.linlin(-1, 1, 10, 40);
    shift = ((velocity * 30) ** 3).lag(0.01);
    // Clip.
    cutoff = cutoff.linlin(-1, 1, 10, 20000);
    amp = amp.clip(0, 1);
    // Synthesis.
    in = Formlet.ar(
        WhiteNoise.ar(SinOsc.ar(fbase, shift, 0.5, 1)).min(1),
        // WhiteNoise.ar(SinOsc.ar(fbase, shift, 0.5, 1)).min(1) + SinOsc.ar(fbase, shift),
        LFNoise1.ar(TRand.kr(trig:Delay2.kr(Dust.kr(0.5))), 2450, 2550),
        0.01, 0.1
    ).softclip;
    in = [in, DelayN.ar(in, 0.04, 0.4)];
    in = Mix.fill(4, {AllpassN.ar(in, 0.5, [0.5.rand, 0.5.rand], 4, amp) * attenuate});
    // filter
    signal = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq);
    // Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(out));
    Out.ar(route, out);
}).send(s);


SynthDef(\sr__i__delay, {
    arg bufnum=0, inbus=30, route=20, trigID=80,
        amp=0, attenuate=0.05, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        azimuth= -0.5pi, distance=0.5, elevation=0, velocity=0.5,
        param1=0, param2=0;
    var in, out, signal;
    // Pass through.
    in = InFeedback.ar(inbus, 1);
    signal = AllpassC.ar(in, param1, param1*1.2, 3, amp);
    // Envelope.
    out = signal * EnvGen.kr(Env.adsr(att, 0.1, master, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(route, out);
}).send(s);


// DRUMS AND PERCUSSION
// (Warning! Different enveloping.)
//
SynthDef(\sr__p__kick, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr=3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0;
    var in, out, signal;
    // Synthesis.
    in = SinOsc.ar([60.742, 57.2532], 0, 0.5);
    in = BPeakEQ.ar(in, 1900, 1, 12.0) + LPF.ar(Decay.ar(WhiteNoise.ar(0.05), 0.3, 0.1), 1000);
    signal = Mix(in * master);
    // Envelope.
    out = signal * EnvGen.kr(Env.perc(0.05, 1, 1, -6), doneAction:2);
    Out.ar(route, out);
}).add;


SynthDef(\sr__p__hat, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr=3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
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
    // Envelope.
    out = signal * EnvGen.kr(Env.perc(0.05, 1, 1, -6), doneAction:2);
    Out.ar(route, out);
}).add;


SynthDef(\sr__p__snare, {
    arg bufnum=0, inbus=30, route=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr=3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5,
        offset=36, cutoff=0;
    var in, out, signal;
    // Synthesis.
    in = LPF.ar(
        Pulse.ar(120),
        EnvGen.ar(Env.perc(0.05, 0.2, 0.2, -4), gate) * 1000 + 30
    ) + BPF.ar(HPF.ar(WhiteNoise.ar, 500), 1500);
    signal = Mix(in * master);
    // Envelope.
    out = signal * EnvGen.kr(Env.perc(0.05, 1, 1, -6), doneAction:2);
    Out.ar(route, out);
}).add;


// SPATIALIZERS
//
// - spatializer has no attack, but longer \rel to ensure that it will be released after corresponding Gen synth,
//   since \rel param is sent to both Gen synth and Spatializer.
//

SynthDef(\sr__s__ambisonic2, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.75pi], speakerElev= #[0, 0], speakerDist= #[2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.01, depth, 10000, 1000),
        0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic3, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.17pi, -0.83pi, 0.5pi], speakerElev= #[0, 0, 0],
        speakerDist= #[2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
    azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic4, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= #[0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
    azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic5, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.5pi, -0.75pi, 0.75pi, 0.25pi], speakerElev=[0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic6, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.5pi, -0.75pi, 0.75pi, 0.5pi, 0.25pi], speakerElev=[0, 0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic7, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.25pi, 0],
        speakerElev= #[0, 0, 0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic8, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0],
        speakerElev= #[0, 0, 0, 0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic9, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0.15pi, 0],
        speakerElev= #[0, 0, 0, 0, 0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__ambisonic10, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth= -0.5pi, elevation=0, elevClip=0.01pi, distance=0, depth=5,
        speakerAzim= #[-0.15, -0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0.15pi, 0],
        speakerElev= #[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        speakerDist= #[2, 2, 2, 2, 2, 2, 2, 2, 2, 2], maxDist=2;
    var w, x, y, z, r, s, t, u, v, scaleFlag=1,
        in, signal, out, room, mix;
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    in = In.ar(route, 1);
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__vbap4, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0.25pi, distance=0.5, elevation=0,
        elevClip=0.1pi, depth=5;
    var speakerAzim=[-45, -140, 140, 45], speakerElev=0, speakerBuff, spread=0;
    var in, amp, signal, out, room, mix;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    amp = distance.lincurve(0.01, 5, 1, 0.01, 4);
    azimuth = azimuth.linlin(-1pi, 1pi, -180, 180);
    elevation = elevation.linlin(-0.5pi, 0.5pi, -90, 90);
    spread = [100, 0, 4].asSpec.map(distance); // the closer the signal, the more speakers involved (welch-like)
    in = In.ar(route, 1) * amp;
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    out = VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(outbus, out);
}).send(s);


SynthDef(\sr__s__vbap2, {
    arg route=20, outbus=0, gate=1, rel=1,
        azimuth=0.25pi, distance=0.5, elevation=0,
        elevClip=0.1pi, depth=5;
    var speakerAzim=[-45, 45], speakerElev=0, speakerBuff, spread=0;
    var in, amp, signal, out, room, mix;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    distance = distance.linlin(0, 2.sqrt, 0.01, depth);
    mix = distance.linexp(0.01, depth, 0.1, 0.8);
    room = distance.linexp(0.01, depth, 0.2, 1);
    amp = distance.lincurve(0.01, 5, 1, 0.01, 4);
    azimuth = azimuth.linlin(-1pi, 1pi, -180, 180);
    elevation = elevation.linlin(-0.5pi, 0.5pi, -90, 90);
    spread = [100, 0, 4].asSpec.map(distance); // the closer the signal, the more speakers involved (welch-like)
    in = In.ar(route, 1) * amp;
    in = RLPF.ar(
        FreeVerb.ar(in, mix, room, 0.2),
        distance.linlin(0.5, depth, 10000, 1000),
    0.5);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    out = VBAP.ar(2, signal, speakerBuff.bufnum, azimuth, elevation, spread);
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
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.5, velocity=0.5;
    var in, out, signal, ds;
    // Conversion.
    ds = distance/3.44;
    // Synthesis.
    in = InFeedback.ar(inbus, 1);
    signal = RLPF.ar(
        DelayL.ar(FreeVerb.ar(in, distance.clip(0.01, 1), ds, 0.2), 0.3, ds),
        distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
    // Envelope.
    out = signal * EnvGen.kr(Env.adsr(att, 0.1, master, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).send(s);


// MODULATORS
//
SynthDef(\sr__k__sine, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * SinOsc.ar(lfo, phase, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out);
}).add;

SynthDef(\sr__k__saw, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * Saw.kr(lfo, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out);
}).add;

SynthDef(\sr__k__tri, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFTri.kr(lfo, phase, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out);
}).add;

// clip noise
SynthDef(\sr__k__clipnoise, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFDClipNoise.kr(lfo, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out);
}).add;

// step noise
SynthDef(\sr__k__lfnoise0, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFDNoise0.kr(lfo, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out);
}).add;

SynthDef(\sr__k__lfnoise1, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise1.kr(lfo, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out );
}).add;

SynthDef(\sr__k__lfnoise2, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise2.kr(lfo).clip2 * mul + add;
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out );
}).add;

SynthDef(\sr__k__stepnoise, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * TWChoose.kr(
        Dust.ar(1),
        [LFNoise0.kr(lfo, mul, add), LFNoise1.kr(lfo, mul, add), LFNoise2.kr(lfo).clip2 * mul + add],
        [0.1, 0.4, 0.5]
    );
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out);
}).add;

SynthDef(\sr__k__sinmod, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * SinOsc.kr(LFNoise0.kr(lfo, mod_mul, mod_add), LFDClipNoise.kr(lfo), mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out);
}).add;

SynthDef(\sr__k__sawmod, {
    arg outbus=0, lfo=1, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * Saw.kr(LFNoise0.kr(lfo, mod_mul, mod_add), mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, Saw.kr(lfo, mul, add));
}).add;


// UTILITIES
//
SynthDef(\sr__u__grain, { //individual grain (can only be sent to audio in).
    arg bufnum=0, busnum=0, amp=1, att=1, rel=1, ca=3, cr= -3,
    pos=0.0, rate=1, dur=0.1;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate, 1, BufFrames.ir(bufnum) * pos, 0);
    // Envelope.
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
    // Envelope.
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
