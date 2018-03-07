(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime
var scales;

~sequence[\title] = "STRUCT 5 4 3 2 1";

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
scales = [
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 2, 5, 7, 10], // the rest are specific to sequence's parts
    FloatArray[0, 2, 4, 8, 10],
    FloatArray[0, 1, 4, 5, 7, 11],
    FloatArray[0, 4, 5, 7, 11 ] //["c# 3", "d 3", "f# 3", "g 3", "a 3"].notemidi
];
scales.do { |c, i|
    ~sequence.scales.add(Buffer.sendCollection(~scsynth, c));
};

~sequence.events = (

    0: [
        (
            info: "INTRO: Remove all, initial settings",
            message: \action,  params: [\remove, \all]
        ),
        (
            message: \action,  params: [\draw, \calibration]
        ),
        (
            message: \physics,
            params: [
                \gravX, \default,
                \gravY, \default,
                \gravZ, \default,
                \drag, 0,
                \repulsion, 10,
                \starMass, 1,
                \particleSystem, \default,
                \springRestLen, \default,
                \springStrength, 1,
                \springDamp, \default,
                \maxVel, 150,
                \mutualAttraction, \default,
            ]
        ),
        (
            info: "LFOs <ksine>, <keyscale>, <klfno0>",
            message: \lfo,
            synth: (name: "ksine",
                node: 1251,
                params: [
                    \lfreq, 100,
                    \min, "a 2".notemidi.midicps,
                    \max, "g 4".notemidi.midicps,
                    \out, 2
                ]
            ),
        ),
        (
            message: \lfo,
            synth: (name: "keyscale",
                node: 1252,
                params: [
                    \lfreq, 1,
                    \min, "c 2".notemidi.midicps,
                    \max, "g 4".notemidi.midicps,
                    \out, 3
                ]
            ),
        ),
        (
            message: \lfo,
            synth: (name: "klfno2",
                params: [
                    \lfreq, 0.5,
                    \min, 0.5,
                    \max, 2,
                    \out, 4
                ]
            ),
        ),
    ],
    10: [
        (
            info: "INTRO: 2 heavy <pole>",
            message: \particle,
            synth: (name: "pole",
                node: 1100,
                params: [
                    \attack, 120,
                    \ca, 2,
                    \release, 0.5,
                    \freq, "d 3".notemidi.midicps,
                    \amp, 1,

                    // XXX - assign .kr connection
                    \cutoff, \c1,
                    \room, \c4
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
                    \attack, 120,
                    \ca, 2,
                    \release, 0.5,
                    \freq, "a#2".notemidi.midicps,
                    \amp, 1,

                    // XXX remove after TEST
                    \cutoff, \c2,
                    \detune, \c3,
                    \lfreq, \c4,
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
    15: [
        (
            info: "INTRO: <pole> goes \melo",
            message: \n_set,
            synth: (
                node: 1100,
                params: [
                    \freq, "e 3".notemidi,
                    \bufnum, ~sequence.scales[4].bufnum,
                    \melo, 1
                ]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1101,
                params: [
                    \freq, "e 3".notemidi,
                    \bufnum, ~sequence.scales[4].bufnum,
                    \melo, 1
                ]
            ),
        ),
        (
            info: "heavy <wind>",
            message: \particle,
            synth: (
                name: "wind",
                node: 1121,
                params: [
                    \attack, 20,
                    \release, 40,
                    \amp, 0.5,
                    \decaytime, \c4, // XXX - is it necessary?
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
    ],
    16: [
        (
            info: "INTRO: <wind> goes \LFNoised",
            message: \n_set,
            synth: (
                node: 1121,
                params: [\melo, 1]
            ),
        ),
        (
            info: "<pole> fixed freq",
            message: \n_set,
            synth: (
                node: 1100,
                params: [
                    \freq, "d 2".notemidi.midicps,
                    \melo, 0,
                ]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1101,
                params: [
                    \freq, "d 2".notemidi.midicps,
                    \melo, 0,
                ]
            ),
        ),
    ],
    20: [
        (
            info: "INTRO: remove <pole>",
            message: \action, params: [\remove, 1100],
        ),
        (
            message: \action, params: [\remove, 1101],
        ),
        (
            info: "heavy <bass>",
            message: \particle,
            synth: (
                name: "bass",
                node: 1120,
                params: [
                    \attack, 0.1,
                    \release, 20,
                    \freq, "g 2".notemidi.midicps,
                    \amp, 0.1,
                    \rq, \c0 // XXX
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 1, source: \l_hand)
        ),
        (
            info: "TRAIN: <wind> X <gauss> #1",
            message: \particle,
            synth: (
                name: "gauss",
                node: 1102,
                params: [
                    \attack, 20,
                    \release, 1,
                    \ca, 5,
                    \amp, 0.5
                ]
            ),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \action, params: [\remove, 1121],
        )
    ],
    65: [
        (
            info: "TRAIN: heavy <gauss> #2",
            message: \particle,
            synth: (
                name: "gauss",
                node: 1103,
                params: [
                    \attack, 0.5,
                    \release, 1,
                    \amp, 0.5
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            info: "remove <bass>",
            message: \action, params: [\remove, 1120],
        ),
    ],
    70: [
        (
            info: "NEURO: 2 heavy <neural>, heavy <bass>",
            message: \action,  params: [\remove, \all]
        ),
        (
            message: \particle,
            synth: (name: "neural", params: [\attack, 1, \cutoff, 1, \amp, 1]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "neural", params: [\attack, 1, \cutoff, 1, \amp, 1]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "bass",
                params: [
                    \attack, 15,
                    \release, 8,
                    \freq, "g 2".notemidi.midicps,
                    \amp, 0.08
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 1, source: \l_hand)
        ),
    ],
    75: [
        (
            info: "NEURO: avant (1) - <buzz> stream 1",
            message: \task, name: \buzzStream1, act: 1
        ),
    ],
    76: [
        (
            info: "NEURO: avant (2) - <buzz> stream 2",
            message: \task, name: \buzzStream2, act: 1
        ),
        (
            message: \task, name: \buzzStream1, act: 0
        ),
    ],
    80: [
        (
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy <melo>",
            message: \particle,
            synth: (
                name: "melo",
                node: 1180,
                params: [
                    \attack, 1,
                    \release, 10,
                    \offset, 38,
                    \bufnum, ~sequence.scales[4].bufnum,
                    \cutoff, 1300,
                    \rq, 0.1
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "melo",
                node: 1181,
                params: [
                    \attack, 1,
                    \release, 10,
                    \offset, 38,
                    \bufnum, ~sequence.scales[4].bufnum,
                    \cutoff, 1000,
                    \rq, 0.1
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
    ],
    82: [
        (
            info: "PATA: 2 heavy <entro>",
            message: \particle,
            synth: (
                name: "entro",
                node: 1182,
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "entro",
                node: 1183,
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            info: "Skel mode, stop <buzz> stream 2, remove <melo>",
            message: \action,  params: [\draw, \skelfull]
        ),
        (
            message: \task, name: \buzzStream2, act: 0
        ),
        (
            message: \action,  params: [\remove, 1180]
        ),
        (
            message: \action,  params: [\remove, 1181]
        ),
    ],
    83: [
        (
            info: "PATA: <entro> go high",
            message: \n_set,
            synth: (
                node: 1182,
                params: [
                    \amp, 0.01,
                    \cutoff, 3479.95,
                    \rq, 0.05,
                ]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1183,
                params: [
                    \amp, 0.18,
                    \cutoff, 2244.45,
                    \rq, 0.49,
                ]
            ),
        ),
        (
            message: \action,  params: [\draw, \skel]
        ),
    ],
    84: [
        (
            info: "PATA: <entro> go back low",
            message: \n_set,
            synth: (
                node: 1182,
                params: [
                    \amp, 1,
                    \cutoff, 8570.69,
                    \rq, 0.76,
                ]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1183,
                params: [
                    \amp, 1,
                    \cutoff, 9261.48,
                    \rq, 0.49,
                ]
            ),
        ),
        (
            info: "2 heavy <buzz>",
            message: \particle,
            synth: (name: "buzz", params: [
                \att, 1,
                \bufnum,  ~sequence.scales[3].bufnum,
                \offset, 26+24,
                \amp, 0.1,
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
                \amp, 0.1,
                \freq, 740
            ]),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            message: \action,  params: [\draw, \skelfull]
        ),
    ],
    86: [
        (
            info: "MATH: remove <entro>",
            message: \action,  params: [\remove, 1182]
        ),
        (
            message: \action,  params: [\remove, 1183]
        ),
        (
            info: "Graph mode",
            message: \action,  params: [\draw, \graph]
        ),
    ],
    87: [
        (
            info: "MATH: voice 1",
            message: \particle,
            synth: (
                name: "loopdel",
                node: 1187,
                params: [
                    \att, 1,
                    \bufnum, ~sequence.samples[0].bufnum,
                    \amp, 0.5,
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
                name: "loopdel",
                node: 1188,
                params: [
                    \attack, 1,
                    \release, 10,
                    \bufnum, ~sequence.samples[1].bufnum,
                    \amp, 0.5,
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),

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
        ),
        (
            message: \action,  params: [\draw, \calibration]
        ),
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
            // Occasionally send a light "wind" with an age
            // insufficient to make a big difference in audio.
            // Serves more to create bigger entropy than for the sake of sound.
            if (0.3.coin) {
                ~sendParticle.(
                    particle: (x:x, y:z, z:z, age: rrand(1, 3), mass: 0.9, spring: 1),
                    synth: (name: "wind", params: [\attack, 1, \release, 3, \amp, 0.3])
                );
                (rrand(3, 5)).wait;
            };
            // Main particle
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
    buzzStream1: Task({
        var amp=0.2, quant=60/135;
        inf.do { |j|
            x = ~worldSize * [0.3, 0.7].choose;
            #y, z = ~worldSize * 0.3 ! 2;
            amp = (amp + 0.025).min(1);
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: quant*4, mass: 0.9, spring: 0),
                synth: (
                    name: "buzz",
                    params: [\attack, 0.2, \release, 0.2, \freq: "a 4".notemidi.midicps, \amp, amp]
                )
            );
            (quant*16).wait;
        }
    }),
    buzzStream2: Task({
        var quant=60/135;
        inf.do { |j|
            x = ~worldSize * [0.3, 0.7].choose;
            #y, z = ~worldSize * 0.3 ! 2;
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: quant*4, mass: 0.9, spring: 0),
                synth: (
                    name: "buzz",
                    params: [
                        \attack, 0.01,
                        \release, 1,
                        \amp, 0.5,
                        \freq: \c2
                    ]
                )
            );
            (quant*16).wait;
        }
    }),
);
)