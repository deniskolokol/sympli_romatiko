(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime

//GLOBAL
~sequence[\title] = "Sympli Romatiko: band in Traer World";

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

samplesDir = "~/Music/MOON2/samples/";
PathName.new(samplesDir +/+ "drums").entries.do { |f, i|
    try { ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
PathName.new(samplesDir +/+ "voices").entries.do { |f, i|
    try { ~sequence.voices.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
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
        (message: \physics, params: [
            \gravX, \default,
            \gravY, \default,
            \gravZ, \default,
            \drag, 0.001,
            \repulsion, \default,
            \starMass, \default,
            \particleSystem, \default,
            \springRestLen, 3,
            \springStrength, 0.5,
            \springDamp, 2,
            \mutualAttraction, \default
        ]),
    ],
    5: [
        (
            wait: 120,
            info: "INTRO, no objects, only .kr buses",
            message: \g_new,
            id: \intro_bundle,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", "humm__" ++ ~spatial.(), \next_node_id, 0, \group_id, // add synth to new group's head
                    \momentum, 0.5,
                    \attack, 40,
                    \bufnum, ~sequence.scales[4].bufnum,
                    \depth, ~depth,
                    \out, ~outbus
                ],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \lfo, 0.2, \mul, 1pi, \out, 0],
                ["/n_map", \group_id, \azimuth, 0],
                ["/s_new", \kstepno, \next_node_id, 0, \group_id, \lfo, 0.08, \mul, 0.3, \add, 0.7, \out, 1],
                ["/n_map", \group_id, \distance, 1],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \lfo, 0.1, \mul, 0.25, \add, 0.5, \out, 2],
                ["/n_map", \group_id, \momentum, 2],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \lfo, 0.01, \mul, 0.1, \add, 0.1, \out, 3],
                ["/n_map", \group_id, \az, 3]
            ]
        )
    ],
    7: [
        (
            wait: 5*60,
            info: "INTRO: particleSystem",
            message: \physics, params: [\particleSystem, 1, \maxVel, 2]
        ),
        (
            info: "Silent object",
            message: \particle,
            synth: (name: "silent"),
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
                ["/s_new", "wind__" ++ ~spatial.(), \next_node_id, 0, \group_id, // add synth to new group's head
                    \momentum, 0.5,
                    \attack, 120,
                    \depth, ~depth,
                    \out, ~outbus
                ],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \freq, 0.2, \mul, 1pi, \out, 4],
                ["/n_map", \group_id, \azimuth, 4],
                ["/s_new", \kstepno, \next_node_id, 0, \group_id, \freq, 0.08, \mul, 2.3, \add, 2.7, \out, 5],
                ["/n_map", \group_id, \distance, 5],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \freq, 1, \mul, 0.2, \add, 0.6, \out, 6],
                ["/n_map", \group_id, \momentum, 6]
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
            synth: (name: "greg", params: [
                \ca, 5, \attack, rand(40, 60), \release, 10, \bufnum, ~sequence.voices.choose.bufnum
            ]),
            particle: (mass: 0.5),
        ),
        (
            message: \particle,
            synth: (name: "drone", params: [
                \ca, 5, \attack, rand(80, 120), \release, 10, \bufnum, ~sequence.voices.choose.bufnum
            ]),
            particle: (mass: 0.5),
        ),
    ],
    20: [
        (
            info: "Physics environment change",
            message: \physics,
            params: [\drag, 0.5, \repulsion, 10, \maxVel, 150]
        ),
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
            info: "INTRO: <moog> cutoff= -1",
            message: \task, name: \moogCutoff, act: 1
        ),
    ],
    31: [
        ( // Remove all objects.
            info: "SCI-FI",
            message: \action, params: [\remove, \all]
        ),
        ( // Stop schedule with sporadic moog, cutoff= -1
            info: "Remove all, stop sched, particles OFF",
            message: \task, name: \moogCutoff, act: 0
        ),
        ( // Clear \intro schedule
            message: \task, name: \intro, act: 0
        ),
        ( // Stop occasional particles
            message: \task, name: \randomParticles, act: 0
        ),
        ( // switch particles OFF
            message: \physics, params: [particleSystem: 0]
        ),
        ( // remove intro group from server
            message: \g_free, id: \intro_bundle, params: [\release, 80]
        ),
        ( // remove noisy synth group from server
            message: \g_free, id: \intro_noisy, params: [\release, 80]
        ),
        (
            info: "Ave <pulse>, 2 heavy <moog>",
            message: \particle,
            synth: (name: "pulse", params: [\attack, 40, \release, 10]),
            particle: (age: rrand(80, 150), mass: 0.6, x: 350, y: 120, z: 750),
        ),
        // Start 2 heavy <moog> w/default cutoff and long attack
        (
            message: \particle,
            synth: (name: "moog", params: [\attack, 40, \release, 10]),
            particle: (mass: 1, x: 300, y: 300, z: 250),
        ),
        (
            message: \particle,
            synth: (name: "moog", params: [\attack, 40, \release, 10]),
            particle: (mass: 1, x: 470, y: 300, z: 250)
        )
    ],
    34: [
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
            info: "2 heavy <moog>",
            message: \particle,
            synth: (
                name: "moog",
                params: [\bufnum, ~sequence.scales[0].bufnum, \attack, 2 + 1.0.rand2, \release, 5, \threshold, 0.5]
            ),
            particle: (mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "moog",
                params: [\bufnum, ~sequence.scales[0].bufnum, \attack, 2 + 1.0.rand2, \release, 5, \threshold, 0.5]
            ),
            particle: (mass: 1, spring: 1, source: \l_hand)
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
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Midrange <moog> w/wt/cutoff",
            message: \particle,
            synth: (name: "moog", params: [\attack, 2, \release, 10, \amp, 0.4]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "moog", params: [\attack, 2, \release, 10, \cutoff, -1, \amp, 0.2]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \l_hand)
        ),
        (
            info: "Light <lowe> ~heaviness", // must be on the same hand with cutoff!
            message: \particle,
            synth: (name: "lowe", params: [\attack, 2 + 1.0.rand2, \release, 10]),
            particle: (mass: 0.9, spring: 1, x: 470, y: 300, z: 250, source: \l_hand)
        ),
        (
            info: "Two heavy <therems>",
            message: \particle,
            synth: (name: "therem", params: [\attack, 2, \release, 10, \amp, 0.3]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \l_hand),
        ),
        (
            message: \particle,
            synth: (name: "therem", params: [\attack, 2, \release, 10, \amp, 0.3]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
    ],
    50: [
        (
            info: "AIRY - 1st change automatic!",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy <probe>",
            message: \particle,
            synth: (name: "probe",
                params: [\attack, 2+1.0.rand2, \release, 60, // very long release for xfade
                    \bufnum, ~sequence.scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "probe",
                params: [\attack, 2+1.0.rand2, \release, 60, // very long release for xfade
                    \bufnum, ~sequence.scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \l_hand),
        ),
        (
            info: "Schedule <cmb> & <melo>",
            wait: 180,
            message: \task, name: \randomCMBMelo, act: 1
        ),
        (
            info: "Schedule scale switch",
            message: \task, name: \switchScale, act: 1
        )
    ],
    60: [
        (
            info: "2 heavy <cmb>",
            message: \particle,
            synth: (name: "cmb", params: [\attack, 30, \release, 20]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand),
        ),
        (
            message: \particle,
            synth: (name: "cmb", params: [\attack, 30, \release, 20]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
    ],
    70: [
        (
            info: "ELECTRO SOLO",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy <melo>",
            message: \particle,
            synth: (name: "melo",
                params: [\attack, 5.0.rand, \release, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "melo",
                params: [\attack, 5.0.rand, \release, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
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
            info: "heavy <entro> + <radio>",
            message: \particle,
            synth: (name: "entro"),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "komar"),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand) // radio must be on r_hand!
        ),
    ],
    82: [
        (
            info: "BREAKS",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy <entro>",
            message: \particle,
            synth: (name: "entro"),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "entro"),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand)
        ),
    ],
    90: [
        (
            info: "GROOVE",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "two heavy <gauss>",
            message: \particle,
            synth: (name: "gauss", params: [\attack, 60, \release, 16, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "gauss", params: [\attack, 60, \release, 16, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand)
        )
    ],
    92: [
        ( // Remove all objects.
            info: "OUTRO",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy <wind>",
            message: \particle,
            synth: (name: "wind", params: [\attack, 5.0.rand, \release, 10]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "wind", params: [\attack, 5.0.rand, \release, 10]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand)
        ),
        (
            info: "heavy <pulse> with long attack",
            message: \particle,
            synth: (name: "pulse",
                params: [\attack, 120, \release, 10, \ca, 5, \bufnum, ~sequence.scales[3].bufnum]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand) // must be on l_hand!
        )
    ],
    99: [
        (
            info: "FIN: Remove all",
            message: \action,  params: [\remove, \all]
        ),
    ]
);

// Tasks dictionary.
//
~sequence.tasks = (
    randomParticles: Task({
        var key, next;
        var params = [ // list of acceptable configurations
            [\partSynth, "wind",  \partSigmoidRatio, 0.3, \partAgeThresh, 1.67, \partInitAccel, 10 ],
            [                     \partSigmoidRatio, 0.7, \partAgeThresh, 0.20, \partInitAccel, 30 ],
            [\partSynth, "melo",  \partSigmoidRatio, 0.7, \partAgeThresh, 0.78, \partInitAccel, 2.0],
            [\partSynth, "cmb",   \partSigmoidRatio, 0.4, \partAgeThresh, 0.20, \partInitAccel, 30 ],
            [\partSynth, "wind",  \partSigmoidRatio, 0.7, \partAgeThresh, 1.08, \partInitAccel, 8.0],
            [\partSynth, "pulse", \partSigmoidRatio, 0.2, \partAgeThresh, 1.03, \partInitAccel, 20 ],
            [\partSynth, "wind",  \partSigmoidRatio, 0.2, \partAgeThresh, 1.67, \partInitAccel, 1.0],
        ];
        inf.do { |i|
            2.do { |j|
                key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.3, 0.6, 0.1]);
                next = msetObjSeq.next(key);
                next = (next + rand2(next * 0.25));
                ~sendMessage.(\physics, params[i % params.size]);
                next.wait;
            };
            0.01.wait;
        }
    }),

    intro: Task({
        // INTRO:
        // Picks up a key and the number of iterations randomly (average
        // sequences are the most probable, long are the least probable).
        //
        // A new particle's age spans over to the next object birth (no gaps).
        // The lighter the object the faster it dies, but demography is denser.
        var key, next, name, synth, mass, age;
        var params = (
            komar: [\cutoff, 12000, \rq, 0.7, \amp, 0.05],
            humm: [\bufnum, ~sequence.scales[4].bufnum, \amp, 0.9],
            lowe: [\amp, 0.05]
        );
        loop {
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 10, 1].normalizeSum);
            dictObjSeq[key.asInteger][0].choose.do{ |i|
                next = msetObjSeq.next(key);
                age = next * (1 + (1/(next.pow(0.33))));
                mass = next.sqrt.clip(0.1, 0.3);
                name = ["humm", "komar"][i % 2]; // alternate
                synth = (
                    name: name,
                    params: [\attack, rrand(1, 3)] ++ params[name.asSymbol]
                );
                ~sendParticle.(
                    synth: synth,
                    particle: (mass:mass, age:age)
                );

                if (0.7.coin) {
                    name = ["lowe", "komar", "humm"].wchoose([0.6, 0.2, 0.2]);
                    synth = (
                        name: name,
                        params: [\attack, rrand(1, 3)] ++ params[name.asSymbol]
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
            #x, y, z = { rrand(~worldSize, ~worldSize * ([0.2, 0.8].choose)) } ! 3;

            case
            // when voices are introduced, they should be clearly recognizable
            { j <= 5 } {
                synth = "loop"
            }
            { (j > 5) && (j <= 10) } {
                synth = ["loop", "loopdel", "unst"].choose
            }
            { j > 10 } { // later on "smooth them out" into a voice meshup
                // appear closer to the center of the world
                #x, y, z = { (~worldSize / 2 + rand2(~worldSize * 0.15))} ! 3;
                prob = 0.6; // bigger chance that the next sample will cross with the current one
                synth = ["loop", "unst", "greg"].wchoose([0.5, 0.3, 0.2]);

                // occasionally send a light __scratch with the same sample and age
                if (0.3.coin) {
                    ~sendParticle.(
                        particle: (mass:0.1, x:x, y:z, z:z, age:age),
                        synth: (
                            name: "scratch",
                            params:[\attack, 3, \bufnum, buff.bufnum]
                        )
                    );
                };
            };

            // main "voice particle"
            ~sendParticle.(
                particle: (mass:0.5, x:x, y:z, z:z, age:age),
                synth: (
                    name:synth,
                    params:[\attack, 2, \bufnum, buff.bufnum]
                )
            );
            // vary waiting time - every now and then send the next particle
            // without waiting until the end of the sample
            if (prob.coin) { (age * 0.25).wait } { (age + rrand(4, 10)).wait }
        }
    }),
    moogCutoff: Task({
        loop {
            ~sendParticle.(
                particle: (mass:0.6, age:rrand(3, 4),
                    x: [0.3, 0.7].choose * ~worldSize,
                    y: ~worldSize*0.25,
                    z: ~worldSize*0.6
                ),
                synth: (
                    name: "moog",
                    params:[\cutoff, -1, \attack, 0.2, \release, rrand(4, 6), \amp, 0.2]
                )
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
                synth: (name: "pulse", params: [\attack, 2, \release, 3]));
            (20 + rand2(20 * 0.5)).wait;
        }
    }),
    randomCMBMelo: Task({
        var x, y, z, synthName = ["cmb", "melo"];
        inf.do { |j|
            x = ~worldSize * [0.2, 0.8].choose;
            #y, z = ~worldSize * 0.2 ! 2;
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: rrand(3, 6), mass: 0.9, spring: 1),
                synth: (name: synthName[j % synthName.size] , params: [\attack, 1.5, \release, 3])
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
)
)