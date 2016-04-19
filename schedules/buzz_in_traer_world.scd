(
var currentScale, currentOffset=24;
var validScales=all{: c, c <- ScaleInfo.scales, c.pitchesPerOctave == 12};

~sequence = (
    title: "Buzz in Traer World",
    events: Dictionary.new,
    tasks: Dictionary.new,
    scales: List.new,
    samples: List.new,
    voices: List.new,
);
[
    FloatArray[0, 3, 5],
    FloatArray[0, 2, 5],
    FloatArray[0, 5, 9],
    FloatArray[0, 3, 7, 10],
    FloatArray[0, 3, 5, 7, 10],
].do { |c, i|
    ~sequence.scales.add(Buffer.sendCollection(~scsynth, c));
};

currentScale = ~sequence.scales[3];

// events
~sequence.events = (
    0: [
        (message: \action,  params: [\remove, \all],
            info: "Remove all before start\n Apply initial settings"),
        (message: \physics, params: [\gravX, \default]),
        (message: \physics, params: [\gravY, \default]),
        (message: \physics, params: [\gravZ, \default]),
        (message: \physics, params: [\drag, 0]),
        (message: \physics, params: [\repulsion, 25]),
        (message: \physics, params: [\starMass, 1.3]),
        (message: \physics, params: [\particles, \default]),
        (message: \physics, params: [\mutualAttraction, true]),
    ],
    1: [
        (
            info: "Constant humm",
            message: \g_new,
            id: \constant_humm,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \distance, 2.sqrt,
                    \route, 12, // getting signal from synth
                    \outbus, ~outbus // to main output
                ],
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 12, // feeding into spatilizer
                    \velocity, 0.5,
                    \att, 40,
                    \bufnum, currentScale.bufnum,
                    \offset, currentOffset
                ],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 1pi, \outbus, 0],
                ["/n_map", \group_id, \azimuth, 0],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08, \mul, 1.25, \add, 2.75, \outbus, 1],
                ["/n_map", \group_id, \distance, 1],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.25, \add, 0.5, \outbus, 2],
                ["/n_map", \group_id, \velocity, 2],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.01, \mul, 0.1, \add, 0.1, \outbus, 3],
                ["/n_map", \group_id, \az, 3]
            ]
        ),
    ],
    2: [
        (
            info: "Pulse -X- Pad",
            message: \task, name: \pulseXPad, act: 1
        ),
    ],
    10: [
        (
            info: "Silent object",
            message: \particle,
            synth: (name: \sr__e__silent),
            particle: (mass: 1, x: 470, y: 300, z: 250)
        ),
        (
            info: "Flying synths",
            message: \task, name: \flyingSynths, act: 1
        ),
    ],
    15: [
        (
            info: "Particles machine",
            message: \task, name: \particlesMachine, act: 1
        ),
    ],
    20: [
        (
            info: "Kaleidoscope of scales",
            message: \task, name: \scaleKalei, act: 1
        ),
    ],
    99: [
        (
            info: "FIN",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Remove all, particles OFF, tasks stop",
            message: \physics, params: [particles: 0]
        ),
        (message: \task, name: \flyingSynths, act: 0),
        (message: \task, name: \particlesMachine, act: 0),
        (message: \task, name: \pulseXPad, act: 0),
        (message: \task, name: \scaleKalei, act: 0),
    ]
);

~sequence.tasks = (
    pulseXPad: Task({
        var groups, current, node, attack, scale;
        attack = [{ [5, 20, 120].choose }, { [20, 40, 80].choose }];
        groups = [
            (
                synth: \sr__e__pulse,
                modulators: (
                    azimuth: (outbus: 4,
                        name: \sr__k__lfnoise1,
                        params: [\freq, 0.05, \mul, 1pi]
                    ),
                    distance: (outbus: 5,
                        name: \sr__k__lfnoise1,
                        params: [\freq, 0.01, \mul, 0.01, \add, 1.36]
                    ),
                    velocity: (outbus: 6,
                        name: \sr__k__lfnoise1,
                        params: [\freq, 0.05, \mul, 0.2, \add, 0.8]
                    ),
                    az: (outbus: 7,
                        name: \sr__k__stepnoise,
                        params: [\freq, 0.13, \mul, 0.1, \add, 0.65]
                    )
                )
            ),
            (
                synth: \sr__e__dempad,
                modulators: (
                    azimuth: (outbus: 4,
                        name: \sr__k__lfnoise1,
                        params: [\freq, 0.05, \mul, 1pi]
                    ),
                    distance: (outbus: 5,
                        name: \sr__k__lfnoise1,
                        params: [\freq, 0.01, \mul, 0.01, \add, 1.36]
                    ),
                    velocity: (outbus: 6,
                        name: \sr__k__stepnoise,
                        params: [\freq, 0.05, \mul, 0.1, \add, 0.9]
                    ),
                    offset: (outbus: 7,
                        name: \sr__k__stepnoise,
                        params: [\freq, 0.3, \mul, 3.5, \add, 36.5]
                    )
                )
            )
        ];
        inf.do { |i|
            if (current.isNil.not) {
                ~groupFree.(node, release:30.rand)
            };
            current = groups[i % groups.size];
            scale = ~sequence.scales.choose.bufnum;
            node = ~groupInit.(
                synth:current[\synth],
                bufnum:scale,
                params:[
                    \att, attack[i % groups.size].value(),
                    \distance, 2.sqrt * 0.5
                ]
            );
            // s.sendMsg("/n_set", node, \distance, 2.sqrt * 0.5);
            if (current.keys.includes(\modulators)) {
                current.modulators.keysValuesDo { |param, modulator|
                    s.sendBundle(0.01,
                        [
                            "/s_new", modulator.name, s.nextNodeID, 0, node,
                            \outbus, modulator.outbus
                        ]
                        ++ modulator.params,
                        ["/n_map", node, param, modulator.outbus],
                    )
                }
            };
            rrand(120, 480).wait;
        }
    }),

    flyingSynths: Task({
        var next;
        var go = {
            var x, y, z, synth, go;
            #x, y, z = { rrand(~worldSize, ~worldSize * ([0.1, 0.9].choose)) } ! 3;
            synth = [\sr__e__lowe, \sr__e__neural, \sr__e__pulse].choose;
            ~sendParticle.(
                particle: (
                    x:x, y:z, z:z,
                    age: rrand(5, 10),
                    mass: rrand(0.1, 0.2),
                    spring: [1, 0].wchoose([0.7, 0.3])
                ),
                synth: (
                    name: synth,
                    params: [
                        \att, 1.5, \rel, 3,
                        \bufnum, ~sequence.scales.choose.bufnum
                    ]
                )
            );
        };
        loop {
            go.();
            if (0.3.coin.booleanValue) {
                (5 + rand2(1)).wait;
                go.();
            };
            next = [20, 60, 80].choose;
            (next + rand2(next * 0.25)).wait;
        }
    }),

    particlesMachine: Task({
        var key, next, cnt=0;
        var particleParams = [ // list of acceptable configurations
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.3, \partAgeThresh, 1.67, \partInitAccel, 30 ],
            [                           \partSigmoidRatio, 0.7, \partAgeThresh, 0.20, \partInitAccel, 30 ],
            [\partSynth, \sr__e__melo,  \partSigmoidRatio, 0.7, \partAgeThresh, 0.78, \partInitAccel, 2.0],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.7, \partAgeThresh, 3.0,  \partInitAccel, 8.0],
            [\partSynth, \sr__e__pulse, \partSigmoidRatio, 0.2, \partAgeThresh, 1.03, \partInitAccel, 20 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.2, \partAgeThresh, 1.67, \partInitAccel, 1.0],
        ];
        loop {
            next = 20 + rand2(4);
            ~sendMessage.(\physics, [\particles, 1]);
            ~sendMessage.(\physics, particleParams[cnt % particleParams.size]);
            rrand(next * 0.25, next).wait;
            ~sendMessage.(\physics, [\particles, 0]);
            cnt = cnt + 1;
            next.wait;
        }
    }),

    scaleKalei: Task({
        var changeScale, changeOffset;
        var dictObjSeq, msetObjSeq;
        var key, next, scaleName;

        // Sequence rules (Markov set).
        dictObjSeq = (
            // [number of repeats] (to choose from) -> [timelapse] (current moment and age)
            0: [(4..12), (1..6)], // short
            1: [[1, 3, 5, 7, 9], ({rrand(5, 40)} ! 10)], // average
            2: [[1, 2], ({rrand(180, 360)} ! 10)] // long (repeat)
        );
        msetObjSeq = MarkovSetN([], 2);
        dictObjSeq.keysValuesDo{|k, v| msetObjSeq[k] = v[1]};

        loop {
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.3, 0.6, 0.1]);
            next = msetObjSeq.next(key);
            next = (next + rand2(next * 0.25));
            if (next > 120) {
                changeScale = true;
                changeOffset = 0.5.coin;
            } {
                changeScale = 0.5.coin;
                changeOffset = true;
            };

            if (changeScale) {
                currentScale.free;
                scaleName = validScales.choose;
                currentScale = Buffer.sendCollection(~scsynth, scaleName);
            };
            if (changeOffset) {
                currentOffset = rrand(24, 60);
            };
            postf("* currently applied: %, offset %, change in %\n",
                scaleName, currentOffset, next.round(0.0001)
            );
            s.sendMsg("/n_set", nil, \bufnum, currentScale.bufnum, \offset, currentOffset);

            next.wait;
        }
    }),

);
)