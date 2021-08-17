(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime
var scales, buf;

~sequence[\title] = "Sympli Romatiko: poli 2017";

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

samplesDir = "/run/media/deko/Vayu/Music/MOON2/samples/";
PathName.new(samplesDir +/+ "kraut_traer").entries.do { |f, i|
    try {
        buf = Buffer.readChannel(~scsynth, f.fullPath, channels: [0]);
        ~reportBufLoad.(buf);
        ~sequence.samples.add(buf);
    } { |err|
        postf("ERROR: %\n", err);
    };
};
PathName.new(samplesDir +/+ "voices").entries.do { |f, i|
    try { ~sequence.voices.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
scales = [
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 2, 5, 7, 10], // the rest are specific to sequence's parts
    FloatArray[0, 2, 4, 8, 10],
    FloatArray[0, 1, 4, 5, 7, 11],
    FloatArray[0, 4, 5, 7, 11 ] //["c# 3", "d 3", "f# 3", "g 3", "a 3"].notemidi
];
scales.do { |c, i|
    buf = Buffer.sendCollection(~scsynth, c);
    ~reportBufLoad.(buf);
    ~sequence.scales.add(buf);
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
        (
            message: \action,  params: [\draw, \calibration]
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
        ),
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
    12: [
        (
            info: "INTRO: voices",
            message: \task, name: \voices, act: 1
        ),
    ],
    13: [
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
    14: [
        (
            info: "Physics environment change",
            message: \physics,
            params: [\drag, 0.5, \repulsion, 10, \maxVel, 150]
        ),
    ],
    15: [
        (
            info: "INTRO: stop voices",
            message: \task, name: \voices, act: 0
        ),
        (
            message: \physics, params: [audioIn: false]
        )
    ],
    16: [
        (
            info: "INTRO: <moog> cutoff= -1",
            message: \task, name: \moogCutoff, act: 1
        ),
    ],

    20: [
        (message: \action,  params: [\remove, \all],
            info: "MVT I: rm all, stop sched, init"),
        ( // Stop schedule with sporadic moog, cutoff= -1
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
        (message: \physics, params: [
            \springRestLen, \default,
            \springStrength, 1,
            \springDamp, \default,
            \mutualAttraction, \default,
        ]),
    ],
    21: [
        (
            info: "DARK: 2 heavy <pole>",
            message: \particle,
            synth: (name: "pole",
                node: 1100,
                params: [
                    \attack, 120,
                    \ca, 2,
                    \release, 5,
                    \freq, "d 3".notemidi.midicps,
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
                    \release, 5,
                    \freq, "a#2".notemidi.midicps,
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
    22: [
        (
            info: "DARK: <pole> goes \melo",
            message: \n_set,
            synth: (
                node: 1100,
                params: [
                    \freq, "e 3".notemidi,
                    \bufnum, ~sequence.scales[4].bufnum,
                    \threshold, 0.7,
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
                    \threshold, 0.5,
                    \melo, 1
                ]
            ),
        ),
    ],
    23: [
        (
            info: "TRAIN: transition heavy <bass>",
            message: \particle,
            synth: (
                name: "bass",
                node: 1110,
                params: [
                    \attack, 0.1,
                    \release, 2,
                    \freq, "a 2".notemidi.midicps,
                    \amp, 0.5,
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 0, x: 300, y: 300, z: 150)
        ),
        (
            info: "heavy <wind>",
            message: \particle,
            synth: (
                name: "wind",
                node: 1121,
                params: [
                    \attack, 0.1,
                    \release, 2,
                    \amp, 0.6,
                    \decaytime, \c4, // XXX
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 1, source: \r_hand)
        ),
        (
            info: "attenuate <pole>",
            message: \n_set,
            synth: (
                node: 1100,
                params: [ \amp, 0 ]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1101,
                params: [ \amp, 0 ]
            ),
        ),
    ],
    25: [
        (
            info: "TRAIN: <wind> goes \LFNoised",
            message: \n_set,
            synth: (
                node: 1121,
                params: [\melo, 1]
            ),
        ),
        (
            info: "<pole> goes momentum controlled",
            message: \n_set,
            synth: (
                node: 1100,
                params: [\amp, 1, \ampc, 1]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1101,
                params: [\amp, 1, \ampc, 1]
            ),
        ),
        (
            info: "heavy <bass> - hook on spring",
            message: \particle,
            synth: (
                name: "bass",
                node: 1120,
                params: [
                    \attack, 0.1,
                    \release, 20,
                    \freq, "g 2".notemidi.midicps,
                    \amp, 0.2,
                    \rq, \c0 // XXX
                ]
            ),
            particle: (age: inf, mass: 0.9, spring: 1,  source: \r_hand, x: 470, y: 300, z: 250)
        ),
        (
            message: \action, params: [\remove, 1110],
        ),
    ],
    30: [
        (
            info: "TRAIN: <pole> & <bass> fixed freq, continuous",
            message: \n_set,
            synth: (
                node: 1100,
                params: [
                    \freq, "g 2".notemidi.midicps,
                    \melo, 0,
                    \ampc, 0,
                ]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1101,
                params: [
                    \freq, "a 2".notemidi.midicps,
                    \melo, 0,
                    \ampc, 0,
                ]
            ),
        ),
        (
            info: "attenuate <bass>",
            message: \n_set,
            synth: (
                node: 1120,
                params: [
                    \freq, "f 3".notemidi.midicps,
                    \amp, 0.2,
                ]
            ),
        ),
    ],
    31: [
        (
            info: "TRAIN: remove <wind>",
            message: \action, params: [\remove, 1121],
        ),
    ],
    32: [
        (
            info: "TRAIN: go melo",
            message: \n_set,
            synth: (
                node: 1100,
                params: [
                    \bufnum, ~sequence.scales[4].bufnum,
                    \melo, 1,
                    \threshold, 0.1,
                    \lfreq, \c0,
                ]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1101,
                params: [
                    \bufnum, ~sequence.scales[4].bufnum,
                    \melo, 1,
                    \threshold, 0.1,
                    \lfreq, \c1,
                ]
            ),
        ),
        (
            message: \n_set,
            synth: (
                node: 1120,
                params: [
                    \bufnum, ~sequence.scales[4].bufnum,
                    \melo, 1
                ]
            ),
        ),
    ],
    33: [
        (
            info: "TRAIN switchScaleAndOffset",
            message: \task, name: \switchScaleAndOffset, act: 1
        ),
    ],
    70: [
        (
            info: "NEURO: 2 heavy <neural>, heavy <bass>",
            message: \action,  params: [\remove, \all]
        ),
        (
            message: \task, name: \switchScaleAndOffset, act: 0
        ),
        (
            message: \particle,
            synth: (name: "neural", params: [\attack, 1, \cutoff, 1, \amp, 0.8]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (name: "neural", params: [\attack, 1, \cutoff, 1, \amp, 0.8]),
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
            info: "NEURO: avant (2) - stream <bgMarkovProcess>",
            message: \task, name: \bgMarkovProcess, act: 1
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
        (
            info: "2 heavy <komar> - /elbows",
            message: \particle,
            synth: (
                name: "komar",
                node: 1195,
                params: [
                    \attack, 1,
                    \release, 10,
                    \freq, 3041,
                    \maxdelaytime, 1.33,
                    \decaytime, 1,
                    \cutoff, 1690.92,
                    \rq, 0.71,
                    \amp, 0.18
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \r_elbow)
        ),
        (
            message: \particle,
            synth: (
                name: "komar",
                node: 1196,
                params: [
                    \attack, 1,
                    \release, 10,
                    \freq, 3041,
                    \maxdelaytime, 1.33,
                    \decaytime, 1,
                    \cutoff, 1690.92,
                    \rq, 0.71,
                    \amp, 0.18
                ]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_elbow)
        ),
        (
            message: \task, name: \buzzStream1, act: 0
        ),
        (
            message: \task, name: \bgMarkovProcess, act: 0
        ),
    ],
    82: [
        (
            info: "PATA: 2 heavy <entro>",
            message: \particle,
            synth: (
                name: "entro",
                node: 1182,
                params: [\amp, 0.7]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "entro",
                node: 1183,
                params: [\amp, 0.7]
            ),
            particle: (age: inf, mass: 1, spring: 1, source: \l_hand)
        ),
        (
            info: "Skel mode, stop <buzz> stream 2, remove <melo>",
            message: \action,  params: [\draw, \skelfull]
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
            synth: (
                name: "buzz",
                node: 1190,
                params: [
                    \attack, 1,
                    \release, 120,
                    \bufnum,  ~sequence.scales[3].bufnum,
                    \offset, 26+24,
                    \amp, 0.3,
                    \freq, 622.25396744416
            ]),
            particle: (age: inf, mass: 1, spring: 1, source: \r_hand)
        ),
        (
            message: \particle,
            synth: (
                name: "buzz",
                node: 1191,
                params: [
                    \attack, 1,
                    \release, 120,
                    \bufnum, ~sequence.scales[3].bufnum,
                    \offset, 26+24,
                    \amp, 0.3,
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
    92: [
        (
            info: "MATH: remove voice 2,\n leave buzz alone",
            message: \action,  params: [\remove, 1188]
        ),
        (
            info: "remove <komar>",
            message: \action, params: [\remove, 1195],
        ),
        (
            message: \action, params: [\remove, 1196],
        ),
    ],

    // + na ulice
    93: [
        (
            info: "GROOVE",
            message: \action,  params: [\remove, 1190]
        ),
        (
            message: \action,  params: [\remove, 1191]
        ),
        (
            message: \action,  params: [\draw, \skel]
        ),
        (
            info: "two heavy <gauss>",
            message: \particle,
            synth: (name: "gauss", params: [
                \attack, 10, // 60,
                \release, 3,
                \ca, 5
            ]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "gauss", params: [
                \attack, 10, // 60,
                \release, 3,
                \ca, 5
            ]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand)
        )
    ],
    94: [
        (
            info: "GROOVE - draw strob",
            message: \action,  params: [\draw, \skelfull]
        ),
    ],
    95: [
        (
            info: "GROOVE - draw skel",
            message: \action,  params: [\draw, \skel]
        ),
    ],
    99: [
        (
            info: "FIN: remove all",
            message: \action,  params: [\remove, \all]
        ),
        (
            message: \func,
            name: \finWin,
            run: {
                var tw, cursorTask, cnt=0;
                var visHost = NetAddr("192.168.1.131", 7110);
                var win = Window("FIN",
                    Rect(590, Window.screenBounds.height-~worldSize, Window.screenBounds.width, Window.screenBounds.height),
                    border: false
                );
                win.background = Color.black;
                win.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
                    case
                    { keycode == 8 } { // C
                        if (modifiers == 262144) { // Ctrl + C
                            win.close;
                        }
                    }
                };
                tw = TextView(win.asView, bounds: Rect(0, 0, win.bounds.width, win.bounds.height))
                .font_(Font("Courier", 16))
                .background_(Color.grey(alpha:0.01))
                .string_("\n  [exited]\n  pi@deko-rpi-1:~/ ▓");
                tw.setStringColor(Color.white, 0, 12);
                tw.setStringColor(Color.green, 13, 14);
                tw.setStringColor(Color.white, 27, 1);
                tw.setStringColor(Color.blue, 28, 3);
                tw.select(tw.string.size, 1); // autoscroll
                cursorTask = Task({
                    inf.do {
                        {
                            if (win.isClosed.not) {
                                if (cnt % 5 == 0) { tw.setStringColor(Color.white, 30, 3) };
                                if (cnt % 10 == 0) { tw.setStringColor(Color.grey(alpha:0.001), 30, 3) };
                            } {
                                cursorTask.stop
                            }
                        }.defer;
                        cnt = cnt + 1;
                        0.1.wait
                    };
                }).play;

                win.front;
                win.fullScreen;
                win.onClose = { cursorTask.stop };

                // also send kill signal to visualisation host
                visHost.sendMsg("/user", "kill");
            }
        ),
        (
            message: \action,  params: [\draw, \calibration]
        ),
    ]
);

// Tasks dictionary.
//
~sequence.tasks = (
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
    switchScaleAndOffset: Task({
        var sca = ~sequence.scales[3..4];
        var offset = [
            "e 1", "g 1", "a# 1", "c# 1",
            "a# 1", "e 1", "g 1", "a 1"
        ];
        var note;
        inf.do{ |i|
            postf("? switchScaleAndOffset: scale %\n", scales[i % sca.size]);
            ~scsynth.sendMsg("/n_set", nil, \bufnum, sca[i % sca.size].bufnum);
            (6..9).choose.wait;

            note = offset[i % offset.size].notemidi + (12* (0..3).choose);
            postf("? switchScaleAndOffset: note % (%: %)\n",
                note.midinote, note, note.midicps.round(0.0001)
            );
            ~scsynth.sendMsg("/n_set", nil, \freq, note.midicps);
            (1..15).choose.wait;
        }
    }),
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
    bgMarkovProcess: Task({
        var msetWait= MarkovSet([ // markov set for waiting time (1st order)
            [\s, [4, 4.5, 5, 5.5]], // short
            [\a, [6, 6.5, 7, 7.5, 8, 8.5, 9, 10, 12]], // ave
            [\l, [20, 25, 27, 32, 40, 45, 55, 60, 90, 120], // long
                [6, 7, 4, 4, 3, 3, 2, 2, 1, 1].normalizeSum
            ]
        ]);
        var msetKey= MarkovSet([ // markov set for number of msetWait use (2nd order)
            [\n,
                [2, 5, 10, 12, 15, 25, 40], // number of repeats
                [6, 12, 9, 3, 2, 0.5, 0.1].normalizeSum // longer sequences are less probable
            ]
        ]);
        var keySteps, key, waitKey, wait, midinote, flytime, x, y, z;
        inf.do({ |i|
            key= msetWait.dict.keys.asArray.choose;
            keySteps= msetKey.next(\n);
            postf("\n? TASK:bgMarkovProcess:\n\tkey: %\n\tsteps: %\n\n",
                key, keySteps
            );
            keySteps.do({ |j|
                waitKey = msetWait.next(key);
                wait = rrand(waitKey * 0.75, waitKey).max(0.01);
                // the shorter dur, the higher the note
                midinote = wait.linlin(0.5, 120, 10, 80);
                // flying time varies but depends on the current duration
                flytime = key.switch(
                    \ss, {0.1},
                    \s, {rrand(0.5, 2)},
                    \a, {rrand(2, 3)},
                    \l, {rrand(1, 10)}
                );
                postf(
                    "\n? TASK:bgMarkovProcess %:%\n\twait time: %\n\tflying time: %\n\tmidinote: % (%)\n\n",
                    i, j, wait.round(0.001), flytime, midinote.round(0.001), midinote.midinote
                );
                x = ~worldSize * [0.3, 0.7].choose;
                #y, z = ~worldSize * 0.3 ! 2;
                ~sendParticle.(
                    particle: (x:x, y:z, z:z, age: 0.5, mass: 0.9, spring: 0),
                    synth: (
                        name: "bass",
                        params: [
                            \attack, 0.01,
                            \release, 0.01,
                            \amp, 0.3,
                            \freq, "d 6".notemidi.midicps,
                        ]
                    )
                );
                0.5.wait;
                ~sendParticle.(
                    particle: (x:x, y:z, z:z, age: flytime, mass: 0.9, spring: 1),
                    synth: (
                        name: "glide",
                        params: [
                            \attack, 0.1,
                            \release, 1,
                            \freq, rrand(24, 240),
                            \amp, 0.6
                        ]
                    )
                );
                flytime.wait;
                ~initSynth.("shov", params: [\freq, midinote.midicps, \amp, 0.7]);
                (wait-flytime).max(0.1).wait;
            });
        });
    })
);
)