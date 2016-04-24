(
SynthDef(\exp1__e__proba1, {
    arg bufnum=0, inbus=30, outbus=20,
    amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=5, velocity=0.5,
    offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var cutOff, rq, azThresh=0.7;
    // Conversion.
    //cutOff = distance.linexp(0.0, 1.0, 200, 10000); // different from arg!
    //rq = distance.linlin(0, 2.sqrt, 0.5, 1);
    cutOff = 5000;
    rq = 0.5; // FOR TESTS ONLY!
    // Synthesis.
    in = Formlet.ar(
        LPF.ar(
            Saw.ar(
                (1..5) * LFClipNoise.ar(SinOsc.ar(0.1, 0, 0.5, 1), 10, 50), 0.3
            )
            + SinOsc.ar((6..2)).exprange(0.05, 50),
            300
        )
        + Impulse.ar(
            (0..4) + SinOsc.ar(
        (4..8) * 0.02).exprange(0.3, 300))
        , (1..5)
        * SinOsc.ar((5..9)*0.05).exprange(200, 2000)
        * SinOsc.ar(SinOsc.ar((2..6) * 0.1, 0, 0.1), 0, 0.1, 1), 0.001, 0.0015
    );
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutOff, rq), cutOff, rq);
    in = Compander.ar(in, in, 0.002, slopeBelow: 0.33, slopeAbove: 0.5,
    clampTime: 0.01, relaxTime: 0.01, mul: amp);
    signal = Mix.ar(in);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;

// modulators
SynthDef(\exp1__k__lfnoise1, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFNoise1.kr(freq, mul, add);
    Out.kr(outbus, out );
}).add;

SynthDef(\exp1__k__tri, {
    arg freq=440, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * LFTri.kr(freq, phase, mul, add);
    Out.kr(outbus, out);
}).add;

SynthDef(\exp1__k__stepnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0, gate=1, att=1, rel=1, trigID=60, trigRate=30;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var out = env * TWChoose.kr(
        Dust.ar(1),
        [LFNoise0.kr(freq, mul, add), LFNoise1.kr(freq, mul, add), LFNoise2.kr(freq).clip2 * mul + add],
        [0.1, 0.4, 0.5]
    );
    SendTrig.kr(Impulse.kr(freq.reciprocal), trigID, out);
    Out.kr(outbus, out);
}).add;

// spatializers
SynthDef(\exp1__s__vbap4, {
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=5;
    var speakerAzim = #[-45, -140, 140, 45], speakerElev=0, speakerBuff, spread=0;
    var in, amp, signal, out;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth = azimuth.linlin(-1pi, 1pi, -180, 180);
    elevation = elevation.linlin(-0.5pi, 0.5pi, -90, 90);
    spread = [100, 0, 4].asSpec.map(distance); // the closer the signal, the more speakers involved (welch-like)
    amp = [1, 0.05, 4].asSpec.map(distance); // and the louder it is.
    in = In.ar(inbus, 1) * amp;
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    out = VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(outbus, out);
}).send(s);

SynthDef(\exp1__s__ambisonic4, {
    arg inbus=20, outbus=0, gate=1, rel=1,
        azimuth=0, elevation=0, elevClip=0.1pi, distance=0, depth=15;
    var w, x, y, z, r, f, t, u, v,
        speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= [0, 0, 0, 0], speakerDist= [1.5, 1.5, 1.5, 1.5],
        maxDist=1.5, scaleFlag=0,
        in, signal, out;
    distance = distance.linlin(0, 2.sqrt, 0.5, depth);
    in = In.ar(inbus, 1);
    signal = in * EnvGen.kr(Env.cutoff(rel * 2, 1, \sin), gate: gate, doneAction: 2);
    #w, x, y, z, r, f, t, u, v = FMHEncode1.ar(signal, azimuth, elevation.clip2(elevClip), distance);
    out = FMHDecode1.ar1(w, x, y, z, r, f, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out);
}).send(s);

// SYNTH PROBA
// start generator
~id_proba1 = s.nextNodeID;
s.sendBundle(0.001,
    ["/g_new", ~id_proba1], // add new group to root's tail
    ["/s_new", \exp1__s__ambisonic4, s.nextNodeID, 1, ~id_proba1, // add spatializer to new group's tail
        \inbus, 12, // getting signal from synth
        \outbus, 0], // to main output
    ["/s_new", \exp1__e__proba1, s.nextNodeID, 0, ~id_proba1, // add synth to new group's head
        \outbus, 12, // feeding into spatilizer
        \azimuth, 0, \velocity, 0.88]
);

// add .kr synth to head - modulate azimuth at bus 0
s.sendBundle(0.1,
    // oscillating change of azimuth
    ["/s_new", \exp1__k__stepnoise, s.nextNodeID, 0, ~id_proba1, \freq, 0.1, \mul, 1pi, \add, 1pi, \outbus, 10],
    ["/n_map", ~id_proba1, \azimuth, 10],
    // variable change of distance
    ["/s_new", \exp1__k__stepnoise, s.nextNodeID, 0, ~id_proba1, \freq, 0.1,
        \mul, (2.sqrt - 0.3) * 0.5, \add, 2.sqrt - ((2.sqrt - 0.3) * 0.5), // range 0.3..1.41
        \outbus, 11],
    ["/n_map", ~id_proba1, \distance, 11],
    ["/s_new", \exp1__k__stepnoise, s.nextNodeID, 0, ~id_proba1, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 12],
    ["/n_map", ~id_proba1, \velocity, 12]
);
)

// release group
s.sendBundle(0.1, ["/n_set", ~id_proba1, \rel, 1, \gate, 0], ["/n_free", ~id_proba1]);

//{[LFDClipNoise.ar, LFDNoise0.ar, LFDNoise1.ar, LFDNoise3.ar, LFNoise0.ar, LFNoise1.ar, LFNoise2.ar]}.plot(0.2)

//(0.001, 0.002..2.sqrt).collect(_.linexp(0.001, 2.sqrt, 1, 0.001)).plot


