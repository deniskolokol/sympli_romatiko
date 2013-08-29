/*
Sympli Romatiko SynthDefs

Naming synths:
\sr__<t>__<name>, where:
<t> - type of the synth, where:
    g - granular (\bufnum points to a buffer with a sound file loaded)
    e - electronic (if there is a \bufnum it can point to a buffer with a scale)
    p - percussion
    s - spatialization
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
SynthDef(\sr__g__dron, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=0, cutoff=0, maxVel=30;
    var in, out, signal;
    var trate, dur, pos, clk, d, rate=1;
    // Conversion.
    rate = az.linlin(0,1, 0.2,2);
    trate = SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur = 12 / trate;
    clk = Impulse.kr(trate);
    pos = ax * BufDur.kr(bufnum);
    d = distance/3.44;
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos + TRand.kr(0, 0.01, clk), dur, amp: amp);
    in = RLPF.ar(
        DelayL.ar(FreeVerb.ar(in, distance.clip(0.01, 1), d, 0.2), 0.3, d),
        distance.linlin(0, 1, 10000, 1000), 0.5);
    //Envelope.
    signal = Mix.ar(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


// ELECTRONIC SYNTHS
// starfield (Ambisonic 4)
SynthDef(\sr__e__lowe, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
    var note, scale, in, out, signal;
    var q=0.1, a=2pi, b=400, c=0, dir=[1, 0], frate=1, freq=400, xx=(1..5)*20;
    // Conversion.
    dir = dir.put(1, az.linlin(0, 1, -pi, pi));
    dir = dir.put(0, ax.linlin(0, 1, -pi, pi));
    q = dir[1].atan2(dir[0]) + pi;
    a = frate.linlin(0,2, 2pi, 0);
    b = dir[1].hypot(dir[0]) * 400 + 200;
    c = velocity.linlin(1, 30, 50, 150);
    // Synthesis.
    in = SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp * 0.05);
    in = RLPF.ar(FreeVerb.ar(Limiter.ar(in)), distance.linlin(0, 1, 500, 10000), 0.5);
    signal = Mix.ar(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__probe, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
    var note, scale, in, out, signal;
    var rate=1, dtl=0.01, dtr=0.05;
    // Conversion.
    rate = velocity.linlin(1, maxVel, 0.5, 5) * exprand(3, 8);
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
    2.do({in= AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2)});
    signal = Mix.ar(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


// CMB stands for "Cosmic Backgroud Radiation" (a loose aesthetic assosiation).
SynthDef(\sr__e__cmb, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
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
    in = RLPF.ar(FreeVerb.ar(in, distance, distance/3.44, 0.2),
        distance.linlin(0, 1, 10000, 500), 0.5, mul: amp);
    signal = Mix.ar(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__melo, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
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
    in = RLPF.ar(
        FreeVerb.ar(LeakDC.ar(in * 0.03), distance, distance/3.44, 0.2),
        distance.linlin(0, 1, 10000, 500), 0.5);
    signal = Mix.ar(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__ringz, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
    var scale, in, out, signal;
    var fbase, reso, shift;
    // Conversion.
    fbase = distance.linexp(0, 1, 10, 40);
    reso = distance.linexp(0, 1, 200, 5000);
    shift = (velocity ** 3).lag(0.01);
    // Synthesis.
    in = Ringz.ar(SinOsc.ar(fbase, shift, amp * 0.02), reso, 0.01).softclip;
    5.do({in});
    signal = Mix.ar(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__pulse, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
    var note, scale, in, out, signal;
    var cutOff, rq, azThresh=0.7;
    // Conversion.
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10]);
    cutOff = distance.linexp(0.0, 1.0, 200, 10000); // different from arg!
    rq = distance.linlin(0.0, 1.0, 0.5, 1.0);
    note = SelectX.kr(BinaryOpUGen('<', az, azThresh) * 2,
        [
            DegreeToKey.kr(LocalBuf.newFrom(scale), // go melodic above height threshold
                (az - azThresh).linlin(0, 1 - azThresh, 0, 12), 12, 1, offset
            ).midicps,
            velocity.linlin(1,30, 5,150) // continuos change at the bottom
        ]
    );
    // Synthesis.
    in = Blip.ar(SinOsc.kr(0.5, 0, LFDNoise1.kr(1.5), note), 100, 0.2);
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutOff, rq, amp), cutOff, rq, amp);
    in = Compander.ar(in, in, 0.002, slopeBelow: 0.33, slopeAbove: 0.5, clampTime: 0.01, relaxTime: 0.01);
    signal = Mix.ar(in * master);
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__analog, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
    var scale, note, in, out, signal;
    var rq, azThresh=0.7;
    // Conversion.
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10]);
    cutoff = SelectX.kr(BinaryOpUGen('<', cutoff, 0) * 2,
        [ // Positive cutoff falls at the freq range 200..5000
            SelectX.kr(BinaryOpUGen('<', velocity, maxVel * 0.33) * 2, [ // high velocity causes sharp switch
                LFDClipNoise.ar(az, 34, 78),
                LFNoise1.ar(TRand.kr(trig:Delay2.kr(Dust.kr(1))), 34, 90)
            ]).midicps,
            5666 // zero or negative cutoff means constant
        ]
    );
    rq = SelectX.kr(BinaryOpUGen('==', cutoff, 5666) * 2,
        [ // If cutoff is variable, RQ depends on distance.
            distance.linlin(0.0, 1.0, 0.07, 1.0),
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
    in = RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq, amp);
    signal = in * master;
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__humm, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30,
        mnote=0, freqBase=85, mod=0; // WARNING! This is obsolete, remove when finishing notes via .kr bus!
    var scale, note, in, out, signal;
    // Synthesis.
    in = RLPF.ar(
        LFSaw.ar(mnote + freqBase + mod.linlin(-1, 1, -40, 40)),
        LinLin.kr(mod, -1, 1, 80, 30).midicps,
        0.1,
        amp.clip(0.01, 0.99)
    );
    signal = in * master;
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__lfsaw, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30,
        mnote=0, freqBase=85, mod=0; // WARNING! This is obsolete, remove when finishing notes via .kr bus!
    var scale, note, in, out, signal;
    // Conversion.
    in = LFSaw.ar(
        mnote + freqBase + mod.linlin(-1, 1, -50, 0),
        (amp * mod.linlin(-1,1, 0.01, 0.25) ).clip(0.01, 0.99)
    );
    signal = in * master;
    //Envelope.
    out = signal * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


// DRUMS AND PERCUSSION (different enveloping)
SynthDef(\sr__p__kick, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
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
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
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
        amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
        offset=36, cutoff=0, maxVel=30;
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


// Spatializers
//
// - spatializer has no attack, but longer \rel to ensure that it will be released after corresponding Gen synth,
//   since \rel param is sent to both Gen synth and Spatializer.
//
// Ambisonic notes:
// - distance of the object from the center should always be corrected with respect to field depth.
// - distance artificially moved to 0.5 from the center to eliminate feedback.

SynthDef( \sr__s__ambisonic2, {
    arg inbus=20, outbus=0, amp=1, gate=1, rel=1, azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v;
    var in, signal, out;
    distance = distance.linlin(0.0, 1.41, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance, amp);
    out = FMHDecode1.stereo(w, z);
    Out.ar(outbus, out);
}).send(s);


SynthDef( \sr__s__ambisonic4, {
    arg inbus=20, outbus=0, amp=1, gate=1, rel=1, azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
        maxDist=3, scaleFlag=1,
        in, signal, out;
    distance = distance.linlin(0.0, 1.41, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance, amp);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


SynthDef( \sr__s__ambisonic8, {
    arg inbus=20, outbus=0, amp=1, gate=1, rel=1, azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var w, x, y, z, r, s, t, u, v,
        speakerAzim=[-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev=0,
        speakerDist=[6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1,
        in, signal, out;
    distance = distance.linlin(0.0, 1.41, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance, amp);
    out = FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);


// ````````````````````````````````````````````````
// 				     OLD SYNTHDEFs
//
//
// ================================================
//
// 					   Universal
//
// ================================================
// mono recording synth
SynthDef(\recsyn_1, { arg inbus, bufnum= 0, amp= 1;
    DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).send(s);

// universal synth for recording into buffer
SynthDef( \syninbuff, {
    arg bufnum, busnum = 0, volIn = 0.8, loop= 1, dur= 1, gate= 0;
    RecordBuf.ar(
        InFeedback.ar(busnum)
        * EnvGen.kr(
            Env.linen(0.1, dur-0.2, 0.1, volIn, \welch),
            gate: Impulse.kr(gate.reciprocal)
        ),
        bufnum, 0, volIn, 0, 1, loop, 1
    ); // envelope trigger doesn't work!!!
}).send(s);

// individual grain (can only be sent to audio in).
SynthDef(\sr_grain, {
    arg bufnum=0, busnum=0, amp=1, att=1, rel=1, crva=3, crvr= -3,
    pos=0.0, rate=1, dur=0.1;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate, 1, BufFrames.ir(bufnum) * pos, 0);
    //Envelope.
    out = in * (EnvGen.kr(Env.perc(0.01, dur), doneAction:2) - 0.001);
    Out.ar(busnum, out);
}).add;

// sample player (can only be sent to audio in).
SynthDef(\sr_play, {
    arg bufnum=0, busnum=0, amp=1, att=1, rel=1, gate=1, crva=3, crvr= -3,
    pos=0.0, rate=1, dur=0.1;
    var in, out;
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate, 1, BufFrames.ir(bufnum) * pos, 1);
    //Envelope.
    out = in * EnvGen.kr(Env.asr(att, amp, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(busnum, out);
}).add;



// ================================================
//
// 					   Ambisonic 2
//
// ================================================

// audio in (Ambisonic 2)
SynthDef(\audioin_1_ambisonic2, {
    arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=1, distance=1, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, dl, env, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    env= EnvGen.kr(Env.asr(att, master, rel, [crva, crvr]), gate: gate, doneAction: 2);
    dl= DelayL.ar(InFeedback.ar(inbus, 1), 110/344, distance/3.44);
    in= RLPF.ar(
        FreeVerb.ar(
            InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(outbus, out)
    }
).add;

// buffer player (Ambisonic 2)
SynthDef(\sr_play_ambisonic2, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=0.5, rel= 1, gate=1, done= 2,
    azimuth=0, elevation=0, distance=1, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var env, signal, in, out, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
    in= PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2) * env;
    signal= RLPF.ar(
        FreeVerb.ar(
            in,
            distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
        ),
        distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).add;

// == GRANULAR SYNTHS
// "regular" granulating (Ambisonic 2)
SynthDef( \sr_regu_ambisonic2, { // regular
    arg bufnum= 0, busnum= 0, amp=0.1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rate=1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
    dur= 4 / trate;
    clk= Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(azimuth));
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos,
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).add;

// "drone" (Ambisonic 2)
SynthDef( \sr_dron_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rate=1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
    trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur= 12 / trate;
    clk= Impulse.kr(trate);
    pos= ax*BufDur.kr(bufnum);
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos + TRand.kr(0, 0.01, clk),
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000,500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).add;

// "gusts of wind" (Ambisonic 2)
SynthDef( \sr_gust_ambisonic2, {
    arg bufnum= 0, busnum= 0, ax=0, amp=1, master=1, gate=1, rate= 1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=1, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, d, zz, signal, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    pos= round((distance*0.19)+0.1, 0.01);
    trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
    clk= Impulse.ar(trate);
    d= {Dwhite(0.1, 0.2, 1)};
    zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).add;

// "slicing" (Ambisonic 2)
SynthDef( \sr_slid_ambisonic2, {
    arg bufnum= 0, busnum= 0, ax=0, amp=1, master=1, gate=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
    trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
    dur= 8 / trate;
    clk= Dust.kr(trate);
    pos= ax * BufDur.kr(bufnum);
    rateratio= (2 ** WhiteNoise.kr(2)) * rate;
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rateratio,
        centerPos: pos,
        dur: dur,
        amp: amp * rateratio.linlin(0,4, 1,0.5)
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
        distance.linlin(0,1.41, 10000,500), 0.5)
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).add;

// looper (Ambisonic 2)
SynthDef(\sr_loop_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, gate=1, amp=1, master=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, signal, startPos=0.0, rate=1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi,0.5pi, 0.1,1.9);
    in = PlayBuf.ar(
        1,
        bufnum,
        rate*BufRateScale.kr(bufnum),
        Impulse.ar(BufDur.kr(bufnum).reciprocal),
        BufFrames.ir(bufnum)*startPos
    )
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, amp);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out)
}).add;

// ================================================
//
// 					   Ambisonic 4
//
// ================================================

// audio in (Ambisonic 4)
SynthDef(\audioin_1_ambisonic4, {
    arg bufnum=0, busnum=0, inbus=0, gate=1, amp=1, master=1, att=1, rel=1, crva=3, crvr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
    depth=5, maxVel=30, elevClip=0.1pi;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist,
    in, out, signal;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    // Synthesis.
    in= RLPF.ar(
        FreeVerb.ar(
            InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.09), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 1000), 0.5, mul: amp
    );
    //Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, az.linlin(0,1, -0.5pi,0.5pi).clip2(elevClip), dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).add;

// buffer player (Ambisonic 4)
SynthDef(\sr_play_ambisonic4, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=1, rel=1, crva=3, crvr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
    depth=5, maxVel=30, elevClip=0.1pi;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.61pi, 0.61pi, 0.25pi], speakerElev= 0.12pi, speakerDist= [4.87, 3.35, 3.35, 4.87],
    maxDist=3, scaleFlag=1, dist,
    in, out, signal;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    // Synthesis.
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2);
    in = RLPF.ar(
        FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2),
        distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    //Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, az.linlin(0,1, -0.5pi,0.5pi).clip2(elevClip), dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).add;

// == GRANULAR SYNTHS
// "regular" granulating (Ambisonic 4)
SynthDef( \sr_regu_ambisonic4, { // regular
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=1, rel=1, crva=3, crvr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
    offset=36, depth=5, maxVel=30, elevClip=0.1pi;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist,
    in, out, signal;
    var trate, dur, pos, clk, rate=1;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate = az.linlin(0,1, 0.2,2);
    trate = az.linlin(0,1, 100,0.2);
    dur = 4 / trate;
    clk = Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(azimuth));
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos, dur, amp: amp);
    in = RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                Mix.new(in), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 1000).clip(1000, 10000), 0.5
    );
    //Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, az.linlin(0,1, -0.5pi,0.5pi).clip2(elevClip), dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).add;

// "drone" (Ambisonic 4)
SynthDef( \sr_dron_ambisonic4, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=1, rel=1, crva=3, crvr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
    offset=36, depth=5, maxVel=30, elevClip=0.1pi;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist,
    in, out, signal;
    var trate, dur, pos, clk, rate=1;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate = az.linlin(0,1, 0.2,2);
    trate = SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur = 12 / trate;
    clk = Impulse.kr(trate);
    pos = ax*BufDur.kr(bufnum);
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos + TRand.kr(0, 0.01, clk), dur, amp: amp);
    in = RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                Mix.new(in), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 1000).clip(1000, 10000), 0.5
    );
    //Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, az.linlin(0,1, -0.5pi,0.5pi).clip2(elevClip), dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).add;

// "gusts of wind" (Ambisonic 4)
SynthDef( \sr_gust_ambisonic4, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=1, rel=1, crva=3, crvr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
    offset=36, depth=5, maxVel=30, elevClip=0.1pi;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist,
    in, out, signal;
    var trate, dur, pos, clk, d, zz;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    pos = (distance * 0.19 + 0.1).round(0.01);
    trate = az.linlin(0,1, 0.1,20);
    clk = Impulse.ar(trate);
    d = {Dwhite(0.1, 0.2, 1)};
    zz = {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
    );
    in = RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                Mix.new(in), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 1000).clip(1000, 10000), 0.5
    );
    //Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, az.linlin(0,1, -0.5pi,0.5pi).clip2(elevClip), dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).add;

// "slicing" (Ambisonic 4)
SynthDef( \sr_slid_ambisonic4, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=1, rel=1, crva=3, crvr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
    offset=36, depth=5, maxVel=30, elevClip=0.1pi;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist,
    in, out, signal;
    var trate, dur, pos, clk, rate= 1;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate = az.linlin(0,1, 0.2,2);
    trate = az.linlin(0,1, 1,100);
    dur = 8 / trate;
    clk = Dust.kr(trate);
    pos = ax * BufDur.kr(bufnum);
    // Synthesis.
    in = TGrains.ar(2, clk, bufnum, (2 ** WhiteNoise.kr(2)) * rate, BufFrames.ir(bufnum) * pos, dur, 0, amp);
    in = RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                Mix(in), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 1000).clip(1000, 10000), 0.5
    );
    //Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, az.linlin(0,1, -0.5pi,0.5pi).clip2(elevClip), dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).add;

// looper (Ambisonic 4)
SynthDef(\sr_loop_ambisonic4, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=1, rel=1, crva=3, crvr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=10,
    offset=36, depth=5, maxVel=30, elevClip=0.1pi;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist,
    in, out, signal;
    var startPos=0.0, rate=1;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate = az.linlin(0,1, 0.1,1.9);
    // Synthesis.
    in = PlayBuf.ar(1, bufnum,
        rate * BufRateScale.kr(bufnum),
        Impulse.ar(BufDur.kr(bufnum).reciprocal),
        BufFrames.ir(bufnum) * startPos
    );
    in = RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 1000).clip(1000, 10000), 0.5, mul: amp
    );
    //Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, az.linlin(0,1, -0.5pi,0.5pi).clip2(elevClip), dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).add;

// Additional synths (WARNING!) No such synths in the other spatial configurations!
// Universalize them!
SynthDef(\sr_loop_stable, {
    arg bufnum=0, busnum=0, pos=0, amp=1, master=1, gate=1, rate=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist;
    var in, signal, out;
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), Impulse.ar(BufDur.kr(bufnum).reciprocal), BufFrames.ir(bufnum) * pos);
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    // uneven ellipse rotation
    azimuth = Saw.kr(SinOsc.kr(0.1, 0, 0.75, 0.625), 2pi);
    dist = TRand.kr(0.01, 0.7, Dust.kr(0.1));
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
    azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

SynthDef(\sr_loop_unstable, {
    arg bufnum=0, busnum=0, pos=0, amp=1, master=1, gate=1, rate=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist;
    var in, signal, out;
    in = PlayBuf.ar(1, bufnum,
        TWChoose.kr(
            Dust.kr(0.01),
            [
                BufRateScale.kr(bufnum) * TRand.kr(0.5, 1.5, Dust.kr(0.2)),
                BufRateScale.kr(bufnum) * TRand.kr(-0.5, 2, Dust.kr(0.2)),
            ],
        [0.8, 0.2]),
        Dust.kr(0.2),
        TRand.kr(0, BufFrames.ir(bufnum), Dust.kr(0.2))
    );
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    // azimuth rotation
    azimuth = LFNoise0.kr(0.1, 2pi);
    dist = LFNoise0.kr(TRand.kr(0.01, 0.5, Dust.kr(0.1)), 0.2, 0.3);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master * 1.5);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
    azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

// send sum to the 5th channel, LPF, 5th channel goes to sub
SynthDef(\sr_mixerNode4x1, { arg inbus=0, outbus=4, gate=1;
    var env, in, out;
    in = Limiter.ar(LPF.ar(InFeedback.ar(inbus, 4), 200) * 0.7);
    env = EnvGen.kr(Env.asr(0.1, 1, 0.5, [3, -3]), gate: gate, doneAction:2);
    out = Mix.ar(in * env);
    Out.ar(outbus, out);
}).send(s);


// ================================================
//
// 					   Ambisonic 8
//
// ================================================

// audio in (Ambisonic 8)
SynthDef(\audioin_1_ambisonic8, {
    arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var in, out, dl, env, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr(Env.asr(att, master, rel, [crva, crvr]), gate: gate, doneAction: 2);
    dl= DelayL.ar(InFeedback.ar(inbus, 1), 110/344, distance/3.44);
    in= RLPF.ar(
        FreeVerb.ar(
            InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out)
    }
).add;

// buffer player (Ambisonic 8)
SynthDef(\sr_play_ambisonic8, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=0.5, rel= 1, gate=1, done= 2,
    azimuth=0, elevation=0, distance=1;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var env, signal, in, out, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
    in= PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2) * env;
    signal= RLPF.ar(
        FreeVerb.ar(
            in,
            distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
        ),
        distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).add;


// ================================================
//
// 						VBAP 4
//
// ================================================

// audio in (Ambisonic 8)
SynthDef(\audioin_1_vbap4, {
    arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;
    var in, out, dl, env;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //	in= RLPF.ar(InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 10000,800), 0.5) * env;
    //Conversion.
    env= EnvGen.kr(Env.asr(att, master, rel, [crva, crvr]), gate: gate, doneAction: 2);
    dl= DelayL.ar(InFeedback.ar(inbus, 1), 110/344, distance/3.44);
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in= RLPF.ar(
        FreeVerb.ar(
            InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    out= VBAP.ar(4, in, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(outbus, out)
    }
).add;

// buffer player (VBAP 4)
SynthDef(\sr_play_vbap4, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=0.5, rel= 1, gate=1, done= 2,
    azimuth=0, elevation=0, distance=1;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var env, signal, in, out;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
    in= PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2) * env;
    signal= RLPF.ar(
        FreeVerb.ar(
            in,
            distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
        ),
        distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).add;

// == GRANULAR SYNTHS
// "regular" granulating (VBAP 4)
SynthDef( \sr_regu_vbap4, { // regular
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rate=1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
    dur= 4 / trate;
    clk= Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(azimuth));
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos,
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).add;

// "drone" (VBAP 4)
SynthDef( \sr_dron_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0.5, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rate=1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
    trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur= 12 / trate;
    clk= Impulse.kr(trate);
    pos= ax*BufDur.kr(bufnum);
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos + TRand.kr(0, 0.01, clk),
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000,500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).add;

// "gusts of wind" (VBAP 4)
SynthDef( \sr_gust_vbap4, {
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, d, zz, signal;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    pos= round((distance*0.19)+0.1, 0.01);
    trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
    clk= Impulse.ar(trate);
    d= {Dwhite(0.1, 0.2, 1)};
    zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).add;

// "slicing" (VBAP 4)
SynthDef( \sr_slid_vbap4, {
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
    trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
    dur= 8 / trate;
    clk= Dust.kr(trate);
    pos= ax * BufDur.kr(bufnum);
    rateratio= (2 ** WhiteNoise.kr(2)) * rate;
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rateratio,
        centerPos: pos,
        dur: dur,
        amp: amp * rateratio.linlin(0,4, 1,0.5)
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
        distance.linlin(0,1.41, 10000,500), 0.5)
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).add;

// looper (VBAP 4)
SynthDef(\sr_loop_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal, startPos=0.0, rate=1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    rate= ay.linlin(-0.5pi,0.5pi, 0.1, 1.9);
    in = PlayBuf.ar(
        1,
        bufnum,
        rate*BufRateScale.kr(bufnum),
        Impulse.ar(BufDur.kr(bufnum).reciprocal),
        BufFrames.ir(bufnum)*startPos
    )
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
}).add;

// == ELECTRONIC SYNTHS
// doors (VBAP 4)
SynthDef(\sr_doors_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var freq, in, out, signal, grav;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    freq= 1/(2..5);
    grav= 7-(1/freq);
    in= GVerb.ar(
        Ball.ar(
            LPF.ar(Impulse.ar(freq), 500),
            grav, 1e-5,
            LFNoise2.kr(freq/5,2e-4,12e-4))/2,
        5, 0.5, 0.9);
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= PitchShift.ar(
        RLPF.ar(
            DelayL.ar(
                FreeVerb.ar(
                    in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
                ), 110/344, distance/3.44
            ), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
        ),
        0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out)
}).add;

// probe (VBAP4)
SynthDef(\sr_prob_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var dtl=0.01, dtr=0.05;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, scale, fbase, signal, startPos=0.0, rate=1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    rate= velocity.linlin(1,30, 0.5, 3) * exprand(3,8);
    scale = FloatArray[0, 3, 10, 12, 19];
    fbase= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi,0.5pi, 15,0), 24, 1, 17).midicps;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in = LPZ2.ar(
        LFPulse.ar(
            fbase, 2pi.rand, 0.1,
            (
                Mix.ar(SinOsc.ar(rate * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand])).abs
                * (amp*0.2))
        )
    );
    2.do({ in= AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2); });
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(in, 30/344, distance.linlin(0.0,1.41, 30,75)/344), //~30kph
        distance.linlin(0.0,1.41, 10000,500).clip(500,10000), 0.5, mul: amp * master
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
}).add;

// cmb (VBAP 4)
SynthDef(\sr_cmb_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
    delayL= elevation.linlin(-0.5pi, 0.5pi, 0.01, 0.05);
    delayR= ax.linlin(0,1, 0.01, 0.05);
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    mix= Klank.ar(
        `[Array.fill(n, {exprand(1.0,20.0)}),
            nil,
            Array.fill(n, {0.2.rand})
        ],
        Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
    ).fold2(0.2).cubed * 12;
    mix= Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
    in= mix.distort * 0.5;
    6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
    in= Mix.ar(LeakDC.ar(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.3
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out)
}).add;

// starfield (VBAP 4)
SynthDef(\sr_star_vbap4, {
    arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, gate=1, frate=1, modf=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
    dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
    q= dir[1].atan2(dir[0])+pi;
    a= frate.linlin(0,2, 2pi, 0);
    b= dir[1].hypot(dir[0])*400+200;
    c= modf.linlin(-440,440, 0, 50);
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
    in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    signal= RLPF.ar(FreeVerb.ar(in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2), distance.linlin(0,1.41, 10000, 500), 0.5);
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).add;

// "melodic" (VBAP 4)
SynthDef( \sr_melo_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -140, 140, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, freq, scale, signal;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    scale = FloatArray[0, 3, 10, 12, 19];
    freq= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 17).midicps;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in= RLPF.ar(
        LFSaw.ar(freq)
        + Impulse.ar( XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand)
        + WhiteNoise.ar(0.8.rand, mul:ay.linlin(0,1,1,0.1)),
        LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp*0.02
    );
    in= [in, DelayN.ar(in, 0.04, 0.04) ];
    4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
    in= Mix.ar(LeakDC.ar(in))*EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out)
    }
).add;

// ringz (VBAP4)
SynthDef(\sr_ringz_vbap4, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance= 1, velocity=10;
    var speakerAzim= #[-45, -140, 140, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal;
    var fbase, phase, cutoff;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    fbase= distance.linexp(0,1.41, 10,40);
    phase= velocity*100;
    cutoff= distance.linexp(0,1.41, 200,2000);
    in=
    Ringz.ar(SinOsc.ar(fbase, phase.lag(0.01), amp*0.02), cutoff, 0.01);
    5.do({in});
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(in, 30/344, distance.linlin(0.0,1.41, 30,75)/344), //~30kph
        distance.linlin(0.0,1.41, 10000,500).clip(500,10000), 0.5, mul: amp * master
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
}).add;