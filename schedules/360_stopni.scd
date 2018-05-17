(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime

//GLOBAL
~sequence[\title] = "Sympli Romatiko: 360 stopni";

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
        (
            message: \action,  params: [\remove, \all],
            info: "Remove all before start\n Apply initial settings"
        ),
        (
            message: \physics,
            params: [
                \gravX, \default,
                \gravY, \default,
                \gravZ, \default,
                \drag, 0.5,
                \repulsion, 10,
                \maxVel, 150,
                \starMass, \default,
                \springRestLen, 3,
                \springStrength, 0.5,
                \springDamp, 2,
                \mutualAttraction, \default
            ]
        ),
        (
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
        ),
    ],
    10: [
        (
            info: "INTRO: <moog> cutoff= -1",
            message: \task, name: \moogCutoff, act: 1
        ),
    ],
    20: [
        ( // Remove all objects.
            info: "SCI-FI",
            message: \action, params: [\remove, \all]
        ),
        ( // Stop schedule with sporadic moog, cutoff= -1
            info: "Remove all, stop sched, particles OFF",
            message: \task, name: \moogCutoff, act: 0
        ),
        ( // remove intro group from server
            message: \g_free, id: \intro_bundle, params: [\release, 80]
        ),
        (
            info: "Ave <pulse>, 2 heavy <moog>",
            message: \particle,
            synth: (name: "pulse", params: [\attack, 40, \release, 10]),
            particle: (
                age: rrand(80, 150),
                mass: 0.6,
                x: 350, y: 120, z: 750,
                spring: 0
            ),
        ),
        // Start 2 heavy <moog> w/default cutoff and long attack
        (
            message: \particle,
            synth: (name: "moog", params: [\attack, 40, \release, 10]),
            particle: (
                mass: 1,
                x: 300, y: 300, z: 250,
                spring: 0
            ),
        ),
        (
            message: \particle,
            synth: (name: "moog", params: [\attack, 40, \release, 10]),
            particle: (
                mass: 1,
                x: 470, y: 300, z: 250,
                spring: 0
            )
        )
    ],
    25: [
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
                params: [
                    \bufnum, ~sequence.scales[0].bufnum,
                    \attack, 2,
                    \release, 5,
                    \threshold, 0.5
                ]
            ),
            particle: (
                mass: 1,
                spring: 1,
                source: \r_hand
            )
        ),
        (
            message: \particle,
            synth: (
                name: "moog",
                params: [
                    \bufnum, ~sequence.scales[0].bufnum,
                    \attack, 2,
                    \release, 5,
                    \threshold, 0.5
                ]
            ),
            particle: (
                mass: 1,
                spring: 1,
                source: \l_hand
            )
        ),
    ],
    99: [
        (
            info: "FIN: Remove all",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Stop sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 0
        )
    ]
);

// Tasks dictionary.
//
~sequence.tasks = (
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
)
)