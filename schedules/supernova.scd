(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime
var scales, buf;

~sequence[\title] = "MOON2: supernova (Part II of poli_2017)";

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
            info: "INTRO: rm all, init"),
        (message: \physics, params: [
			\gravX, \default,
			\gravY, \default,
			\gravZ, \default,
			\drag, 0.23,
			\starMass, 1.5,
			\repulsion, 10,
			\particleSystem, \default,
			\maxVel, 150,
            \springRestLen, \default,
            \springStrength, 1,
            \springDamp, \default,
            \mutualAttraction, \default,
        ]),
        (
            info: "calibration mode",
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
    1: [
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
    2: [
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
        (
            message: \action,  params: [\draw, \skel]
        ),
    ],
    3: [
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
    5: [
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
    10: [
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
    11: [
        (
            info: "TRAIN: remove <wind>",
            message: \action, params: [\remove, 1121],
        ),
    ],
    12: [
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
    13: [
        (
            info: "TRAIN switchScaleAndOffset",
            message: \task, name: \switchScaleAndOffset, act: 1
        ),
    ],
    20: [
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
        (
            message: \action,  params: [\draw, \calibration]
        ),
    ],
    25: [
        (
            info: "NEURO: avant (1) - <buzz> stream 1",
            message: \task, name: \buzzStream1, act: 1
        ),
    ],
    26: [
        (
            info: "NEURO: avant (2) - stream <bgMarkovProcess>",
            message: \task, name: \bgMarkovProcess, act: 1
        ),
    ],
    30: [
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
        (
            message: \action,  params: [\draw, \skel]
        )
    ],
    32: [
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
            info: "Vis mode, stop <buzz> stream 2, remove <melo>",
            message: \action,  params: [\draw, \skelfull]
        ),
        (
            message: \action,  params: [\remove, 1180]
        ),
        (
            message: \action,  params: [\remove, 1181]
        ),
    ],
    33: [
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
            message: \action,  params: [\draw, \graph]
        ),
    ],
    34: [
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
    36: [
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
    37: [
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
    38: [
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
    40: [
        (
            info: "MATH: remove voice 1 effect",
            message: \action,  params: [\remove, 1189]
        ),
        (
            info: "remove voice 2",
            message: \action,  params: [\remove, 1187]
        )
    ],
    41: [
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
    50: [
        (
            info: "NA ULI",
            message: \action,  params: [\remove, 1190]
        ),
        (
            message: \action,  params: [\remove, 1191]
        ),
        (
            message: \action,  params: [\draw, \calibration]
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
    53: [
        (
            info: "NA ULI - draw skel",
            message: \action,  params: [\draw, \skel]
        ),
    ],
    54: [
        (
            info: "NA ULI - draw strob",
            message: \action,  params: [\draw, \skelfull]
        ),
    ],
    55: [
        (
            info: "NA ULI - draw skel",
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