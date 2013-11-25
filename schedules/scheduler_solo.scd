(
var playRout, quant= 0.01, current;
var w, lbKey, lbSteps, lbWait, liWait; // main window
var warn= 0.6, crit= 0.9;
var key, next, syn, obj, age, mass;
var synths=Dictionary.new; // temp dictionary of the synths symbolic IDs vs. server Nodes
var sGroupId, receiverNet;
var dictObjSeq, msetObjSeq; // Markov chains used for creating sequences and obtaining objects' birthtime.

var thePiece=Dictionary.new; // The dictionary that describes sequence of scheduled tasks.
var getKey, procKey, sendObjCreate, sendSNew;
var task;

// Global params of the piece dictionary.
var parmDir = Dictionary.new;

// WARNING! Specific for the current piece!
// Read left channel only to feed to TGrains!
var drumLoop1 = Buffer.readChannel(s, "~/Music/Sympli_Romatiko/solo/Audio/bbcloop_comp.wav", channels: [0]);
var introBuff = Buffer.readChannel(s,
    "~/Music/Sympli_Romatiko/solo/Audio/DRLATPOL.WAV",
    channels: [0]);
var buffList = List.new;
[ // Fill buffList.
    "~/Music/Sympli_Romatiko/solo/Audio/bboxbeay2.wav",
    "~/Music/Sympli_Romatiko/solo/Audio/17boxloop.wav",
    "~/Music/Sympli_Romatiko/solo/Audio/BBOX75.WAV",
    "~/Music/Sympli_Romatiko/solo/Audio/BBOX90.WAV",
    "~/Music/Sympli_Romatiko/solo/Audio/loop_clean.wav"
].do { |filename|
    buffList.add(Buffer.readChannel(s, filename, channels: [0]));
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
    0: [ // Initial settings
        // (notice \master, 0 - it will be set to 1 during the next phase, inside the task).
        (
            message: \worldpar,
            params: [
                // Audio settings.
                \audioIn: true, \confSurround: "Ambisonic4", \inbus: 20, \fieldDepth: 4,
                \master: 0,
                // World settings.
                \repulsiveEnergy: 20, \heavy: 5, \initMass: 5, \starMass: 120, \world_maxVel: 30,
                \objAttract: false, \world_damping: 0.8, \world_gravity: 0.98,
                // General.
                \visualize: 1
            ]
        ),
        ( // Remove all objects before starting out.
            message: \worldact,
            action: \remove,
            objects: \all
        )
    ],
    10: [
        ( // Start initial schedule for \sr__e__ringz
            message: \task,
            name: \initRingz,
            act: 1
        )
    ],
    15: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Initialize 2 \sr__e__pulse, that will persist throughout 10-30.
            message: \worldobj,
            synth: (
                name: \sr__e__pulse,
                params: [\att, 1]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 5
            )
        ),
        ( // Initialize 2 \sr__e__pulse, that will persist throughout 10-30.
            message: \worldobj,
            synth: (
                name: \sr__e__pulse,
                params: [\att, 1]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 5
            )
        ),
        ( // Start schedule with occasional light \sr__e__pulse and \sr__e__ringz
            message: \task,
            name: \lightPulseRingz,
            act: 1
        ),
        ( // Clear initial schedule for \sr__e__ringz
            message: \task,
            name: \initRingz,
            act: 0
        )
    ],
    20: [
        ( // Start schedule with sporadic \sr__e__analog, cutoff= -1
            message: \task,
            name: \sporadicAnalogCutoff,
            act: 1
        )
    ],
    30: [
        ( // Stop schedule with occasional light \sr__e__pulse and \sr_rings
            message: \task,
            name: \lightPulseRingz,
            act: 0
        ),
        ( // Stop schedule with sporadic \sr__e__analog, cutoff= -1
            message: \task,
            name: \sporadicAnalogCutoff,
            act: 0
        ),
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Start ave \sr__e__pulse.
            message: \worldobj,
            synth: (
                name: \sr__e__pulse,
                params: [\att, 1, \rel, 10]
            ),
            object: (
                type: "a RedBoid",
                age: rrand(80, 150), // ...will fade away before the next sequence.
                mass: 4
            ),
        ),
        ( // A "lick" of sr__e__ringz.
            message: \worldobj,
            synth: (
                name: \sr__e__ringz,
                params: [\att, 1, \rel, 1]
            ),
            object: (
                type: "a RedBoid",
                age: 3,
                mass: 4
            ),
        ),
        // Start 2 heavy sr__e__analog w/default cutoff.
        (
            message: \worldobj,
            synth: (
                name: \sr__e__analog,
                params: [\att, 1.0.rand, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 8
            ),
        ),
        (
            message: \worldobj,
            synth: (
                name: \sr__e__analog,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 8
            )
        )
    ],
    35: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Start 2 heavy sr__e__analog w/default cutoff.
            message: \worldobj,
            synth: (
                name: \sr__e__analog,
                params: [\att, 1.0.rand, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            ),
        ),
        (
            message: \worldobj,
            synth: (
                name: \sr__e__analog,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            )
        ),
        ( // Add a little bit of heaviness.
            message: \worldobj,
            synth: (
                name: \sr__e__lowe,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedBoid",
                age: inf,
                mass: 4
            )
        ),
        ( // Start schedule with sporadic \sr__e__pulse
            message: \task,
            name: \sporadicPulse,
            act: 1
        ),
        ( // Start drum loop.
            message: \s_new,
            synth: (
                id: \drum_loop_stable,
                name: \sr_loop_stable,
                params: [\att, 60, \busnum, 0, \master, 2.5, \bufnum, drumLoop1.bufnum]
            )
        ),
        ( // Start drum unstable part.
            message: \s_new,
            synth: (
                id: \drum_loop_unstable,
                name: \sr_loop_unstable,
                params: [\att, 60, \rel, 30, \busnum, 0, \master, 1.5, \bufnum, drumLoop1.bufnum]
            )
        ),
    ],
    40: [
        ( // Start 2 heavy sr__e__analog w/default and -1 cutoff.
            message: \worldobj,
            synth: (
                name: \sr__e__analog,
                params: [\att, 1.0.rand, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            ),
        ),
        (
            message: \worldobj,
            synth: (
                name: \sr__e__analog,
                params: [\att, 2 + 1.0.rand2, \rel, 10, \cutoff, -1]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            )
        ),
        ( // Stop schedule with sporadic \sr__e__pulse
            message: \task,
            name: \sporadicPulse,
            act: 0
        ),
        ( // Stop drum loop.
            message: \n_set,
            synth: (
                id: \drum_loop_stable,
                params: [\gate, 0, \rel, 30]
            )
        ),
        ( // Stop drum unstable part.
            message: \n_set,
            synth: (
                id: \drum_loop_unstable,
                params: [\gate, 0, \rel, 30]
            )
        )
    ],
    45: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Start 2 ave \sr__e__analog (to mimick fade-out).
            message: \worldobj,
            synth: (
                name: \sr__e__analog,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            )
        ),
        (
            message: \worldobj,
            synth: (
                name: \sr__e__analog,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            )
        ),
        ( // Start 1 heavy \sr__e__probe (to mimick cross-fade).
            message: \worldobj,
            synth: (
                name: \sr__e__probe,
                params: [\att, 1.0.rand, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 8
            ),
        )
    ],
    50: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Start 2 heavy \sr__e__probe.
            message: \worldobj,
            synth: (
                name: \sr__e__probe,
                params: [\att, 1.0.rand, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 11
            ),
        ),
        (
            message: \worldobj,
            synth: (
                name: \sr__e__probe,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 11
            )
        )
    ],
    55: [
        ( // Start schedule with sporadic \sr__e__cmb
            message: \task,
            name: \granWave,
            act: 1
        ),
    ],
    60: [
        ( // Start schedule with sporadic \sr__e__cmb
            message: \task,
            name: \sporadicCMB,
            act: 1
        ),
        ( // Start schedule with sporadic \sr__e__melo
            message: \task,
            name: \sporadicMelo,
            act: 1
        )
    ],
    65: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // "Leave" one of \sr__e__probe.
            message: \worldobj,
            synth: (
                name: \sr__e__probe,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 9
            )
        ),
        ( // Start a heavy \sr__e__cmb (mimicking cross-fade).
            message: \worldobj,
            synth: (
                name: \sr__e__cmb,
                params: [\att, 1.0.rand, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 8
            ),
        )
    ],
    70: [
        ( // Stop schedule with sporadic \sr__e__cmb
            message: \task,
            name: \sporadicCMB,
            act: 0
        ),
        ( // Stop schedule with sporadic \sr__e__melo
            message: \task,
            name: \sporadicMelo,
            act: 0
        ),
        ( // Stop percussive granWave.
            message: \task,
            name: \granWave,
            act: 0
        ),
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Start 2 heavy \sr__e__cmb.
            message: \worldobj,
            synth: (
                name: \sr__e__cmb,
                params: [\att, 1.0.rand, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 9
            ),
        ),
        (
            message: \worldobj,
            synth: (
                name: \sr__e__cmb,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 9
            )
        )
    ],
    80: [
        ( // Start a heavy \sr__e__lowe.
            message: \worldobj,
            synth: (
                name: \sr__e__lowe,
                params: [\att, 10.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 7
            )
        )
    ],
    85: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        // Start 2 \sr__e__lowe (but not extremely heavy, otherwise it blows the sub).
        (
            message: \worldobj,
            synth: (
                name: \sr__e__lowe,
                params: [\att, 1, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 7
            )
        ),
        (
            message: \worldobj,
            synth: (
                name: \sr__e__lowe,
                params: [\att, 1.5, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 7
            )
        )
    ],
    90: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        )
    ]
);

// Store global params of the piece in a dictionary.
parmDir.putPairs(thePiece[0][0][\params]);

// Tasks dictionary.
task = (
    initRingz: Task({
        2.do { // create 2 sr__e__ringz boids.
            sendObjCreate.value(
                (message: \worldobj,
                    synth: (name: \sr__e__ringz, params: [\att, 0.1, \rel, 2]),
                    object: (age: inf, mass: parmDir[\heavy].asInt + 2.0.rand, type: "a RedObject")
                )
            );
        };
        // wait 15 sec after objects creation.
        15.wait;
        // bring it!
        receiverNet.sendMsg("/worldpar", \master, 1);
    }),
    lightPulseRingz: Task({
        var key, next, syn, obj, age;
        loop {
            // Pick up a key and the number of iterations randomly.
            // Average sequences are the most probable, long are the least probable.
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 1, 10].normalizeSum);

            dictObjSeq[key.asInteger][0].choose.do{
                next = msetObjSeq.next(key);

                // Choose a synth:
                // \sr__e__pulse is more probable, it creates better background;
                // \sr__e__ringz is required to diversify the audio field every now and then.
                //syn = [\sr__e__pulse, \sr__e__ringz].wchoose([0.7, 0.3]);
                syn = [\sr__e__pulse, \sr__e__ringz].choose;

                // Age spans over to the next object birth - no gaps!
                // The lighter objects the faster they die, but their demography is denser.
                age = next * (1 + (1/(next.pow(0.33))));

                // Mass is: sqrt propotion to life cycle for \sr__e__ringz; constant for \sr__e__pulse.
                mass = if (syn == \sr__e__pulse) {3} {next.sqrt.clip(3, 6);};

                // Send object creation message.
                sendObjCreate.value(
                    (
                        message: \worldobj,
                        synth: (
                            name: syn,
                            params: []
                        ),
                        object: (
                            age: age,
                            mass: mass,
                            type: "a RedBoid"
                        )
                    )
                );
                next.wait;
            };
            0.001.wait;
        }
    }),
    sporadicAnalogCutoff: Task({
        var next=8.30;
        loop {
            // Send object creation message.
            sendObjCreate.value(
                (
                    message: \worldobj,
                    synth: (
                        name: \sr__e__analog,
                        params: [\cutoff, -1]
                    ),
                    object: (
                        age: rrand(1.70, 2.30),
                        mass: 8,
                        type: "a RedObject"
                    )
                )
            );
            (next + rand2(next * 0.25)).wait;
        }
    }),
    sporadicPulse: Task({
        var next=20;
        loop {
            // Send object creation message.
            sendObjCreate.value(
                (
                    message: \worldobj,
                    synth: (
                        name: \sr__e__pulse,
                        params: [\att, 1.5, \rel, 3]
                    ),
                    object: (
                        age: rrand(1.7, 3.0),
                        mass: 8,
                        type: "a RedBoid"
                    )
                )
            );
            (next + rand2(next * 0.25)).wait;
        }
    }),
    sporadicCMB: Task({
        var age, next=30;
        loop {
            // Send object creation message.
            sendObjCreate.value(
                (
                    message: \worldobj,
                    synth: (
                        name: \sr__e__cmb,
                        params: [\att, 1.5, \rel, 3]
                    ),
                    object: (
                        age: rrand(2, 5),
                        mass: 6,
                        type: "a RedObject"
                    )
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
            sendObjCreate.value(
                (
                    message: \worldobj,
                    synth: (
                        name: \sr__e__melo,
                        params: [\att, 1.5, \rel, 3]
                    ),
                    object: (
                        age: rrand(5, 10),
                        mass: 4,
                        type: "a RedObject"
                    )
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
            sendObjCreate.value(
                (
                    message: \worldobj,
                    object: (age: age, mass: 5, type: "a RedBoid"),
                    synth: (
                        name: introSynths.wchoose(introSynthProb),
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
                    sendSNew.value(
                        (
                            synth: (
                                name: \sr__u__grain,
                                params: [\bufnum, buff.bufnum,
                                    \busnum, parmDir[\inbus],
                                    \rate, 1 + timeprop.rand2.pow(2),
                                    \pos, rrand(0.0, timeprop),
                                    \amp, exprand(0.05, 1.00)
                                ]
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

// Send object creation message.
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

// Obtain the key next/prev to current.
getKey = { arg current=nil, next=1;
    var k, c;
    k = thePiece.keys.asArray.asInteger.sort;
    c = k.indexOf(current) ? -1;
    k[c + next] ? k[0]; // Go back to beginning if nothing more left.
};

// Process specific key from thePiece.
procKey = { arg k=nil;
    var val, funcName;
    val = thePiece.atFail(k, {[]});
    val.do { |d, l|
        d[\message].switch(
            \task, { // Launch/stop a task.
                try {
                    if (d[\act].booleanValue) {task[d[\name]].play()} {task[d[\name]].stop}
                } { |err|
                    postf("Error while trying to switch task % on or off:\n%\n", d[\name], err);
                };
            },
            \worldobj, { // Single object creation.
                sendObjCreate.value(d);
            },
            \worldpar, { // Send World parameter(s).
                if (d.atFail(\params, {[]}).size > 1) {
                    d[\params].pairsDo { |n, v| receiverNet.sendMsg("/worldpar", n, v)};
                }
            },
            \worldact, { // Send an act signal to the World.
                if (d.atFail(\action, {\}) != \) {
                    receiverNet.sendMsg("/worldact", d[\action], d[\objects]);
                };
            },
            \s_new, { // Send a new synth message directly to the server.
                sendSNew.value(d);
            },
            \n_set, { // Send a 'set params' message directly to the server.
                s.listSendMsg(["/n_set", synths.at(d[\synth][\id])] ++ d[\synth].atFail(\params, {[]}))
            }
        )
    }
};

// GUI.
w= Window("sequencing and scheduling", Rect(1800, 900, 270, 150), resizable:false)
	.acceptsMouseOver_(true);
w.view.decorator = FlowLayout(w.view.bounds);
b = StaticText(w, 260@50).font_(Font("Helvetica", 36));
c = StaticText(w, 260@50).font_(Font("Helvetica", 18));
Button(w, 77@30)
.states_([
    ["<<", Color.black, Color.white]
])
.action_({ |bt|
    b.string = current = getKey.value(current, -1);
    procKey.value(current);
});
Button(w, 77@30)
.states_([[">>", Color.black, Color.white]])
.action_({ |bt|
    b.string = current = getKey.value(current);
    procKey.value(current);
});

// WARNING! This is specific for the current setup and piece (quad).
Button(w, 77@30)
.states_([
    ["0-3 -> 4", Color.blue, Color.white],
    ["free 4", Color.white, Color.blue],
])
.action_({ |bt|
    if (bt.value == 1) {
        sendSNew.value(
            (synth: (
                id: \sr_mixerNode,
                name: \sr_mixerNode4x1,
                params: [\inbus, 0, \outbus, 4])
            )
        )
    } {
        s.listSendMsg(["/n_set", synths.at(\sr_mixerNode), \gate, 0])
    }
});

w.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    //[char, modifiers, unicode, keycode].postln;
};

w.refresh;
w.front;

CmdPeriod.doOnce({
    playRout.stop;

    // Free buffers.
    drumLoop1.free;
    introBuff.free;
    buffList.do { |buff| buff.free};

    w.close;
	});


// SYNTHS USED IN THIS PARTICULAR PIECE.
SynthDef(\sr_loop_stable, {
    arg bufnum=0, busnum=0, pos=0, amp=1, master=1, gate=1, rate=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist;
    var in, signal, out;
    in = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), Impulse.ar(BufDur.kr(bufnum).reciprocal), BufFrames.ir(bufnum) * pos);
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    // uneven ellipse rotation
    azimuth = Saw.kr(SinOsc.kr(0.1, 0, 0.75, 0.625), 2pi);
    dist = TRand.kr(0.01, 0.7, Dust.kr(0.1));
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
    azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

SynthDef(\sr_loop_unstable, {
    arg bufnum=0, busnum=0, pos=0, amp=1, master=1, gate=1, rate=1, att=1, rel=1, crva=3, crvr= -3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.6pi, 0.6pi, 0.25pi], speakerElev= 0, speakerDist= [6.34, 4.88, 4.88, 6.34],
    maxDist=3, scaleFlag=1, dist;
    var in, signal, out;
    in = PlayBuf.ar(1, bufnum,
        TWChoose.kr(
            Dust.kr(0.01),
            [
                BufRateScale.kr(bufnum) * TRand.kr(0.5, 1.5, Dust.kr(0.2)),
                BufRateScale.kr(bufnum) * TRand.kr(-0.5, 2, Dust.kr(0.2)),
            ],
        [0.8, 0.2]),
        Dust.kr(0.2),
        TRand.kr(0, BufFrames.ir(bufnum), Dust.kr(0.2))
    );
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    // azimuth rotation
    azimuth = LFNoise0.kr(0.1, 2pi);
    dist = LFNoise0.kr(TRand.kr(0.01, 0.5, Dust.kr(0.1)), 0.2, 0.3);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master * 1.5);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
    azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);
)