(
SynthDef(\sr__e__proba1, {
    arg bufnum=0, inbus=30, outbus=20,
    amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
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

SynthDef(\sr__e__humm, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0,
        mnote=0, freqBase=36, mod=0; // WARNING! This is obsolete, remove when finishing notes via .kr bus!
    var scale, note, in, out, signal;
    // Conversion.
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10]);
    note = DegreeToKey.kr(LocalBuf.newFrom(scale), az, 24, 1, freqBase).midicps;
    // Synthesis.
    in = LFSaw.ar((1..5) * note, velocity)
         + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300));
    signal = RLPF.ar(Mix.ar(in), LinLin.kr(velocity, 0, 1, 80, 30).midicps, velocity, amp * 0.2);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// modulators
SynthDef(\kr_osc_sin, {
    arg outbus=0, freq=440, phase=0, mul=1, add=0, mod_mul=0.45, mod_add=0.55;
    var out = SinOsc.kr(LFNoise0.kr(freq, mod_mul, mod_add), LFDClipNoise.kr(freq), mul, add);
    Out.kr(outbus, out);
}).add;

SynthDef(\kr_osc_saw, {
    arg outbus=0, freq=440, mul=1, add=0, mod_mul=0.45, mod_add=0.55;
    var out = Saw.kr(LFNoise0.kr(freq, mod_mul, mod_add), mul, add);
    Out.kr(outbus, Saw.kr(freq, mul, add));
}).add;

SynthDef(\kr_osc_tri, {
    arg freq=440, phase=0, mul=1, add=0, outbus=0;
    Out.kr(outbus, LFTri.kr(freq, phase, mul, add));
}).add;

// clip noise
SynthDef(\kr_rnd_clipnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0;
    Out.kr(outbus, LFDClipNoise.kr(freq, mul, add));
}).add;

// step noise
SynthDef(\kr_rnd_stepnoise, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0;
    Out.kr(outbus, LFDNoise0.kr(freq, mul, add));
}).add;

SynthDef(\kr_rnd_LFNoise2, {
    arg freq=1, phase=0, mul=1, add=0, outbus=0;
    Out.kr(outbus, LFNoise2.kr(freq, mul, add));
}).add;

//{[LFDClipNoise.ar, LFDNoise0.ar, LFDNoise1.ar, LFDNoise3.ar, LFNoise0.ar, LFNoise1.ar, LFNoise2.ar]}.plot(0.2)
)

(
//move this to schedule, create nodes for switching it ON and OFF!

// SYNTH HUMM
// start generator
~id_humm = s.nextNodeID;
s.sendBundle(0.001,
    ["/g_new", ~id_humm], // add new group to root's tail
    ["/s_new", \sr__s__ambisonic4, s.nextNodeID, 1, ~id_humm, // add spatializer to new group's tail
        \inbus, 3, // getting signal from synth
        \outbus, 0], // to main output
    ["/s_new", \sr__e__humm, s.nextNodeID, 0, ~id_humm, // add synth to new group's head
        \outbus, 3, // feeding into spatilizer
        \azimuth, 0, \velocity, 0.88]
);

// add .kr synth to head - modulate azimuth at bus 0
s.sendBundle(0.1,
    // change of azimuth
    ["/s_new", \sr__k__lfnoise2, s.nextNodeID, 0, ~id_humm, \freq, 0.5, \mul, 1pi, \outbus, 0],
    ["/n_map", ~id_humm, \azimuth, 0],
    // variable change of distance
    ["/s_new", \sr__k__sin, s.nextNodeID, 0, ~id_humm, \freq, 0.2,
        \mul, ((32.sqrt - 0.5)/2), \add, (32.sqrt - ((32.sqrt - 0.5)/2)),
        \mod_mul, ((0.2 - 0.02)/2), \mod_add, 0.2 - ((0.2 - 0.02)/2), \outbus, 1],
    ["/n_map", ~id_humm, \distance, 1],
    ["/s_new", \sr__k__stepnoise, s.nextNodeID, 0, ~id_humm, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 2],
    ["/n_map", ~id_humm, \velocity, 2],
    ["/s_new", \sr__k__stepnoise, s.nextNodeID, 0, ~id_humm, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 3],
    ["/n_map", ~id_humm, \velocity, 3],
    ["/s_new", \sr__k__sin, s.nextNodeID, 0, ~id_humm, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 4],
    ["/n_map", ~id_humm, \az, 4]
);


// SYNTH PROBA
// start generator
~id_proba1 = s.nextNodeID;
s.sendBundle(0.001,
    ["/g_new", ~id_proba1], // add new group to root's tail
    ["/s_new", \sr__s__vbap4, s.nextNodeID, 1, ~id_proba1, // add spatializer to new group's tail
        \inbus, 3, // getting signal from synth
        \outbus, 0], // to main output
    ["/s_new", \sr__e__proba1, s.nextNodeID, 0, ~id_proba1, // add synth to new group's head
        \outbus, 3, // feeding into spatilizer
        \azimuth, 0, \velocity, 0.88]
);

// add .kr synth to head - modulate azimuth at bus 0
s.sendBundle(0.1,
    // change of azimuth
    ["/s_new", \sr__k__lfnoise1, s.nextNodeID, 0, ~id_proba1, \freq, 0.1, \mul, 1pi, \outbus, 10],
    ["/n_map", ~id_proba1, \azimuth, 10],
    // variable change of distance
    ["/s_new", \sr__k__stepnoise, s.nextNodeID, 0, ~id_proba1, \freq, 0.08,
        \mul, (2.sqrt - 0.3) * 0.5, \add, 2.sqrt - ((2.sqrt - 0.3) * 0.5), // range 0.3..1.41
        \outbus, 11],
    ["/n_map", ~id_proba1, \distance, 11],
    ["/s_new", \kr_rnd_stepnoise, s.nextNodeID, 0, ~id_proba1, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 12],
    ["/n_map", ~id_proba1, \velocity, 12]
);


// SYNTH CMB
// start generator
~id_cmb = s.nextNodeID;
s.sendBundle(0.001,
    ["/g_new", ~id_cmb], // add new group to root's tail
    ["/s_new", \sr__s__ambisonic2, s.nextNodeID, 1, ~id_cmb, // add spatializer to new group's tail
        \inbus, 4, // getting signal from synth
        \outbus, 0], // to main output
    ["/s_new", \sr__e__cmb, s.nextNodeID, 0, ~id_cmb, // add synth to new group's head
        \outbus, 4, // feeding into spatilizer
        \azimuth, 0, \velocity, 0.88]
);

// add .kr synth to head - modulate azimuth at bus 0
s.sendBundle(0.1,
    // stable sinusoidal change of azimuth
    ["/s_new", \kr_osc_sin, s.nextNodeID, 0, ~id_cmb, \freq, 0.1, \mul, 1pi, \mod_mul, 1, \mod_add, 0, \outbus, 20],
    ["/n_map", ~id_cmb, \azimuth, 20],
    // variable change of distance
    ["/s_new", \kr_osc_sin, s.nextNodeID, 0, ~id_cmb, \freq, 0.2,
        \mul, ((32.sqrt - 0.1)/2), \add, (32.sqrt - ((32.sqrt - 0.1)/2)),
        \mod_mul, ((0.2 - 0.02)/2), \mod_add, 0.2 - ((0.1 - 0.02)/2), \outbus, 21],
    ["/n_map", ~id_cmb, \distance, 21],
    ["/s_new", \kr_osc_tri, s.nextNodeID, 0, ~id_cmb, \freq, 1.6, \mul, 0.4, \add, 0.6, \outbus, 22],
    ["/n_map", ~id_cmb, \velocity, 22]
);
)

// release group
s.sendBundle(0.1, ["/n_set", ~id_humm, \rel, 2, \gate, 0], ["/n_free", ~id_humm]);
s.sendBundle(0.1, ["/n_set", ~id_proba1, \rel, 1, \gate, 0], ["/n_free", ~id_proba1]);
s.sendBundle(0.1, ["/n_set", ~id_cmb, \rel, 1, \gate, 0], ["/n_free", ~id_cmb]);