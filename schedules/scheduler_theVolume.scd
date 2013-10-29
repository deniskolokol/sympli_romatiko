(
var win, info, buttons, stCurrNum, stCurrInfo, stNextNum, stNextInfo, timeLabel; // interface
var shade, count=0, animate=false; // schedule animation
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime.
var key, current, next, syn, obj, age, mass;
var synths=Dictionary.new; // temp dictionary of the synths symbolic IDs vs. server Nodes
var sGroupId, receiverNet;
var thePiece=Dictionary.new; // Sequence of scheduled tasks.
var getKey, processEvents, displayEventInfo, convertTime;
var sendObjCreate, sendSNew, sendParam, groupNew, groupFree;
var task; // Tasks dictionary
var parmDir = Dictionary.new; // Global params of the piece dictionary.

// WARNING! Specific for the current piece!
// Read left channel only to feed to TGrains!
var introBuff = Buffer.readChannel(s,
    PathName("~/Music/Sympli_Romatiko/solo/Audio/DRLATPOL.WAV").fullPath,
    channels: [0]);
var buffList = List.new;
[ // Fill buffList.
    "~/Music/Sympli_Romatiko/solo/Audio/bboxbeay2.wav",
    "~/Music/Sympli_Romatiko/solo/Audio/17boxloop.wav",
    "~/Music/Sympli_Romatiko/solo/Audio/BBOX75.WAV",
    "~/Music/Sympli_Romatiko/solo/Audio/BBOX90.WAV",
    "~/Music/Sympli_Romatiko/solo/Audio/loop_clean.wav"
].do { |f|
    buffList.add(Buffer.readChannel(s, PathName(f).fullPath, channels: [0]));
};

// Initial settings.
// Net Address and Port of the Receiver.
receiverNet = NetAddr.new("127.0.0.1", 57120);
// Group for synths.
sGroupId = s.nextNodeID;
s.sendMsg("/g_new", sGroupId);
// Sequence rules (Markov set).
dictObjSeq = (
    // [number of repeats] (to choose from) -> [timelapse] (current moment and age)
    0: [(4..12), (1..6)], // short
    1: [[1, 3, 5, 7, 9], ({rrand(5, 40)} ! 10)], // average
    2: [[1, 2], ({rrand(30, 120)} ! 10)] // long (repeat)
);
msetObjSeq = MarkovSetN([], 2);
dictObjSeq.keysValuesDo{|k, v| msetObjSeq[k] = v[1]};

thePiece = (
    0: [
        (
            info: "Initial settings",
            message: \worldpar,
            params: [
                // Audio settings.
                audioIn: true, inbus: 20, fieldDepth: 5, confSurround: "Ambisonic4", master: 1,
                // Physics parameters.
                worldGrav: 0.98, worldMaxVel: 30, worldDamp: 0.01, starMass: 120, heavy: 5, initMass: 8,
                springStiff: 1, springDamp: 0.1, springLen: 2,
                repulsiveForce: 5, objAttract: true, // WARNING! switch it off when the skeleton enters!
                // Particles.
                particles: 0, partSigmoidRatio: 0.7, partFreq: 0.5, partAgeThresh: 80,
                partInitAccel: 3, partGuide: "object", partSynth: \sr__e__analog,
                // General.
                visualize: 1
            ]
        ),
        (
            info: "Remove all before start",
            message: \worldact, action: \remove, objects: \all
        )
    ],
    1: [
        (
            info: "Intro, no objects, only .kr buses",
            message: \g_new,
            id: \intro_bundle,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", \sr__s__ambisonic4, \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \inbus, 3, // getting signal from synth
                    \outbus, 0, // to main output
                    \azimuth, 0],
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \outbus, 3, // feeding into spatilizer
                    \velocity, 0.88, \att, 15, \amp, 0.08],
                ["/s_new", \sr__k__lfnoise2, \next_node_id, 0, \group_id, \freq, 0.5, \mul, 1pi, \outbus, 0],
                ["/n_map", \group_id, \azimuth, 0],
                // TO-DO: Somehow this works really bad! No real movement, plus very loud
                // Find proper distance! Properly set azimuth!
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, \freq, 0.2,
                    \mul, (1.5 - 0.6) * 0.5, \add, 1.5 - ((1.5 - 0.6) * 0.5), // range 0.3..0.7
                    \outbus, 1],
                // ["/s_new", \sr__k__sin, \next_node_id, 0, \group_id, \freq, 0.2,
                //     \mul, ((32.sqrt - 0.5)/2), \add, (32.sqrt - ((32.sqrt - 0.5)/2)),
                // \mod_mul, ((0.2 - 0.02)/2), \mod_add, 0.2 - ((0.2 - 0.02)/2), \outbus, 1],
                ["/n_map", \group_id, \distance, 1],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 2],
                ["/n_map", \group_id, \velocity, 2],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 3],
                ["/n_map", \group_id, \velocity, 3],
                ["/s_new", \sr__k__sin, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 4],
                ["/n_map", \group_id, \az, 4]
            ]
        )
    ],
    5: [
        (
            info: "Particles ON!",
            message: \worldpar, params: [particles: 1, partGuide: "object"]
        ),
        //
        // TO-DO: Experiment with particles density and age to find a proper balance
        // of dynamics with the rest - at least in the beginning
        //
        (
            info: "Schedule particles",
            message: \task, name: \randomParticles, act: 1
        ),
    ],
    7: [
        (
            info: "Schedule Intro",
            message: \task, name: \intro, act: 1
        )
    ],
    10: [
        (
            info: "Schedule light __pulse & __ringz",
            message: \task, name: \lightPulseRingz, act: 1
        ),
    ],
    20: [
        (
            info: "Remove mutual attraction",
            message: \worldpar, params: [objAttract: false]
        ),
        (
            info: "Schedule __analog cutoff= -1",
            message: \task, name: \sporadicAnalogCutoff, act: 1
        )
    ],
    30: [
        ( // Remove all objects.
            info: "SCI-FI",
            message: \worldact, action: \remove, objects: \all
        ),
        ( // Stop schedule with occasional light \sr__e__pulse and \sr_rings
            info: "Remove all, stop sched, particles OFF",
            message: \task, name: \lightPulseRingz, act: 0
        ),
        ( // Stop schedule with sporadic \sr__e__analog, cutoff= -1
            message: \task, name: \sporadicAnalogCutoff, act: 0
        ),
        ( // Clear \intro schedule
            message: \task, name: \intro, act: 0
        ),
        ( // Stop occasional particles
            message: \task, name: \randomParticles, act: 0
        ),
        ( // switch particles OFF
            message: \worldpar, params: [particles: 0]
        ),
        ( // remove intro group from server
            message: \g_free, id: \intro_bundle, params: [\release, 10]
        ),
        (
            info: "Ave __pulse, 2 heavy __analog default cutoff",
            message: \worldobj,
            synth: (name: \sr__e__pulse, params: [\att, 1, \rel, 10]),
            object: (type: "a RedBoid", age: rrand(80, 150), mass: 4),
        ),
        // Start 2 heavy sr__e__analog w/default cutoff.

        // TO-DO:
        // - 2 heavy sr__e__analog should appear in a particular place (calculate coordinates) and stay for some time
        //   (to give it a time to accumulate a pressure before transition)
        // - they can also appear one after another (add one more event)
        //

        (
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 1.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9),
        ),
        (
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        )
    ],
    35: [
        (
            info: "Remove all",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "2 heavy __analog default cutoff",
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 1.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 10),
        ),
        (
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 10)
        ),
        (
            info: "Light __lowe ~heaviness",
            message: \worldobj,
            synth: (name: \sr__e__lowe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            object: (type: "a RedBoid", age: inf, mass: 4)
        ),
        (
            info: "Schedule sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 1
        ),
    ],
    40: [
        (
            info: "HEAVY",
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 1.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 10),
        ),
        (
            info: "2 more heavy __analog default and -1 cutoff",
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 10, \cutoff, -1]),
            object: (type: "a RedObject", age: inf, mass: 10)
        ),
        (
            info: "Stop sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 0
        ),
    ],
    45: [
        ( // Remove all objects.
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Leave 2 ave __analog ~Fade-out",
            message: \worldobj,
            synth: ( name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 10)
        ),
        (
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 10)
        ),
        (
            info: "Heavy __probe ~X-fade",
            message: \worldobj,
            synth: (name: \sr__e__probe, params: [\att, 1.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 8),
        )
    ],
    50: [
        (
            info: "AIRY",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Remove all",
            message: \worldobj,
            synth: (name: \sr__e__probe, params: [\att, 1.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 11),
        ),
        (
            info: "2 heavy __probe",
            message: \worldobj,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 11)
        )
    ],
    55: [
        (
            info: "Schedule sporadic __cmb & __melo",
            message: \task, name: \sporadicCMB, act: 1
        ),
        (
            message: \task, name: \sporadicMelo, act: 1
        )
    ],
    57: [
        ( // Remove all objects.
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Leave one __probe",
            message: \worldobj,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
        (
            info: "Heavy __cmb ~X-fade",
            message: \worldobj,
            synth: (name: \sr__e__cmb, params: [\att, 1.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 8),
        )
    ],
    60: [
        ( // Remove all objects.
            message: \worldact, action: \remove, objects: \all
        ),
        ( // Start 2 heavy \sr__e__cmb.
            message: \worldobj,
            synth: (name: \sr__e__cmb, params: [\att, 1.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9),
        ),
        (
            info: "Add another heavy __cmb",
            message: \worldobj,
            synth: (name: \sr__e__cmb, params: [\att, 3 + 2.0.rand2, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        )
    ],
    65: [
        (
            info: "Schedule light __pulse and __rings",
            message: \task, name: \lightPulseRingz, act: 1
        ),
    ],
    70: [
        (
            info: "ELECTRO SOLO",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "2 heavy ringz",
            message: \worldobj,
            synth: (name: \sr__e__ringz, params: [\att, 10.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
        (
            message: \worldobj,
            synth: (name: \sr__e__ringz, params: [\att, 10.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
    ],
    75: [
        (
            info: "Remove all",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Schedule granular waves",
            message: \task, name: \granWave, act: 1
        ),
        (
            info: "Ave __lowe",
            message: \worldobj,
            synth: (name: \sr__e__lowe, params: [\att, 10.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 6)
        ),
    ],
    78: [
        (
            info: "Add ave __noisy",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 10.0.rand, \rel, 10]),
            object: (type: "a RedBoid", age: inf, mass: 7)
        ),
    ],
    80: [
        ( // Remove all objects.
            info: "GROOVE_1",
            message: \worldact, action: \remove, objects: \all
        ),
        ( // Stop schedule with sporadic \sr__e__cmb
            info: "Remove all, stop sched",
            message: \task, name: \sporadicCMB, act: 0
        ),
        ( // Stop schedule with sporadic \sr__e__melo
            message: \task, name: \sporadicMelo, act: 0
        ),
        ( // Stop schedule lightPulseRingz
            info: "Remove all, stop sched",
            message: \task, name: \lightPulseRingz, act: 0
        ),
        ( // Stop percussive granWave.
            message: \task, name: \granWave, act: 0
        ),
        //
        // TO-DO:
        // - add 2 __melo here, re-write them so that their \amp depend on velocity
        //   via some sigmoid function: in this way moving hands slowly would seem like
        //   moving a wind around, when it's more energetic, the winds start "singing"
        //
        (
            info: "2 heavy __noisy",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
        (
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),

    ],
    85: [
        (
            info: "BREAK GROOVE",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Leave one __noisy",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
        (
            info: "Start heavy __entro",
            message: \worldobj,
            synth: (name: \sr__e__entro),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),

    ],
    90: [
        (
            info: "GROOVE_2",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Leave one __noisy",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 8)
        ),
        (
            info: "Add heavy __radio",
            message: \worldobj,
            synth: (name: \sr__e__radio, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
    ],
    95: [
        ( // Remove all objects.
            info: "FADE AWAY",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "2 heavy __noisy",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
        (
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
        (
            info: "Particles ON",
            message: \worldpar,
            params: [
                particles: 1, partSigmoidRatio: 0.7, partFreq: 0.02, partAgeThresh: 80,
                partInitAccel: 3, partGuide: "object", partSynth: \sr__e__analog,
            ]
        ),
    ],
    99: [
        (
            info: "FIN",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Remove all, particles OFF",
            message: \worldpar, params: [particles: 0]
        ),
    ]
);

// Store global params of the piece in a dictionary.
parmDir.putPairs(thePiece[0][0][\params]);

// Tasks dictionary.
task = (
    intro: Task({
        var key, next, syn, obj, age;
        loop {
            // Pick up a key and the number of iterations randomly.
            // Average sequences are the most probable, long are the least probable.
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 10, 1].normalizeSum);

            dictObjSeq[key.asInteger][0].choose.do{ |i|
                next = msetObjSeq.next(key);
                syn = [\sr__e__humm, \sr__e__radio][i % 2];

                // Age spans over to the next object birth - no gaps!
                // The lighter objects the faster they die, but their demography is denser.
                age = next * (1 + (1/(next.pow(0.33))));

                // Mass is: sqrt propotion to life cycle for \sr__e__ringz; constant for \sr__e__pulse.
                mass = if (syn == \sr__e__pulse) {3} {next.sqrt.clip(3, 6)};

                // Send object creation message.
                sendObjCreate.(
                    (
                        message: \worldobj,
                        synth: (name: syn),
                        object: (age: age, mass: mass, type: "a RedBoid")
                    )
                );
                next.wait;
            };
            0.001.wait;
        }
    }),
    randomParticles: Task({
        var key, next;
        var particleParams = [ // list of acceptable configurations
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.3, \partAgeThresh, 40, \partInitAccel, 10 ],
            [\partSynth, \sr__e__cmb,   \partSigmoidRatio, 0.8, \partAgeThresh, 5, \partInitAccel, 2.6],
            [                           \partSigmoidRatio, 0.4, \partAgeThresh, 80,  \partInitAccel, 30 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.7, \partAgeThresh, 5,  \partInitAccel, 8.0],
            [                           \partSigmoidRatio, 0.2, \partAgeThresh, 100,\partInitAccel, 0.1],
            [\partSynth, \sr__e__melo,  \partSigmoidRatio, 0.7, \partAgeThresh, 47, \partInitAccel, 2.0],
            [\partSynth, \sr__e__pulse, \partSigmoidRatio, 0.2, \partAgeThresh, 2,  \partInitAccel, 20 ]
        ];
        inf.do { |i|
            // Send object creation message.
            2.do { |j|
                key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.3, 0.6, 0.1]);
                next = msetObjSeq.next(key);
                next = (next + rand2(next * 0.25));
                sendParam.(
                    (
                        message: \worldpar,
                        params: [partFreq: next.linlin(20, 5, 0.1, 1)] ++ particleParams[i % particleParams.size]
                    )
                );
                next.wait;
            };
            0.01.wait;
        }
    }),
    sporadicAnalogCutoff: Task({
        var next = 8.30;
        loop {
            // Send object creation message.
            sendObjCreate.(
                (
                    message: \worldobj,
                    synth: (name: \sr__e__analog, params: [\cutoff, -1]),
                    object: (age: rrand(1.70, 2.30), mass: 8, type: "a RedObject", objectPos: [300.rand, 300.rand, 300.rand])
                )
            );
            (next + rand2(next * 0.25)).wait;
        }
    }),
    sporadicPulse: Task({
        var next=20;
        loop {
            // Send object creation message.
            sendObjCreate.(
                (
                    message: \worldobj,
                    synth: (name: \sr__e__pulse, params: [\att, 1.5, \rel, 3]),
                    object: (age: rrand(1.7, 3.0), mass: 8, type: "a RedBoid")
                )
            );
            (next + rand2(next * 0.25)).wait;
        }
    }),
    sporadicCMB: Task({
        var age, next=30;
        loop {
            // Send object creation message.
            sendObjCreate.(
                (
                    message: \worldobj,
                    synth: (name: \sr__e__cmb, params: [\att, 1.5, \rel, 3]),
                    object: (age: rrand(2, 5), mass: 6, type: "a RedObject")
                )
            );
            (next + rand2(next * 0.25)).wait;
        }
    }),
    sporadicMelo: Task({
        var age, next=20;
        loop {
            (next + rand2(next * 0.25)).wait;
            // Send object creation message.
            sendObjCreate.(
                (
                    message: \worldobj,
                    synth: (name: \sr__e__melo, params: [\att, 1.5, \rel, 3]),
                    object: (age: rrand(5, 10), mass: 4, type: "a RedObject")
                )
            );
            ((next + rand2(next * 0.25))/2).wait;
        }
    }),
    granWave: Task({
        var buff, age, next=20;
        var introSynths = [\sr__g__loop, \sr__g__slic, \sr__g__drone, \sr__g__reg, \sr__g__gust];
        // Probablity of choosing a particular synth decreases towards the end of the list.
        var introSynthProb = Array.fill(introSynths.size, {exprand(0.01, 1.00)}).normalizeSum.sort.reverse;

        inf.do{ |j|
            // Start fade-in synth before the wave.
            age = rrand(5, 8);
            sendObjCreate.(
                (
                    message: \worldobj,
                    object: (age: age, mass: 5, type: "a RedBoid"),
                    synth: (name: introSynths.wchoose(introSynthProb),
                        params: [\att, 4, \rel, 3.0.rand, \bufnum, introBuff.bufnum]
                    )
                )
            );
            // Wait attack time (will overlap with wave a little).
            4.wait;
            // Alternate between samples from buffList.
            buff = buffList[(j % buffList.size).asInt];
            {
                200.do{ arg i;
                    var timeprop = (i / 199.0) ** 3;
                    sendSNew.(
                        (synth: (
                            name: \sr__u__grain,
                            params: [\bufnum, buff.bufnum, \busnum, parmDir[\inbus],
                                \rate, 1 + timeprop.rand2.pow(2), \pos, rrand(0.0, timeprop), \amp, exprand(0.05, 1.00)]
                            )
                        ),
                    );
                    rrand((timeprop * 0.1).max(0.01),timeprop*0.4).wait
                };
            }.fork;
            rrand(12, 30).wait;
        }
        }
    )
);

// Send synth to server.
sendSNew = { |data|
    var nodeID = s.nextNodeID;

    try { // Ignore the case when doneAction = 2.
        synths.put(data[\synth][\id], nodeID);
    };

    s.listSendMsg(["/s_new", data[\synth][\name],
        nodeID, 0, sGroupId] ++ data[\synth].atFail(\params, {[]}));
};


// Send bundle to server, places everything mentioned to the top level group.
groupNew = { |data, time=0.1|
    var nodeID = s.nextNodeID, messages = data[\params];

    messages.do{ |l, i|
        l.do{ |m, j| // replace keywords with node ids
            m.switch(
                \group_id, { messages[i][j] = nodeID},
                \next_node_id, {messages[i][j] = s.nextNodeID}
            )
        }
    };
    messages = [["/g_new", nodeID]] ++ messages; // add group creation
    s.listSendBundle(time, messages);

    synths.put(data[\id], nodeID);
};


// Release all synths from group, wait until released, then remove group node from server.
groupFree = { |data|
    var nodeID=synths.at(data[\id]);
    var release, params=();

    try {params.putPairs(data.atFail(\params, {[]}))};
    release = params.atFail(\release, {2});
    release.postln;

    Routine({
        [
            ["/n_set", nodeID, \rel, release, \gate, 0],
            ["/n_free", nodeID]
        ].do { |l|
            s.listSendMsg(l);
            release.wait;
        }
    }).play;

    synths.removeAt(data[\id]);
};


// Send object creation message to the World.
sendObjCreate = { |data|
    var pos;
    pos = data[\object].atFail(\pos, {nil});

    // Check if position given correctly.
    if (pos.isNil || (pos.class != Array)) {pos = [0, 0, 0]};

    // It might also be only X & Y or even X given, in that case the rest must be 0.
    3.do{|i| try {pos[i] = pos[i].asFloat} { |err| err.postln; pos.add(0)}};

    // Send object creation message.
    receiverNet.sendBundle(0.01,
        [
            "/worldobj",
            data[\synth][\name], data[\object][\type], data[\object][\age],
            pos[0], pos[1], pos[2], data[\object][\mass]
        ]
        ++ data[\synth].atFail(\params, {[]})
    )
};


// Send parameter to the World.
sendParam = { |data|
    if (data.atFail(\params, {[]}).size > 1) {
        data[\params].pairsDo { |n, v| receiverNet.sendMsg("/worldpar", n, v)};
    }
};


// Obtain the key next/prev to current.
getKey = { |current=nil, next=1|
    var k, c;
    k = thePiece.keys.asArray.asInteger.sort;
    c = k.indexOf(current) ? -1;
    k[c + next] ? k[0]; // Go back to beginning if nothing more left.
};


// Convert all event's [\info] keys into info string.
displayEventInfo = { |k=nil, lim=50|
    var infoStr, val, sF;
    val = thePiece.atFail(k, {[]});
    sF = { |l| format(" %\n", if (l.size <= lim) {l} {l[..lim] ++ "..."})};
    infoStr = all{: sF.(l[\info].asString), l <- val, l.keys.includes(\info)};
    "".catList(infoStr)
};


// Convert time to readable format.
convertTime = { |timecode|
    var sec=0, min=0, minstring="00", secstring="00";
    if(timecode >= 60) {
        min = trunc(timecode / 60);
        sec = round(timecode % 60, 0.1);
    } {
        sec = round(timecode,0.1)
    };
    if (min < 10) {minstring = "0"++min.asString} {minstring = min.asString};
    if (sec < 10) {secstring = "0"++sec.asString} {secstring = sec.asString};
    format("%:%", minstring, secstring)
};


// Process specific key from thePiece.
processEvents = { |k=nil|
    var val = thePiece.atFail(k, {[]});
    val.do { |d, l|
        d[\message].switch(
            \task, { // Launch/stop a task.
                try {
                    if (d[\act].booleanValue) {task[d[\name]].play()} {task[d[\name]].stop}
                } { |err|
                    postf("Error while trying to switch task % on or off:\n%\n", d[\name], err);
                };
            },
            \worldobj, {sendObjCreate.(d)}, // Single object creation.
            \worldpar, {sendParam.(d)}, // Send World parameter(s).
            \worldact, { // Send an act signal to the World.
                if (d.atFail(\action, {\}) != \) {
                    receiverNet.sendMsg("/worldact", d[\action], d[\objects]);
                };
            },
            \s_new, {sendSNew.(d)}, // Send a new synth message directly to the server.
            \n_set, { // Send a 'set params' message directly to the server.
                s.listSendMsg(["/n_set", synths.at(d[\synth][\id])] ++ d[\synth].atFail(\params, {[]}))
            },
            \g_new, {groupNew.(d)}, // Send bundle to the server, place everything into the group.
            \g_free, {groupFree.(d)}, // Release group.
        )
    }
};


// GUI.
//
win = Window("sequencing and scheduling", Rect(580, 900, 600, 160))
.acceptsMouseOver_(true);
win.view.decorator = FlowLayout(win.view.bounds);

info = CompositeView(win, 500@150);
info.decorator = FlowLayout(info.bounds);
stCurrNum = StaticText(info, 70@60).font_(Font("Monaco", 32)).background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stCurrInfo = StaticText(info, 410@60).font_(Font("Monaco", 12)).background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stNextNum = StaticText(info, 70@90).font_(Font("Monaco", 32)).background_(Color.grey(0.4)).stringColor_(Color.white);
stNextInfo = StaticText(info, 410@90).font_(Font("Monaco", 14)).background_(Color.grey(0.4)).stringColor_(Color.white);

buttons = CompositeView(win, 80@150);
buttons.decorator = FlowLayout(buttons.bounds);
Button(buttons, 70@45).states_([[">>", Color.black, Color.white]])
.action_({ |bt|
    if (animate.not) {animate = true}; // bring it on!
    stCurrNum.string = current = getKey.(current);
    stCurrInfo.string = displayEventInfo.(current);
    stNextNum.string = next = getKey.(current, 1);
    stNextInfo.string = displayEventInfo.(next, 50);

    processEvents.(current);
});

Button(buttons, 70@45).states_([["<<", Color.black, Color.white]])
.action_({ |bt|
    stCurrNum.string = current = getKey.(current, -1);
    stCurrInfo.string = displayEventInfo.(current);
    stNextNum.string = next = getKey.(current, 1);
    stNextInfo.string = displayEventInfo.(next);

    processEvents.(current);
});

timeLabel = StaticText(buttons, 70@60).font_(Font("Monaco", 14));

win.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    //[char, modifiers, unicode, keycode].postln;
    case
    {keycode == 6} { // Z - info
        if( [0, 256].includes(modifiers), {
            postf("window: left %, top %, width %, height %\n",
                win.bounds.left, win.bounds.top, win.bounds.width, win.bounds.height);
        });
    }
};

{ // blinking "next event" info.
    while {win.isClosed.not} {
        if (animate) {
            count = count + 1;
            shade = (count % 8) * 0.1;
            stNextNum.background = Color.grey(shade);
            stNextInfo.background = Color.grey(shade);
            timeLabel.string = convertTime.(count / 10);
        };
        win.refresh;
        0.1.wait;
    }
}.fork(AppClock);

win.front;

CmdPeriod.doOnce({
    // Free buffers.
    introBuff.free;
    buffList.do { |buff| buff.free};

    win.close;
});
)