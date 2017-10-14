(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime

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

samplesDir = "~/Music/MOON2/samples/";
PathName.new(samplesDir +/+ "kraut_traer").entries.do { |f, i|
    try {
        ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0]))
    };
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
            info: "PART I:\n Remove all, initial settings"),
        (message: \physics, params: [
            \gravX, \default,
            \gravY, \default,
            \gravZ, \default,
            \drag, 0.15,
            \repulsion, 10,
            \starMass, \default,
            \particles, \default,
            \springRestLen, 3,
            \springStrength, 0.5,
            \springDamp, 2,
            \maxVel, 150
        ]),
    ],
    10: [
        (
            info: "AIRY: 2 heavy <probe>\n wait 120s",
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
            wait: 120,
            info: "Schedule <cmb>, <melo>, global scale switch",
            message: \task, name: \randomCMBMelo, act: 1
        ),
        (
            message: \task, name: \switchScale, act: 1
        )
    ],
    15: [
        (
            info: "AIRY: Remove drag force\n wait 120s",
            wait: 120,
            message: \physics, params: [\drag, 0.0]
        ),
    ],
    20: [
        (
            info: "AIRY: + 2 heavy <cmb>",
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
    30: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "AIRY: 2 heavy <melo> floating",
            message: \particle,
            synth: (name: "melo",
                params: [\attack, 1.0, \release, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "melo",
                params: [\attack, 1.0, \release, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            info: "Set starMass to 2.8",
            message: \physics, params: [\starMass, 2.8]
        ),
    ],
    35: [
        (
            info: "AIRY: 2 heavy <melo> controlled",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "WARNING! start skel tracking!",
            message: \particle,
            synth: (name: "melo",
                params: [\attack, 1.0, \release, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "melo",
                params: [\attack, 1.0, \release, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            info: "AIRY: Adjust drag and starMass",
            message: \physics, params: [\drag, 0.5, \starMass, 1]
        ),

    ],
    36: [
        (
            info: "TEST: change draw mode",
            message: \action,  params: [\draw, \skel]
        ),
    ],
    37: [
        (
            info: "TEST: revert calibration draw mode",
            message: \action,  params: [\draw, \calibration]
        ),
    ],
    40: [
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
            info: "heavy <entro> + 2x<komar>",
            message: \particle,
            synth: (name: "entro"),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "komar", params: [\freq, 53.39, \cutoff, 11932.07, \rq, 0.07]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand) // radio must be on r_hand!
        ),
        (
            message: \particle,
            synth: (name: "komar", params: [\freq, 291.16]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand) // radio must be on r_hand!
        ),
    ],
    42: [
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


    50: [
        (message: \action,  params: [\remove, \all],
            info: "PART II:\nRemove all, initial settings"),
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
    51: [
        (
            info: "DARK: LFOs: ksine, keyscale, klfno0",
            message: \lfo,
            synth: (name: "ksine",
                node: 1200,
                params: [
                    \lfreq, 10,
                    \min, "d 3".notemidi.midicps,
                    \max, "a 3".notemidi.midicps,
                    \out, 0
                ]
            ),
        ),
        (
            message: \lfo,
            synth: (name: "keyscale",
                node: 1201,
                params: [
                    \lfreq, 1,
                    \min, 0.2,
                    \max, 0.8,
                    \out, 1
                ]
            ),
        ),
        (
            message: \lfo,
            synth: (name: "klfno2",
                params: [
                    \lfreq, 0.5,
                    \min, "c 2".notemidi.midicps,
                    \max, "g 4".notemidi.midicps,
                    \out, 2
                ]
            ),
        )
    ],
    52: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "DARK: 2 heavy <pole>",
            wait: 120,
            message: \particle,
            synth: (name: "pole",
                node: 1100,
                params: [
                    \attack, 10, //120,
                    \release, 40,
                    // XXX un-comment after TEST
                    \freq, "d 3".notemidi.midicps,

                    // // XXX change after TEST
                    // \freq, \c1, // assign .kr connection
                    // \room, \c0
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
            message: \particle,
            synth: (
                name: "pole",
                node: 1101,
                params: [
                    \attack, 10, //120,
                    \release, 40,
                    // XXX un-comment after TEST
                    \freq, "a#2".notemidi.midicps,

                    // // XXX remove after TEST
                    // \freq, \c2,
                    //
                    // \detune, \c0,
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
    56: [
        (
            info: "DARK: 2 heavy <kick>",
            message: \particle,
            synth: (
                name: "kick",
                node: 1110,
                params: [\amp, 0.5, \freq, "a#3".notemidi.midicps]
            ),
            particle: (
                age: inf, mass: 1, spring: 1,
                source: \r_hand,
                x: 194, y: 194, z: 327
            )
        ),
        (
            message: \particle,
            synth: (
                name: "kick",
                node: 1111,
                params: [\amp, 0.5, \freq, "d 3".notemidi.midicps]
            ),
            particle: (age: inf, mass: 1, spring: 1,
                source: \l_hand,
                x: 460, y: 194, z: 327
            )
        )
    ],
    57: [
        (
            info: "DARK: heavy <bass>",
            message: \particle,
            synth: (
                name: "bass",
                node: 1120,
                params: [
                    \attack, 20,
                    \release, 20,
                    \freq, "g 2".notemidi.midicps,
                    \amp, 0.3
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
        (
            info: "heavy <wind>",
            message: \particle,
            synth: (
                name: "wind",
                node: 1121,
                params: [
                    \attack, 12,
                    \release, 20,
                    \release, 0.5,
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 1, source: \l_hand)
        ),
        (
            info: "remove <kick>",
            message: \action, params: [\remove, 1110],
        ),
        (
            message: \action, params: [\remove, 1111],
        )
    ],
    60: [
        (
            info: "TRAIN: Adjust spring params",
            message: \physics, params: [\springStrength, 2, \springDamp, 0.32]
        ),
        (
            info: "2 heavy <komar>",
            message: \particle,
            synth: (
                name: "komar",
                params: [
                    \attack, 10,
                    \release, 10,
                    \amp, 0.5,
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
                    \attack, 10,
                    \release, 10,
                    \amp, 0.5,
                    \freq, 382.56,
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
                    \release, 10,
                    \amp, 0.5,
                    \freq, 52.08,
                    \min, -0.83,
                    \max, 0.87,
                    \cutoff, 19500,
                    \rq, 0.25
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "komar",
                params: [
                    \attack, 0.5,
                    \release, 10,
                    \amp, 0.5,
                    \freq, 252.08,
                    \min, -0.83,
                    \max, 0.87,
                    \cutoff, 19500,
                    \rq, 0.25
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        )
    ],
    65: [
        (
            info: "TRAIN: remove everything except <komar>",
            message: \action, params: [\remove, 1100],
        ),
        (
            message: \action, params: [\remove, 1101],
        ),
        (
            message: \action, params: [\remove, 1120],
        ),
        (
            message: \action, params: [\remove, 1121],
        )
    ],
    66: [
        (
            info: "TRAIN: Spring params to defaults",
            message: \physics, params: [\springStrength, 1, \springDamp, \default]
        ),
    ],
    70: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "NEURO: 2 heavy <neural>",
            message: \particle,
            synth: (name: "neural", params: [\attack, 1, \cutoff, 1]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "neural", params: [\attack, 1, \cutoff, 1]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            info: "heavy <bass>",
            message: \particle,
            synth: (
                name: "bass",
                params: [
                    \attack, 15,
                    \release, 8,
                    \freq, "g 2".notemidi.midicps,
                    \amp, 0.5
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
    ],
    75: [
        (
            info: "XXX - TEST: Buzz Melody",
            message: \task, name: \buzzMelody, act: 1
        ),
    ],
    80: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "PATA: 2 heavy <entro>",
            message: \particle,
            synth: (
                name: "entro",
                node: 1180,
                params: [\attack, 0.1, \amp, 0.3]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "entro",
                node: 1181,
                params: [\attack, 0.1, \amp, 0.3]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        // (
        //     info: "2 heavy <buzz>",
        //     message: \particle,
        //     synth: (name: "buzz", params: [
        //         \att, 1,
        //         \bufnum,  ~sequence.scales[3].bufnum,
        //         \offset, 26+24,
        //         \amp, 0.05,
        //         \freq, 622.25396744416
        //     ]),
        //     particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        // ),
        // (
        //     message: \particle,
        //     synth: (name: "buzz", params: [
        //         \att, 1,
        //         \bufnum, ~sequence.scales[3].bufnum,
        //         \offset, 26+24,
        //         \amp, 0.05,
        //         \freq, 740
        //     ]),
        //     particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        // ),
    ],
    82: [
        (
            info: "XXX - TEST: Stop Buzz Melody",
            message: \task, name: \buzzMelody, act: 0
        ),
    ],
    85: [
        (
            info: "MATH: remove <entro>",
            message: \action,  params: [\remove, 1180]
        ),
        (
            message: \action,  params: [\remove, 1181]
        ),
        (
            info: "2 heavy <buzz>",
            message: \particle,
            synth: (name: "buzz", params: [
                \att, 1,
                \bufnum,  ~sequence.scales[3].bufnum,
                \offset, 26+24,
                \amp, 0.05,
                \freq, 622.25396744416
            ]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "buzz", params: [
                \att, 1,
                \bufnum, ~sequence.scales[3].bufnum,
                \offset, 26+24,
                \amp, 0.05,
                \freq, 740
            ]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
    ],
    87: [
        (
            info: "MATH: voice 1",
            message: \particle,
            synth: (
                name: "loop",
                node: 1187,
                params: [
                    \att, 1,
                    \bufnum, ~sequence.samples[0].bufnum,
                    \amp, 0.2,
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
    ],
    88: [
        (
            info: "MATH: voice 2",
            message: \particle,
            synth: (
                name: "loop",
                node: 1188,
                params: [
                    \attack, 1,
                    \release, 10,
                    \bufnum, ~sequence.samples[1].bufnum,
                    \amp, 0.2,
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),

    ],
    89: [
        (
            info: "MATH: voice 1 effect",
            message: \particle,
            synth: (
                name: "unst",
                node: 1189,
                params: [
                    \attack, 1,
                    \bufnum, ~sequence.samples[0].bufnum,
                    \amp, 0.2,
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        )
    ],
    90: [
        (
            info: "MATH: remove voice 1 effect",
            message: \action,  params: [\remove, 1189]
        ),
        (
            info: "remove voice 2",
            message: \action,  params: [\remove, 1187]
        )
    ],
    95: [
        (
            info: "MATH: remove voice 2,\n leave buzz alone",
            message: \action,  params: [\remove, 1188]
        )
    ],
    99: [
        (
            info: "FIN: remove all",
            message: \action,  params: [\remove, \all]
        )
    ]
);

// Tasks dictionary.
//
~sequence.tasks = (
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
            ~scsynth.sendMsg("/n_set", nil, \bufnum, sca[i % sca.size].bufnum);
            (6..9).choose.wait;
            ~scsynth.sendMsg("/n_set", nil, \bufnum, nil);
            (30, 32..60).choose.wait;
        }
    }),
    buzzMelody: Task({
        var amp=0, bpm=135;
        inf.do { |j|
            x = ~worldSize * [0.2, 0.8].choose;
            #y, z = ~worldSize * 0.2 ! 2;
            amp = (amp + 0.03).min(1);
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: (60/bpm*4), mass: 0.9, spring: 0),
                synth: (
                    name: "buzz",
                    params: [\attack, 0.2, \release, 0.2, \freq: "a 4".notemidi.midicps, \amp, amp]
                )
            );
            (60/bpm*16).wait;
        }
    })
);
)
