(
var samplesDir;
var guideBuff; // buffers (sound files and scales)
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime


//GLOBAL
~sequence = (
    title: "Sympli Romatiko: band in Traer World",

    // step marks (numbered) and time marks (entitled)
    // (
    //     0: [(event0), (event1), ...],
    //     1: [(eventN), (eventN+1), ...],
    //     foo: [...]
    // )
    events: Dictionary.new,

    // connector of time and time marks
    // (
    //     0_00: \foo,
    //     1_12_354: \gee
    // )
    marks: Dictionary.new,

    // descriptions of tasks
    // (
    //     taskX: Task({...}),
    //     taskY: Task({...}),
    // )
    tasks: Dictionary.new,

    // list of buffers
    samples: List.new,

    // list of buffers for voice samples
    voices: List.new,

    // list of buffers for scales
    scales: List.new,
);

// INITIAL
//
// Sequence rules (Markov set).
dictObjSeq = (
    // [number of repeats] (to choose from) -> [timelapse] (current moment and age)
    0: [(4..12), (1..6)], // short
    1: [[1, 3, 5, 7, 9], ({rrand(5, 40)} ! 10)], // average
    2: [[1, 2], ({rrand(30, 120)} ! 10)] // long (repeat)
);
msetObjSeq = MarkovSetN([], 2);
dictObjSeq.keysValuesDo{|k, v| msetObjSeq[k] = v[1]};

samplesDir = "~/Music/Sympli_Romatiko/samples/";
PathName.new(samplesDir +/+ "drums").entries.do { |f, i|
    try { ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
PathName.new(samplesDir +/+ "voices").entries.do { |f, i|
    try { ~sequence.voices.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
guideBuff = Buffer.readChannel(~scsynth,
    PathName(samplesDir +/+ "drums/drumguide.wav").fullPath, channels: [0]
);

[
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 1, 3, 7, 8], // the rest are specific to sequence's parts
    FloatArray[0, 2],
    FloatArray[0, 3],
    FloatArray[1, 3],
].do { |c, i|
    ~sequence.scales.add(Buffer.sendCollection(~scsynth, c));
};

~sequence.events = (
    0: [
        (message: \action,  params: [\remove, \all],
            info: "Remove all before start\n Apply initial settings"),
        (message: \physics, params: [\gravX, \default]),
        (message: \physics, params: [\gravY, \default]),
        (message: \physics, params: [\gravZ, \default]),
        (message: \physics, params: [\drag, 0.001]),
        (message: \physics, params: [\repulsion, \default]),
        (message: \physics, params: [\starMass, \default]),
        (message: \physics, params: [\particles, \default]),
        (message: \physics, params: [\springRestLen, 3]),
        (message: \physics, params: [\springStrength, 0.5]),
        (message: \physics, params: [\springDamp, 2]),
        (message: \physics, params: [\mutualAttraction, \default]),
    ],
    5: [
        (
            wait: 10,
            info: "INTRO, no objects, only .kr buses",
            message: \g_new,
            id: \intro_bundle,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 14, // getting signal from synth
                    \outbus, ~outbus], // to main output
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 14, // feeding into spatilizer
                    \velocity, 0.5, \att, 40, \bufnum, ~sequence.scales[4].bufnum],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.2, \mul, 1pi, \outbus, 0],
                ["/n_map", \group_id, \azimuth, 0],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.08, \mul, 0.3, \add, 0.7, \outbus, 1],
                ["/n_map", \group_id, \distance, 1],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.1, \mul, 0.25, \add, 0.5, \outbus, 2],
                ["/n_map", \group_id, \velocity, 2],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.01, \mul, 0.1, \add, 0.1, \outbus, 3],
                ["/n_map", \group_id, \az, 3]
            ]
        )
    ],
    7: [
        (
            wait:15,
            info: "INTRO: Particles",
            message: \physics, params: [particles: 1]
        ),
        (
            message: \physics, params: [\maxVel, 2]
        ),
        (
            info: "Silent object",
            message: \particle,
            synth: (name: \sr__e__silent),
            particle: (mass: 1, x: 470, y: 300, z: 250)
        ),
        (
            message: \task, name: \randomParticles, act: 1
        ),
    ],
    10: [
        ( // Remove all objects.
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "INTRO: objects",
            message: \task, name: \intro, act: 1
        )
    ],
    11: [
        (
            info: "INTRO: long noisy",
            message: \g_new,
            id: \intro_noisy,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 15, // getting signal from synth
                    \outbus, ~outbus], // to main output
                ["/s_new", \sr__e__noisy, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 15, // feeding into spatilizer
                    \velocity, 0.5, \att, 120],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.2, \mul, 1pi, \outbus, 4],
                ["/n_map", \group_id, \azimuth, 4],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08, \mul, 2.3, \add, 2.7, \outbus, 5],
                ["/n_map", \group_id, \distance, 5],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 1, \mul, 0.2, \add, 0.6, \outbus, 6],
                ["/n_map", \group_id, \velocity, 6]
            ]
        )
    ],
    15: [
        (
            info: "INTRO: voices",
            message: \task, name: \voices, act: 1
        ),
    ],
    16: [
        (
            info: "INTRO: voices background",
            message: \particle,
            synth: (name: \sr__g__reg, params: [
                \ca, 5, \att, rand(40, 60), \rel, 10, \bufnum, ~sequence.voices.choose.bufnum
            ]),
            particle: (mass: 0.5),
        ),
        (
            message: \particle,
            synth: (name: \sr__g__drone, params: [
                \ca, 5, \att, rand(80, 120), \rel, 10, \bufnum, ~sequence.voices.choose.bufnum
            ]),
            particle: (mass: 0.5),
        ),
    ],
    20: [
        (info: "Physics environment change",
            message: \physics, params: [\drag, 0.5]),
        (message: \physics, params: [\repulsion, 10]),
        (message: \physics, params: [\maxVel, 150]),
    ],
    22: [
        (
            info: "INTRO: stop voices",
            message: \task, name: \voices, act: 0
        ),
        (
            message: \physics, params: [audioIn: false]
        )
    ],
    30: [
        (
            info: "INTRO: __analog cutoff= -1",
            message: \task, name: \sporadicAnalogCutoff, act: 1
        ),
    ],
    31: [
        ( // Remove all objects.
            info: "SCI-FI",
            message: \action, params: [\remove, \all]
        ),
        ( // Stop schedule with sporadic \sr__e__analog, cutoff= -1
            info: "Remove all, stop sched, particles OFF",
            message: \task, name: \sporadicAnalogCutoff, act: 0
        ),
        ( // Clear \intro schedule
            message: \task, name: \intro, act: 0
        ),
        ( // Stop occasional particles
            message: \task, name: \randomParticles, act: 0
        ),
        ( // switch particles OFF
            message: \physics, params: [particles: 0]
        ),
        ( // remove intro group from server
            message: \g_free, id: \intro_bundle, params: [\release, 80]
        ),
        ( // remove noisy synth group from server
            message: \g_free, id: \intro_noisy, params: [\release, 80]
        ),
        (
            info: "Ave __pulse, 2 heavy __analog",
            message: \particle,
            synth: (name: \sr__e__pulse, params: [\att, 40, \rel, 10]),
            particle: (age: rrand(80, 150), mass: 0.6, x: 350, y: 120, z: 750),
        ),
        // Start 2 heavy sr__e__analog w/default cutoff and long attack
        (
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 40, \rel, 10]),
            particle: (mass: 1, x: 300, y: 300, z: 250),
        ),
        (
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 40, \rel, 10]),
            particle: (mass: 1, x: 470, y: 300, z: 250)
        )
    ],
    32: [
        (
            info: "SCI-FI: Remove all",
            message: \action,  params: [\remove, \all]
        ),
        ( // switch mutual attraction off
            message: \physics, params: [\mutualAttraction, 0]
        ),
        (
            info: "Schedule sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 1
        ),
        (
            info: "heavy __analog - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__analog,
                params: [\bufnum, ~sequence.scales[0].bufnum, \att, 2 + 1.0.rand2, \rel, 5, \threshold, 0.5]),
            particle: (mass: 1, spring: 1)
        ),
    ],
    33: [
        (
            info: "SCI-FI: heavy __analog 2",
            message: \particle,
            synth: (name: \sr__e__analog,
                params: [\bufnum, ~sequence.scales[0].bufnum, \att, 2 + 1.0.rand2, \rel, 5, \threshold, 0.5]),
            particle: (mass: 1, spring: 1)
        ),
    ],
    35: [
        (
            info: "METAL: Change scale",
            message: \n_set,
            synth: (
                params: [
                    \bufnum, ~sequence.scales[1].bufnum,
                    \threshold, 0.3,
                    \scope, 24,
                    \offset, 24
                ]
            )
        ),
        (
            info: "Stop sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 0
        ),
    ],
    36: [
        (
            info: "METAL-TO-FREE: reset to chromatic scale",
            message: \n_set,
            synth: (
                params: [
                    \bufnum, Buffer.sendCollection(~scsynth, Scale.chromatic.degrees[..4]).bufnum,
                ]
            )
        ),
    ],
    40: [
        (
            info: "HEAVY: Reset scale",
            message: \n_set,
            synth: (
                params: [\bufnum, nil]
            )
        ),
        (
            info: "Light __lowe ~heaviness",
            message: \particle,
            synth: (name: \sr__e__lowe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            particle: (mass: 0.8, spring: 1, x: 470, y: 300, z: 250)
        ),
    ],
    45: [
        (
            info: "One more __analog w/cutoff",
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 2, \rel, 10, \cutoff, -1, \amp, 0.5]),
            particle: (age: inf, mass: 0.8, spring: 1)
        ),
    ],
    46: [
        (
            info: "Add heavy __therem - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__therem, params: [\att, 2, \rel, 10, \amp, 0.7]),
            particle: (age: inf, mass: 0.8, spring: 1),
        )
    ],
    47: [
        (
            info: "heavy __therem 2",
            message: \particle,
            synth: (name: \sr__e__therem, params: [\att, 2, \rel, 10, \amp, 0.7]),
            particle: (age: inf, mass: 0.8, spring: 1)
        ),
    ],
    50: [
        (
            info: "AIRY",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __probe - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10, \bufnum, ~sequence.scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    55: [
        (
            info: "AIRY: heavy __probe 2",
            message: \particle,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10, \bufnum, ~sequence.scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1),
        ),
        (
            info: "Schedule __cmb & __melo",
            wait: 180,
            message: \task, name: \randomCMBMelo, act: 1
        ),
        (
            info: "Schedule scale switch",
            message: \task, name: \switchScale, act: 1
        )
    ],
    60: [
        ( // Remove all objects.
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Heavy __cmb - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__cmb, params: [\att, 1.0.rand, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1),
        ),
    ],
    61: [
        (
            info: "Heavy __cmb",
            message: \particle,
            synth: (name: \sr__e__cmb, params: [\att, 3 + 2.0.rand2, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    70: [
        (
            info: "ELECTRO SOLO",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy __melo - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    71: [
        (
            info: "heavy __melo 2",
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    80: [
        (
            info: "BREAKS",
            message: \action,  params: [\remove, \all]
        ),
        ( // IMPORTANT! switchScale sends scales as buffers to all nodes
            // It should be stopped before starting granWave to prevent
            // sending scales instead of samples.
            info: "Stop all schedules",
            message: \task, name: \switchScale, act: 0
        ),
        (
            message: \task, name: \randomCMBMelo, act: 0
        ),
        (
            info: "heavy __entro + TAP for __radio",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    81: [
        (
            info: "heavy __radio 2",
            message: \particle,
            synth: (name: \sr__e__radio),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    82: [
        (
            info: "BREAKS",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __entro - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    83: [
        (
            info: "heavy __entro 2",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    90: [
        (
            info: "GROOVE",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __gauss - TAP twice for 2!",
            message: \particle,
            // synth: (name: \sr__e__gauss, params: [\att, 100, \rel, 16, \ca, 5]),

            // XXX: temp!
            synth: (name: \sr__e__gauss, params: [\att, 40, \rel, 16, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    91: [
        (
            info: "heavy __gauss 2",
            message: \particle,
            // synth: (name: \sr__e__gauss, params: [\att, 100, \rel, 16, \ca, 5]),

            // XXX: temp!
            synth: (name: \sr__e__gauss, params: [\att, 40, \rel, 16, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],
    92: [
        ( // Remove all objects.
            info: "OUTRO",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __noisy - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    93: [
        (
            info: "heavy __noisy 2",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
        (
            info: "heavy __pulse with long attack",
            message: \particle,
            synth: (name: \sr__e__pulse, params: [\att, 120, \rel, 10, \ca, 5, \bufnum, ~sequence.scales[3].bufnum]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],
    99: [
        (
            info: "FIN",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Remove all, particles OFF",
            message: \physics, params: [particles: 0]
        )
    ]
);

// Tasks dictionary.
//
~sequence.tasks = (
    randomParticles: Task({
        var key, next;
        var particleParams = [ // list of acceptable configurations
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.3, \partAgeThresh, 1.67, \partInitAccel, 10 ],
            [                           \partSigmoidRatio, 0.7, \partAgeThresh, 0.20, \partInitAccel, 30 ],
            [\partSynth, \sr__e__melo,  \partSigmoidRatio, 0.7, \partAgeThresh, 0.78, \partInitAccel, 2.0],
            [\partSynth, \sr__e__cmb,   \partSigmoidRatio, 0.4, \partAgeThresh, 0.20, \partInitAccel, 30 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.7, \partAgeThresh, 1.08, \partInitAccel, 8.0],
            [\partSynth, \sr__e__pulse, \partSigmoidRatio, 0.2, \partAgeThresh, 1.03, \partInitAccel, 20 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.2, \partAgeThresh, 1.67, \partInitAccel, 1.0],
        ];
        inf.do { |i|
            2.do { |j|
                key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.3, 0.6, 0.1]);
                next = msetObjSeq.next(key);
                next = (next + rand2(next * 0.25));
                ~sendMessage.(\physics, particleParams[i % particleParams.size]);
                next.wait;
            };
            0.01.wait;
        }
    }),

    // INTRO:
    // Picks up a key and the number of iterations randomly (average
    // sequences are the most probable, long are the least probable).
    //
    // A new particle's age spans over to the next object birth (no gaps).
    // The lighter the object the faster it dies, but demography is denser.
    //
    intro: Task({
        var key, next, synth, x, y, z, mass, age, node;
        loop {
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 10, 1].normalizeSum);
            dictObjSeq[key.asInteger][0].choose.do{ |i|
                next = msetObjSeq.next(key);
                age = next * (1 + (1/(next.pow(0.33))));
                mass = next.sqrt.clip(0.1, 0.3);
                synth = (
                    name: [\sr__e__humm, \sr__e__radio][i % 2], // alternate
                    params:[
                        \att, rrand(1, 2),
                        \bufnum, ~sequence.scales[4].bufnum
                    ]
                );
                ~sendParticle.(
                    synth: synth,
                    particle: (mass:mass, age:age)
                );

                if (0.7.coin) {
                    synth = (
                        // XXX - \sr__e__radio - quieter in INTRO!
                        name: [\sr__e__lowe, \sr__e__radio, \sr__e__humm].wchoose([0.6, 0.2, 0.2])
                    );
                    ~sendParticle.(
                        synth: synth,
                        particle: (mass:mass, age:age + ((age * 0.25).rand2))
                    );
                };
                next.wait;
            };
            0.01.wait;
        }
    }),
    voices: Task({
        var buff, synth, age, x, y, z, prob=0.2;
        inf.do { |j|
            buff = ~sequence.voices[j % ~sequence.voices.size];
            age = buff.numFrames / buff.numChannels / buff.sampleRate;
            #x, y, z = { rrand(~worldSize, ~worldSize * ([0.1, 0.9].choose)) } ! 3;

            case
            // when voices are introduced, they should be clearly recognizable
            { j <= 5 } {
                synth = \sr__g__loop
            }
            { (j > 5) && (j <= 10) } {
                synth = [\sr__g__loop, \sr__g__loopdel, \sr__g__unst].choose
            }
            { j > 10 } { // later on "smooth them out" into a voice meshup
                // appear closer to the center of the world
                #x, y, z = { (~worldSize / 2 + rand2(~worldSize * 0.15))} ! 3;
                prob = 0.6; // bigger chance that the next sample will cross with the current one
                synth = [\sr__g__loop, \sr__g__unst, \sr__g__reg].wchoose([0.5, 0.3, 0.2]);

                // occasionally send a light __scratch with the same sample and age
                if (0.3.coin) {
                    ~sendParticle.(
                        particle: (mass:0.1, x:x, y:z, z:z, age:age),
                        synth: (
                            name:\sr__g__scratch,
                            params:[\att, 3, \bufnum, buff.bufnum]
                        )
                    );
                };
            };

            // main "voice particle"
            ~sendParticle.(
                particle: (mass:0.5, x:x, y:z, z:z, age:age),
                synth: (
                    name:synth,
                    params:[\att, 2, \bufnum, buff.bufnum]
                )
            );
            // vary waiting time - every now and then send the next particle
            // without waiting until the end of the sample
            if (prob.coin) { (age * 0.25).wait } { (age + rrand(4, 10)).wait }
        }
    }),
    sporadicAnalogCutoff: Task({
        loop {
            ~sendParticle.(
                particle: (mass:0.6, age:rrand(3, 4),
                    x: (1.0.sum3rand * 100).abs + [100, 500].choose,
                    y: rrand(~worldSize*0.15, ~worldSize*0.2),
                    z: ~worldSize*0.8 // (1.0.sum3rand * 150).abs + 100
                ),
                synth: (name:\sr__e__analog, params:[\cutoff, -1, \att, 0.2, \rel, rrand(4, 6), \amp, 0.6])
            );
            (10 + 2.0.rand2).wait;
        }
    }),
    sporadicPulse: Task({
        var x, y, z;
        loop {
            #x, y, z = ({ (1.0.sum3rand * 150).abs + 100 } ! 3);
            (20 + rand2(20 * 0.25)).wait;
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: rrand(2.7, 5.0), mass: 0.9, spring:[1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__pulse, params: [\att, 2, \rel, 3]));
            (20 + rand2(20 * 0.5)).wait;
        }
    }),
    randomCMBMelo: Task({
        var x, y, z, synthName = [\sr__e__cmb, \sr__e__melo];
        inf.do { |j|
            x = ~worldSize * [0.2, 0.8].choose;
            #y, z = ~worldSize * 0.2 ! 2;
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: rrand(3, 6), mass: 0.9, spring: 1),
                synth: (name: synthName[j % synthName.size] , params: [\att, 1.5, \rel, 3])
            );
            (20 * rrand(0.8, 1.3)).wait;
        }
    }),
    switchScale: Task({
        var sca = ~sequence.scales[0..2];
        inf.do{ |i|
            s.sendMsg("/n_set", nil, \bufnum, sca[i % sca.size].bufnum);
            (6..9).choose.wait;
            s.sendMsg("/n_set", nil, \bufnum, nil);
            (30, 32..60).choose.wait;
        }
    }),
);

CmdPeriod.doOnce({
    // Free buffers.
    guideBuff.free;
});
)
