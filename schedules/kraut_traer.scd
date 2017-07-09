(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime

// // ZZZ - skeleton: remove after test
// var skelData;
// postf("Reading skeleton simulation data\n");
// skelData = File(~currentDir +/+ "experiments/joints.log", "r").readAllString.interpret;

~sequence[\title] = "Sympli Romatiko: kraut Traer World";

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
PathName.new(samplesDir +/+ "test").entries.do { |f, i|
    try {
        ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0]))
    }
};
[
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 2, 5, 7, 10], // the rest are specific to sequence's parts
    FloatArray[0, 2, 4, 8, 10],
    FloatArray[0, 1, 4, 5, 7, 11],
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
            \drag, 0.5,
            \repulsion, 10,
            \starMass, \default,
            \springRestLen, \default,
            \springStrength, 1,
            \springDamp, \default,
            \maxVel, 150,
            \particles, \default,
            \mutualAttraction, \default,
            \audioIn, true
        ])
    ],

    // // ZZZ - skeleton: remove after test
    // 1: [
    //     (
    //         info: "ZZZ - Skeleton simulation",
    //         message: \task, name: \skelSimulation, act: 1
    //     ),
    // ],
    2: [
        (
            info: "2 heavy <pole>",
            message: \particle,
            synth: (name: "pole",
                params: [
                    \attack, 120,
                    \release, 40,
                    \amp, 0.5,
                    \freq, "d 3".notemidi.midicps
                ]
            ),
            particle: (
                mass: 1,
                spring: 1,
                source: \l_hand,
                x: 460, y: 194, z: 327
            )
        ),
        (
            wait: 120,
            message: \particle,
            synth: (
                name: "pole",
                params: [
                    \attack, 120,
                    \release, 40,
                    \amp, 0.5,
                    \freq, "a#2".notemidi.midicps // "g 3".notemidi.midicps
                ]
            ),
            particle: (
                mass: 1,
                spring: 1,
                source: \r_hand,
                x: 194, y: 194, z: 327
            )
        ),
    ],
    6: [
        (
            info: "2 heavy <kick>",
            message: \particle,
            synth: (name: "kick",
                params: [\amp, 0.1, \freq, 36.midicps]),
            particle: (
                age: inf, mass: 1, spring: 1,
                source: \r_hand,
                x: 194, y: 194, z: 327
            )
        ),
        (
            message: \particle,
            synth: (name: "kick",
                params: [\amp, 0.1, \freq, 36.midicps]),
            particle: (age: inf, mass: 1, spring: 1,
                source: \l_hand,
                x: 460, y: 194, z: 327
            )
        )
    ],
    7: [
        // (
        //     info: "heavy <lowe>",
        //     message: \particle,
        //     synth: (name: "lowe",
        //         // XXX - play with \freq (~800 -> noisy and sharp)
        //         // XXX - add it to 2 __entro later to achieve some sort of "melodicity"
        //     params: [\attack, 10, \attack, 12, \release, 0.5, \amp, 0.03]),
        //     particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        // ),
        (
            info: "heavy <bass>",
            message: \particle,
            synth: (name: "bass",
                // XXX - play with \freq (~800 -> noisy and sharp)
                // XXX - add it to 2 __entro later to achieve some sort of "melodicity"
                params: [\attack, 12, \release, 0.5, \freq, 42]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
        (
            info: "heavy <wind>",
            message: \particle,
            synth: (name: "wind",
                params: [\attack, 12, \release, 0.5, \amp, 0.7]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \l_hand)
        )
    ],
    8: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy <lowe>",
            message: \particle,
            synth: (name: "lowe",
                params: [\attack, 0.1, \release, 1, \amp, 0.03]
            ),
            particle: (age: inf, mass: 0.9, spring: 1,
                // should appear close to the source to minimize
                // the effect of environment on sound
                source: \r_hand, x: 330, y: 370, z: 350
            )
        ),
        (
            info: "heavy <wind>",
            message: \particle,
            synth: (name: "wind",
                params: [\attack, 0.1, \release, 1, \amp, 0.7]),
            particle: (age: inf, mass: 0.9, spring: 1,
                // should appear close to the source to minimize
                // the effect of environment on sound
                source: \l_hand, x: 370, y: 370, z: 350
            )
        )
    ],
    9: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Adjust spring params",
            message: \physics, params: [\springStrength, 2, \springDamp, 0.32]
        ),
        (
            info: "2 heavy <komar>",
            message: \particle,
            synth: (
                name: "komar",
                params: [
                    \attack, 0.5,
                    \amp, 0.3,
                    \freq, 282.56,
                    \cutoff, 18500,
                    \rq, 0.35
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "komar",
                params: [
                    \attack, 0.5,
                    \amp, 0.3,
                    \freq, 52.08,
                    \min, -0.83,
                    \max, 0.87,
                    \cutoff, 2915,
                    \rq, 0.65
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        )
    ],
    10: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Spring params to defaults",
            message: \physics, params: [\springStrength, 1, \springDamp, \default]
        ),
        (
            info: "2 heavy <neural>",
            message: \particle,
            synth: (name: "neural", params: [\attack, 15, \cutoff, 1]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "neural", params: [\attack, 15, \cutoff, 1]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            info: "heavy <lowe>",
            message: \particle,
            synth: (name: "lowe",
                params: [\attack, 5.0.rand, \release, 8, \amp, 0.03]),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
    ],
    14: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy <entro>",
            message: \particle,
            synth: (name: "entro", params: [\attack, 0.1, \amp, 0.3]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "entro", params: [\attack, 0.1, \amp, 0.3]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            info: "2 heavy <buzz>",
            message: \particle,
            synth: (name: "buzz", params: [\att, 1, \bufnum, ~sequence.scales[3].bufnum, \offset, 26+24, \amp, 0.05]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "buzz", params: [\att, 1, \bufnum, ~sequence.scales[3].bufnum, \offset, 26+24, \amp, 0.05]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
    ],
    15: [
        (
            info: "__analog 1 for audio through, .kr buses",
            message: \g_new,
            id: \feed_audiothrough1,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", "moog", \next_node_id, 0, \group_id, // add synth to new group's head
                    \out, ~audioThruBus[0], // feeding into the bus designated for audio through
                    \momentum, 0.5, \attack, 40, \bufnum, ~sequence.scales[0].bufnum,
                    \amp, 0.5 // attenuate not to overshout main synth
                ],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \lfo, 0.1, \mul, 0.25, \add, 0.5, \out, 0],
                ["/n_map", \group_id, \momentum, 0],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \lfo, 0.1, \mul, 0.2, \add, 0.2, \out, 1],
                ["/n_map", \group_id, \az, 1]
            ]
        )
    ],
    16: [
        (
            info: "__analog 2 for audio through, .kr buses",
            message: \g_new,
            id: \feed_audiothrough2,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", "moog", \next_node_id, 0, \group_id, // add synth to new group's head
                    \out, ~audioThruBus[1],
                    \momentum, 0.5, \attack, 40, \bufnum, ~sequence.scales[0].bufnum,
                    \amp, 0.5 // attenuate not to overshout main synth
                ],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \lfo, 0.1, \mul, 0.25, \add, 0.5, \out, 2],
                ["/n_map", \group_id, \momentum, 2],
                ["/s_new", \klfno1, \next_node_id, 0, \group_id, \lfo, 0.1, \mul, 0.2, \add, 0.2, \out, 3],
                ["/n_map", \group_id, \az, 3]
            ]
        )
    ],
    17: [
        (
            info: "2 heavy __authro",
            message: \particle,
            synth: (name: "atru",
                params: [\in, ~audioThruBus[0],
                    \attack, 2+1.0.rand2, \release, 5, \threshold, 0.5]),
            particle: (mass: 1, spring: 1, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "atru",
                params: [\in, ~audioThruBus[1],
                    \attack, 2+1.0.rand2, \release, 5, \threshold, 0.5]),
            particle: (mass: 1, spring: 1, source: \r_hand)
        ),
    ],
    20: [
        (
            info: "random particles",
            message: \task, name: \randomParticles, act: 1
        ),
    ],
    30: [
        (
            info: "increase gravity",
            message: \physics, params: [\gravY, -2], // everythin is being dragged "forward"
        ),
    ],
    35: [
        (
            info: "storm",
            message: \task, name: \storm, act: 1
        ),
    ],
    40: [
        (
            info: "stop storm",
            message: \task, name: \randomParticles, act: 0
        ),

        // // ZZZ - skeleton: remove after test
        // (
        //     info: "stop skeleton simulation",
        //     message: \task, name: \skelSimulation, act: 0
        // ),
        (
            info: "stop random particles",
            message: \task, name: \storm, act: 0
        ),
        (
            message: \physics, params: [audioIn: false]
        ),
        ( // remove intro group from server
            message: \g_free, id: \feed_audiothrough, params: [\releaseease, 30]
        ),
    ],
    99: [
        (
            info: "FIN: remove all",
            message: \action,  params: [\remove, \all]
        ),
    ]
);

// Tasks dictionary.
//
~sequence.tasks = (

    // // ZZZ - skeleton: remove after test
    // skelSimulation: Task({
    //     var i=0, coords;
    //     inf.do {
    //         // process
    //         if (i == skelData.size) {i = 0};
    //         coords = skelData[i][1..];
    //         coords[2] = coords[2] + 0.6; // offset
    //         ~sendMessage.(\joint, [skelData[i][0], 1] ++ coords);
    //         i = i + 1;
    //         0.001.wait;
    //     }
    // }),

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
            0.005.wait;
        }
    }),

    storm: Task({
        var buff, synth, age, x, y, z, prob=0.2;
        inf.do { |j|
            buff = ~sequence.samples[j % ~sequence.samples.size];
            age = rrand(2, 3);
            x = ~worldSize * 0.5 + rand2(~worldSize * 0.25); // some area around center
            y = ~worldSize * 0.75; // from "behind"
            z = rand(~worldSize);

            case
            // when samples are introduced, they should be clearly recognizable
            { j <= 5 } {
                synth = \sr__g__loop
            }
            { (j > 5) && (j <= 10) } {
                synth = [\sr__g__loop, \sr__g__loopdel, \sr__g__unst].choose
            }
            { j > 10 } { // later on "smooth them out" into a meshup
                // appear closer to the center of the world
                prob = 0.6; // bigger chance that the next sample will cross with the current one
                synth = [\sr__g__loop, \sr__g__unst, \sr__g__reg].wchoose([0.5, 0.3, 0.2]);

                // occasionally send a light __scratch with the same sample and age
                if (0.3.coin) {
                    ~sendParticle.(
                        particle: (mass:0.1, x:x, y:y, z:z, age:age, spring:0),
                        synth: (
                            name:\sr__g__scratch,
                            params:[\attack, 3, \bufnum, buff.bufnum]
                        )
                    );
                };
            };

            // main "sample particle"
            ~sendParticle.(
                particle: (mass:0.2, x:x, y:y, z:z, age:age, spring:0),
                synth: (
                    name:synth,
                    params:[\attack, 2, \bufnum, buff.bufnum]
                )
            );
            (age + rand2(age * 0.5)).wait
        }
    })
);
)
