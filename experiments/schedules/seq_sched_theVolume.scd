// TO-DO:
// - opportunity to hook synth from node to the object and back (only change \busnum??)

(
var playRout, quant= 0.01, current;
var w, lbKey, lbSteps, lbWait, liWait; // main window
var warn= 0.6, crit= 0.9;
var key, next, syn, obj, age, mass;
var synths=Dictionary.new; // temp dictionary of the synths symbolic IDs vs. server Nodes
var sGroupId, receiverNet;
var dictObjSeq, msetObjSeq; // Markov chains used for creating sequences and obtaining objects' birthtime.

var thePiece=Dictionary.new; // The dictionary that describes sequence of scheduling tasks.
var getKey, procKey, sendObjCreate;
var task;

// Initial settings.
// Net Address and Port of the Receiver.
receiverNet = NetAddr.new("127.0.0.1", 57120);
// Group for synths.
sGroupId= s.nextNodeID;
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

// The dictionary that describes sequence of scheduling tasks.
thePiece = (
    0: [ // Initial settings.
        (
            message: \worldpar,
            params: [
                // Audio settings.
                \audioIn: false, \confSurround: "Ambisonic4", \inbus: 8, \fieldDepth: 3,
                \master: 1,
                // World settings.
                \repulsiveEnergy: 20, \heavy: 5, \initMass: 5, \starMass: 120, \world_maxVel: 30,
                \objAttract: false, \world_damping: 0.8, \world_gravity: 0.98,
                // General.
                \visualize: 1
            ]
        ),
        ( // Remove all objects before strting out.
            message: \worldact,
            action: \remove,
            objects: \all
        )
    ],
    10: [
        ( // Initialize \sr_pulse, that will persist throughout 10-30.
            message: \worldobj,
            synth: (
                name: \sr_pulse,
                params: [\att, 10]
            ),
            object: (
                type: "a RedBoid",
                age: inf,
                mass: 4
            )
        )
    ],
    15: [
        ( // Initialize \sr_ringz, that will persist throughout 10-30.
            message: \worldobj,
            synth: (
                name: \sr_ringz,
                params: [\att, 10]
            ),
            object: (
                type: "a RedBoid",
                age: inf,
                mass: 4
            )
        ),
        ( // Start schedule with occasional light \sr_pulse and \sr_ringz
            message: \task,
            name: \lightPulseRingz,
            act: 1
        )
    ],
    20: [
        ( // Start schedule with sporadic \sr_analog, cutoff= -1
            message: \task,
            name: \sporadicAnalogCutoff,
            act: 1
        )
    ],
    30: [
        ( // Stop schedule with occasional light \sr_pulse and \sr_rings
            message: \task,
            name: \lightPulseRingz,
            act: 0
        ),
        ( // Stop schedule with sporadic \sr_analog, cutoff= -1
            message: \task,
            name: \sporadicAnalogCutoff,
            act: 0
        ),
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Start ave \sr_pulse.
            message: \worldobj,
            synth: (
                name: \sr_pulse,
                params: [\att, 1, \rel, 10]
            ),
            object: (
                type: "a RedBoid",
                age: rrand(80, 150), // ...will fade away before the next sequence.
                mass: 4
            ),
        ),
        ( // A "lick" of sr_ringz.
            message: \worldobj,
            synth: (
                name: \sr_ringz,
                params: [\att, 1, \rel, 1]
            ),
            object: (
                type: "a RedBoid",
                age: 3,
                mass: 4
            ),
        ),
        // Start 2 heavy sr_analog w/default cutoff.
        (
            message: \worldobj,
            synth: (
                name: \sr_analog,
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
                name: \sr_analog,
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
        ( // Start 2 heavy sr_analog w/default cutoff.
            message: \worldobj,
            synth: (
                name: \sr_analog,
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
                name: \sr_analog,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            )
        ),
        ( // Start schedule with sporadic \sr_pulse
            message: \task,
            name: \sporadicPulse,
            act: 1
        )
    ],
    40: [
        ( // Start 2 heavy sr_analog w/default cutoff, adding them to the world (to get heavier sound).
            message: \worldobj,
            synth: (
                name: \sr_analog,
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
                name: \sr_analog,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            )
        ),
        ( // Stop schedule with sporadic \sr_pulse
            message: \task,
            name: \sporadicPulse,
            act: 0
        )
    ],
    45: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Start 1 ave \sr_analog (to mimick fade-out).
            message: \worldobj,
            synth: (
                name: \sr_analog,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 10
            )
        ),
        ( // Start 1 heavy \sr_prob (to mimick cross-fade).
            message: \worldobj,
            synth: (
                name: \sr_prob,
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
        ( // Start 2 heavy \sr_prob.
            message: \worldobj,
            synth: (
                name: \sr_prob,
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
                name: \sr_prob,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 11
            )
        )
    ],
    60: [
        ( // Start schedule with sporadic \sr_cmb
            message: \task,
            name: \sporadicCMB,
            act: 1
        ),
        ( // Start schedule with sporadic \sr_melo
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
        ( // "Leave" one of \sr_prob.
            message: \worldobj,
            synth: (
                name: \sr_prob,
                params: [\att, 2 + 1.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 9
            )
        ),
        ( // Start a heavy \sr_cmb (mimicking cross-fade).
            message: \worldobj,
            synth: (
                name: \sr_cmb,
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
        ( // Stop schedule with sporadic \sr_cmb
            message: \task,
            name: \sporadicCMB,
            act: 0
        ),
        ( // Stop schedule with sporadic \sr_melo
            message: \task,
            name: \sporadicMelo,
            act: 0
        ),
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        ( // Start 2 heavy \sr_cmb.
            message: \worldobj,
            synth: (
                name: \sr_cmb,
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
                name: \sr_cmb,
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
        ( // Start a heavy \sr_star.
            message: \worldobj,
            synth: (
                name: \sr_star,
                params: [\att, 10.0.rand2, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 11
            )
        )
    ],
    85: [
        ( // Remove all objects.
            message: \worldact,
            action: \remove,
            objects: \all
        ),
        // Start 2 heavy \sr_star
        (
            message: \worldobj,
            synth: (
                name: \sr_star,
                params: [\att, 1, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 11
            )
        ),
        (
            message: \worldobj,
            synth: (
                name: \sr_star,
                params: [\att, 1.5, \rel, 10]
            ),
            object: (
                type: "a RedObject",
                age: inf,
                mass: 11
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

// Tasks dictionary.
task = (
    lightPulseRingz: Task({
        var key, next, syn, obj, age;
        loop {
            // Pick up a key and the number of iterations randomly.
            // Average sequences are the most probable, long are the least probable.
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 1, 10].normalizeSum);

            dictObjSeq[key.asInteger][0].choose.do{
                next = msetObjSeq.next(key);

                // Choose a synth:
                // \sr_pulse is more probable, it creates better background;
                // \sr_ringz is required to diversify the audio field every now and then.
                //syn = [\sr_pulse, \sr_ringz].wchoose([0.7, 0.3]);
                syn = [\sr_pulse, \sr_ringz].choose;

                // Age spans over to the next object birth - no gaps!
                // The lighter objects the faster they die, but their demography is denser.
                age = next * (1 + (1/(next.pow(0.33))));

                // Mass is of a sqrt propotion to life cycle.
                mass = next.sqrt.clip(3, 6);

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
                        name: \sr_analog,
                        params: [\cutoff, -1]
                    ),
                    object: (
                        age: rrand(1.70, 2.30),
                        mass: 6,
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
                        name: \sr_pulse,
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
                        name: \sr_cmb,
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
                        name: \sr_melo,
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
    })
);

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
                p = d[\object].atFail(\pos, {nil});

                // Check if position given correctly.
                if (p.isNil || (p.class != Array)) {p = [0, 0, 0]};

                // It might also be only X & Y or even X given, in that case the rest must be 0.
                3.do{|i| try {p[i] = p[i].asFloat} { |err| err.postln; p.add(0)}};

                // Send object creation message.
                receiverNet.sendBundle(0.01,
                    [
                        "/worldobj",
                        d[\synth][\name], d[\object][\type], d[\object][\age],
                        p[0], p[1], p[2], d[\object][\mass]
                    ]
                    ++ d[\synth].atFail(\params, {[]})
                );
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
                synths.put(d[\synth][\id], s.nextNodeID);
                s.listSendMsg(["/s_new", d[\synth][\name],
                    synths.at(d[\synth][\id]), 0, sGroupId] ++ d[\synth].atFail(\params, {[]}));
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

w.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    [char, modifiers, unicode, keycode].postln;
};

w.refresh;
w.front;

CmdPeriod.doOnce({
    playRout.stop;
    w.close;
	});
)