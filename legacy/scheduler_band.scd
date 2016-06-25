// TO-DO:
// - INTRO:
// -- think of voices like radio talks
// - fix sending scales, but leave what is now, too ('cause it's cool!)

(
var thePiece; // main dictionary with the sequence of scheduled tasks
var parmDir = Dictionary.new; // Global params of the piece dictionary.
var sGroupId; // root group
var receiverNet; // communication
var task; // tasks dictionary
var guideBuff, samples, scales, voices; // buffers (sound files and scales)
var synths=Dictionary.new; // temp dictionary of the synths symbolic IDs vs. server Nodes
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime
var key, current, next, syn, obj, age, mass; // object's properties
var win, info, buttons, stCurrNum, stCurrInfo, stNextNum, stNextInfo, timeLabel, // interface
    btPrev, btNext;
var shade, count=0, animate=false; // schedule animation
var getKey, displayEventInfo, convertTime; // helper functions
var processEvents, groupNew, groupFree, taskPlay,
    sendObjCreate, sendSNew, sendParam, sendAct; // acting functions
var midiServerVolume, midiNext, midiPrev, midiClean;
var surround = "Ambisonic2";

// INITIAL
//
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

// fill buff with sample connected to guide object
guideBuff = Buffer.readChannel(~scsynth,
    PathName("~/Music/Sympli_Romatiko/samples/drumguide.wav").fullPath,
    channels: [0]);

samples = List.new; // fill samples
[
    "~/Music/Sympli_Romatiko/samples/drumloop00.wav",
    "~/Music/Sympli_Romatiko/samples/drumloop01.wav",
    "~/Music/Sympli_Romatiko/samples/drumloop02.wav",
    "~/Music/Sympli_Romatiko/samples/drumloop03.wav",
    "~/Music/Sympli_Romatiko/samples/drumloop04.wav"
].do { |f|
    samples.add(Buffer.readChannel(~scsynth, PathName(f).fullPath, channels: [0]));
};

voices = List.new; // fill samples
[
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
    "~/Music/Sympli_Romatiko/samples/narration1.wav",
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
    "~/Music/Sympli_Romatiko/samples/narration3.wav",
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
    "~/Music/Sympli_Romatiko/samples/narration5.wav",
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
    "~/Music/Sympli_Romatiko/samples/narration7.wav",
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
    "~/Music/Sympli_Romatiko/samples/narration9.wav",
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
    "~/Music/Sympli_Romatiko/samples/narration11.wav",
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
    "~/Music/Sympli_Romatiko/samples/narration13.wav",
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
    "~/Music/Sympli_Romatiko/samples/narration15.wav",
    "~/Music/Sympli_Romatiko/samples/marcin00.wav",
].do { |f|
    voices.add(Buffer.readChannel(~scsynth, PathName(f).fullPath, channels: [0]));
};

scales = List.new; // fill scales
[
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 1, 3, 7, 8], // the rest are specific to thePiece's parts
    FloatArray[0, 2, 4, 6, 9],
    FloatArray[0, 3, 6, 9, 11],
    FloatArray[0, 1, 3, 7, 10],
].do { |a| scales.add(Buffer.sendCollection(~scsynth, a)) };

thePiece = (
    0: [
        (
            info: "Initial settings",
            message: \worldpar,
            params: [
                // Audio settings.
                audioIn: false, inbus: 20, fieldDepth: 5, confSurround: surround, master: 1,
                // Physics parameters.
                worldGrav: 0.98, worldMaxVel: 30, worldDamp: 0.01, starMass: 50, heavy: 5, initMass: 8,
                springStiff: 2, springDamp: 0.01, springLen: 0.1,
                repulsiveForce: 5, objAttract: true, worldForces: false,
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
    // 1: [
    //     (
    //         info: "INTRO, no objects, only .kr buses",
    //         message: \g_new,
    //         id: \intro_bundle,
    //         params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
    //             ["/s_new", "sr__s__" ++ surround.toLower, \next_node_id, 1, \group_id, // add spatializer to new group's tail
    //                 \inbus, 12, // getting signal from synth
    //             \outbus, 0], // to main output
    //             ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
    //                 \outbus, 12, // feeding into spatilizer
    //             \velocity, 0.5, \att, 30],
    //             ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.5, \mul, 1pi, \outbus, 0],
    //             ["/n_map", \group_id, \azimuth, 0],
    //             ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08,
    //                 \mul, (1 - 0.2) * 0.5, \add, 1 - ((1 - 0.2) * 0.5), // range 0.2..1
    //             \outbus, 1],
    //             ["/n_map", \group_id, \distance, 1],
    //             ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.2, \add, 0.6, \outbus, 2],
    //             ["/n_map", \group_id, \velocity, 2],
    //             ["/s_new", \sr__k__sin, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 3],
    //             ["/n_map", \group_id, \az, 3]
    //         ]
    //     )
    // ],
    // 5: [
    //     (
    //         info: "INTRO: Particles",
    //         message: \worldpar, params: [particles: 1, partGuide: "object"]
    //     ),
    //     (
    //         message: \task, name: \randomParticles, act: 1
    //     ),
    // ],
    // 10: [
    //     (
    //         info: "INTRO: objects",
    //         message: \task, name: \intro, act: 1
    //     )
    // ],
    // 11: [
    //     (
    //         info: "INTRO: voices",
    //         message: \task, name: \voices, act: 1
    //     ),
    //     (
    //         message: \worldpar, params: [audioIn: true]
    //     )
    // ],
    // 20: [
    //     (
    //         info: "INTRO: __analog cutoff= -1",
    //         message: \task, name: \sporadicAnalogCutoff, act: 1
    //     ),
    //     (
    //         info: "Remove mutual attraction",
    //         message: \worldpar, params: [objAttract: false]
    //     ),
    //     (
    //         info: "Restore star mass",
    //         message: \worldpar,
    //         params: [starMass: 120]
    //     ),
    //
    // ],
    // 22: [
    //     (
    //         info: "INTRO: stop voices",
    //         message: \task, name: \voices, act: 0
    //     ),
    //     (
    //         message: \worldpar, params: [audioIn: true]
    //     )
    // ],
    30: [
        ( // Remove all objects.
            info: "SCI-FI",
            message: \worldact, action: \remove, objects: \all
        ),
        // ( // Stop schedule with sporadic \sr__e__analog, cutoff= -1
        //     info: "Remove all, stop sched, particles OFF",
        //     message: \task, name: \sporadicAnalogCutoff, act: 0
        // ),
        // ( // Clear \intro schedule
        //     message: \task, name: \intro, act: 0
        // ),
        // ( // Stop occasional particles
        //     message: \task, name: \randomParticles, act: 0
        // ),
        // ( // switch particles OFF
        //     message: \worldpar, params: [particles: 0]
        // ),
        // ( // remove intro group from server
        //     message: \g_free, id: \intro_bundle, params: [\release, 80]
        // ),
        (
            info: "Ave __pulse, 2 heavy __analog",
            message: \worldobj,
            synth: (name: \sr__e__pulse, params: [\att, 40, \rel, 10]),
            object: (type: "a RedBoid", age: rrand(80, 150), mass: 5, pos: [350, 120, 750]),
        ),
        // Start 2 heavy sr__e__analog w/default cutoff and long attack
        (
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 40, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9, pos: [300, 300, 250]),
        ),
        (
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 40, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9, pos: [470, 300, 250])
        )
    ],
    31: [
        (
            info: "SCI-FI: Activate world forces",
            message: \worldpar, params: [worldForces: true]
        ),
        (
            info: "Schedule sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 1
        ),
        // "Shrink" the audio-space
        (
            message: \worldpar, params: [fieldDepth: 3]
        ),
        (
            info: "Light __lowe ~heaviness",
            message: \worldobj,
            synth: (name: \sr__e__lowe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            object: (type: "a RedBoid", age: inf, mass: 4)
        ),
    ],
    35: [
        (
            info: "SCI-FI: Remove all",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Schedule sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 1
        ),
        (
            info: "heavy __analog - TAP twice for 2!",
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 1.0.rand, \rel, 20]),
            object: (type: "a RedObject", age: inf, mass: 10),
        ),
    ],
    36: [
        (
            info: "SCI-FI: heavy __analog 2",
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 20]),
            object: (type: "a RedObject", age: inf, mass: 10)
        ),
    ],
    40: [
        (
            info: "HEAVY __analog default - TAP twice for 2!",
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 1.0.rand, \rel, 20]),
            object: (type: "a RedObject", age: inf, mass: 10),
        ),
        (
            info: "Stop sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 0
        ),
    ],
    45: [
        (
            info: "heavy __analog 2 with cutoff",
            message: \worldobj,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 20, \cutoff, -1]),
            object: (type: "a RedObject", age: inf, mass: 10)
        ),
        (
            info: "Stop sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 0
        ),
    ],
    50: [
        (
            info: "AIRY",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "heavy __probe - TAP twice for 2!",
            message: \worldobj,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 20]),
            object: (type: "a RedObject", age: inf, mass: 9)
        )
    ],
    51: [
        (
            info: "AIRY: heavy __probe 2",
            message: \worldobj,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 20]),
            object: (type: "a RedObject", age: inf, mass: 9)
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
    60: [
        ( // Remove all objects.
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Heavy __cmb - TAP twice for 2!",
            message: \worldobj,
            synth: (name: \sr__e__cmb, params: [\att, 1.0.rand, \rel, 30]),
            object: (type: "a RedObject", age: inf, mass: 9),
        ),
    ],
    61: [
        (
            info: "Heavy __cmb",
            message: \worldobj,
            synth: (name: \sr__e__cmb, params: [\att, 3 + 2.0.rand2, \rel, 30]),
            object: (type: "a RedObject", age: inf, mass: 9)
        )
    ],
    70: [
        (
            info: "ELECTRO SOLO",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "2 heavy __melo - TAP twice for 2!",
            message: \worldobj,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, scales[1].bufnum]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
    ],
    71: [
        (
            info: "heavy __melo 2",
            message: \worldobj,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, scales[1].bufnum]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
    ],
    72: [
        (
            info: "Schedule scale switch",
            message: \task, name: \switchScale, act: 1
        ),
    ],
    75: [
        ( // IMPORTANT! switchScale sends scales as buffers to all nodes
            // It should be stopped before starting granWave to prevent
            // sending scales instead of samples.
            info: "Stop switching scales",
            message: \task, name: \switchScale, act: 0
        ),
        // (
        //     info: "Schedule granular waves",
        //     message: \task, name: \granWave, act: 1
        // ),
        // ( // ensure audioIn (grains)
        //     message: \worldpar,
        //     params: [audioIn: true]
        // ),
    ],
    // 77: [
    //     ( // Remove all - switch to ringz
    //         message: \worldact, action: \remove, objects: \all
    //     ),
    //     (
    //         info: "Heavy __ringz - TAP twice for 2!",
    //         message: \worldobj,
    //         synth: (name: \sr__e__ringz, params: [\att, 10.0.rand]),
    //         object: (type: "a RedObject", age: inf, mass: 8)
    //     ),
    //     (
    //         info: "Ave __lowe Boid",
    //         message: \worldobj,
    //         synth: (name: \sr__e__lowe, params: [\att, 10.0.rand, \rel, 10]),
    //         object: (type: "a RedBoid", age: inf, mass: 6)
    //     ),
    // ],
    // 78: [
    //     (
    //         info: "Heavy __ringz 2",
    //         message: \worldobj,
    //         synth: (name: \sr__e__ringz, params: [\att, 10.0.rand]),
    //         object: (type: "a RedObject", age: inf, mass: 8)
    //     ),
    // ],
    79: [
        (
            info: "Add ave __noisy, long attack",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 180, \rel, 10]),
            object: (type: "a RedBoid", age: inf, mass: 7)
        ),
        // (
        //     info: "Stop percussive granWave",
        //     message: \task, name: \granWave, act: 0
        // ),
        ( // switch audioIn off
            message: \worldpar,
            params: [audioIn: true]
        ),
    ],
    80: [
        ( // Stop schedule with sporadic \sr__e__cmb
            info: "Stop schedules",
            message: \task, name: \sporadicCMB, act: 0
        ),
        ( // Stop schedule with sporadic \sr__e__melo
            message: \task, name: \sporadicMelo, act: 0
        ),
        (
            info: "Add one heavy __noisy",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 9]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
    ],
    85: [
        (
            info: "BREAKS",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
        (
            info: "heavy __entro - TAP twice for 2!",
            message: \worldobj,
            synth: (name: \sr__e__entro),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
    ],
    86: [
        (
            info: "BREAK GROOVE: heavy __entro 2",
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
            info: "heavy __gauss - TAP twice for 2!",
            message: \worldobj,
            synth: (name: \sr__e__gauss, params: [\att, 1, \rel, 8]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
    ],
    91: [
        (
            info: "GROOVE_2: heavy __gauss 2",
            message: \worldobj,
            synth: (name: \sr__e__gauss, params: [\att, 1, \rel, 8]),
            object: (type: "a RedObject", age: inf, mass: 9)
        )
    ],
    // 92: [
    //     (
    //         info: "GROOVE_2: more heavy __gauss TAP twice for 2!",
    //         message: \worldobj,
    //         synth: (name: \sr__e__gauss, params: [\att, 1, \rel, 8]),
    //         object: (type: "a RedObject", age: inf, mass: 8)
    //     ),
    // ],
    // 93: [
    //     (
    //         info: "GROOVE_2: heavy __gauss 2",
    //         message: \worldobj,
    //         synth: (name: \sr__e__gauss, params: [\att, 1, \rel, 8]),
    //         object: (type: "a RedObject", age: inf, mass: 8)
    //     )
    // ],
    95: [
        ( // Remove all objects.
            info: "FADE AWAY",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "Particles ON",
            message: \worldpar,
            params: [
                particles: 1, partSigmoidRatio: 0.7, partFreq: 0.02, partAgeThresh: 80,
                partInitAccel: 3, partGuide: "object", partSynth: \sr__e__analog,
            ]
        ),
        (
            info: "2 light granular boids",
            message: \worldobj,
            synth: (name: \sr__g__reg, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedBoid", age: inf, mass: 6)
        ),
        (
            message: \worldobj,
            synth: (name: \sr__g__loop, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 6)
        ),
        ( // ensure audioIn (drums)
            message: \worldpar,
            params: [audioIn: true]
        ),
        (
            info: "heavy __noisy - TAP twice for 2!",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
        ),
    ],
    96: [
        (
            info: "heavy __noisy 2",
            message: \worldobj,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            object: (type: "a RedObject", age: inf, mass: 9)
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
                syn = [\sr__e__humm, \sr__e__radio][i % 2]; // alternate between synths

                // Age spans over to the next object birth - no gaps!
                // The lighter objects the faster they die, but their demography is denser.
                age = next * (1 + (1/(next.pow(0.33))));

                // Mass is: sqrt propotion to life cycle for \sr__e__ringz; constant for \sr__e__pulse.
                mass = next.sqrt.clip(1, 3);

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
            0.01.wait;
        }
    }),
    randomParticles: Task({
        var key, next;
        var particleParams = [ // list of acceptable configurations
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.3, \partAgeThresh, 40, \partInitAccel, 10 ],
            [\partSynth, \sr__e__cmb,   \partSigmoidRatio, 0.8, \partAgeThresh, 5,  \partInitAccel, 2.6],
            [                           \partSigmoidRatio, 0.4, \partAgeThresh, 80, \partInitAccel, 30 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.7, \partAgeThresh, 5,  \partInitAccel, 8.0],
            [                           \partSigmoidRatio, 0.2, \partAgeThresh, 100,\partInitAccel, 0.1],
            [\partSynth, \sr__e__melo,  \partSigmoidRatio, 0.7, \partAgeThresh, 47, \partInitAccel, 2.0],
            [\partSynth, \sr__e__pulse, \partSigmoidRatio, 0.2, \partAgeThresh, 2,  \partInitAccel, 20 ],
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
    voices: Task({
        var buff, syn;
        inf.do{ |j|
            // Start fade-in synth before the wave.
            buff = voices[(j % voices.size).asInt];
            syn = [\sr__g__unst, \sr__g__loop, \sr__g__gust].wchoose([0.9, 0.08, 0.02]);
            sendObjCreate.(
                (
                    message: \worldobj,
                    synth: (name: syn, params: [\att, 2, \bufnum, buff.bufnum]),
                    object: (age: 7 + 3.0.rand2, mass: 3, type: "a RedBoid")
                )
            );
            rrand(5, 20).wait;
        }
    }),
    sporadicAnalogCutoff: Task({
        loop {
            // Send object creation message.
            sendObjCreate.(
                (
                    message: \worldobj,
                    synth: (name: \sr__e__analog, params: [\cutoff, -1, \rel, rrand(4, 6)]),
                    object: (age: 5 + 2.0.rand2, mass: 9, type: "a RedObject",
                        pos: [rrand(200, 600), rrand(200, 300), 500])
                )
            );
            (11 + 2.0.rand2).wait;
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
                    object: (age: rrand(1.7, 5.0), mass: 8, type: "a RedBoid")
                )
            );
            (next + rand2(next * 0.5)).wait;
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
                    synth: (name: \sr__e__melo, params: [\att, 1.5, \rel, 3,
                        \bufnum, scales[1].bufnum // specific scale for __melo!
                    ]),
                    object: (age: rrand(5, 10), mass: 4, type: "a RedObject")
                )
            );
            ((next + rand2(next * 0.25))/2).wait;
        }
    }),
    switchScale: Task({
        inf.do{ |i|
            // WARNING! This works weird! Compare with example of
            // DegreeToKey from the doc! Investigate!!!
            //
            s.sendMsg("/n_set", nil, \bufnum, scales[i % scales.size].bufnum);
            (4..8).choose.wait;
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
                        params: [\att, 4, \rel, 3.0.rand, \bufnum, guideBuff.bufnum]
                    )
                )
            );
            // Wait attack time (will overlap with wave a little).
            4.wait;
            // Alternate between samples from samples.
            buff = samples[(j % samples.size).asInt];
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
            rrand(20, 45).wait;
        }
    })
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

    messages.do { |l, i|
        l.do { |m, j| // replace keywords with node ids
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


// Send action to the World.
sendAct = { |action, objects|
    if ((action.asString != "") && (action.isNil.not)) {
        receiverNet.sendMsg("/worldact", action, objects);
    };
};


// Run or stop task.
taskPlay = { |task, play=false|
    try {
        if (play) {
            task.play(doReset:true)
        } {
            task.stop;
            task.reset;
        }
    } { |err|
        postf("Error while trying to switch task % on or off:\n%\n", task, err);
    };
};


// Obtain the key next/prev to current.
getKey = { |current=nil, next=1|
    var k, c;
    k = thePiece.keys.asArray.asInteger.sort;
    c = k.indexOf(current) ? -1;
    k[c + next] ? k[0]; // Go back to beginning upon reaching the upper threshold.
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
            \task, { // launch/stop a task
                taskPlay.(task[d[\name]], d[\act].booleanValue)
            },
            \worldact, { // send action to the World
                sendAct.(d.atFail(\action, {\}), d[\objects])
            },
            \worldobj, { // single object creation
                sendObjCreate.(d)
            },
            \worldpar, { // send World parameter(s)
                sendParam.(d)
            },
            \s_new, { // send a new synth message directly to the server
                sendSNew.(d)
            },
            \n_set, { // send params directly to the synth on the server
                s.listSendMsg(["/n_set", synths.at(d[\synth][\id])] ++ d[\synth].atFail(\params, {[]}))
            },
            \g_new, { // send bundle to the server, place everything into the group
                groupNew.(d)
            },
            \g_free, { // release group
                groupFree.(d)
            },
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
btNext = Button(buttons, 70@45).states_([[">>", Color.black, Color.white]])
.action_({ |bt|
    if (animate.not) {animate = true}; // bring it on!
    stCurrNum.string = current = getKey.(current);
    stCurrInfo.string = displayEventInfo.(current);
    stNextNum.string = next = getKey.(current, 1);
    stNextInfo.string = displayEventInfo.(next, 50);

    processEvents.(current);
});

btPrev = Button(buttons, 70@45).states_([["<<", Color.black, Color.white]])
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

MIDIIn.connectAll;
midiServerVolume = MIDIFunc.cc({ |val, ccNum, chan, srcID|
    s.volume.volume = \db.asSpec.map(\midinote.asSpec.unmap(val));
}, 12, 0);
midiNext = MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
    { btNext.valueAction_(1) }.defer;
}, 43, 0);
midiPrev = MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
    { btPrev.valueAction_(1) }.defer;
}, 46, 0);
midiClean = MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
    sendAct.(\remove, \all)
}, 58, 0);
midiClean = MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
    sendAct.(\remove, \springs)
}, 70, 0);

CmdPeriod.doOnce({
    // Free buffers.
    guideBuff.free;
    midiServerVolume.free;
    midiNext.free;
    midiPrev.free;
    midiClean.free;
    win.close;
});
)