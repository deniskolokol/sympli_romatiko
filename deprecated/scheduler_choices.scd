// WARNING!
// Some synths are re-defined here, so scheduler_choices.scd
// should be started AFTER sympli_romatiko/main.scd!
//

(
var thePiece; // main dictionary with the sequence of scheduled tasks
var parmDir = Dictionary.new; // Global params of the piece dictionary.
var sGroupId; // root group
var receiverNet; // communication
var task; // tasks dictionary
var guideBuff, samples, scales; // buffers (sound files and scales)
var synths=Dictionary.new; // temp dictionary of the synths symbolic IDs vs. server Nodes
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime
var key, current, next, syn, obj, age, mass; // object's properties
var win, info, buttons, stCurrNum, stCurrInfo, stNextNum, stNextInfo, timeLabel; // interface
var shade, count=0, animate=false; // schedule animation
var getKey, displayEventInfo, convertTime; // helper functions
var processEvents, groupNew, groupFree, taskPlay,
    sendObjCreate, sendSNew, sendParam, sendAct; // acting functions

// TO-DO:
// - change scales to weird ones!!
// - small depth (2 or 3) and reduced master volume!!
// - beep 2s prior to a new objects activity


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
    1: [(1, 3..9), ({rrand(5, 40)} ! 10)], // average
    2: [(1..3), ({rrand(30, 120)} ! 10)] // long (repeat)
);
msetObjSeq = MarkovSetN([], 2);
dictObjSeq.keysValuesDo{|k, v| msetObjSeq[k] = v[1]};

// fill buff with sample connected to guide object
guideBuff = Buffer.readChannel(~scsynth,
    PathName("~/Music/Sympli_Romatiko/solo/Audio/DRLATPOL.WAV").fullPath,
    channels: [0]);

samples = List.new; // fill samples
[
    "~/Music/Sympli_Romatiko/solo/Audio/bboxbeay2.wav",
    "~/Music/Sympli_Romatiko/solo/Audio/17boxloop.wav",
    "~/Music/Sympli_Romatiko/solo/Audio/BBOX75.WAV",
    "~/Music/Sympli_Romatiko/solo/Audio/BBOX90.WAV",
    "~/Music/Sympli_Romatiko/solo/Audio/loop_clean.wav"
].do { |f|
    samples.add(Buffer.readChannel(~scsynth, PathName(f).fullPath, channels: [0]));
};

scales = List.new; // fill scales
[
    FloatArray[0, 2, 3, 7, 9], // scales[0] is the main scale
    FloatArray[0, 1, 5, 6, 10] // the rest are specific to parts
].do { |a| scales.add(Buffer.sendCollection(~scsynth, a)) };

thePiece = (
    0: [
        (
            info: "Initial settings",
            message: \worldpar,
            params: [
                // Audio settings.
                audioIn: true, inbus: 20, fieldDepth: 4, confSurround: "Ambisonic2", master: 1,
                // Physics parameters.
                worldGrav: 0.98, worldMaxVel: 30, worldDamp: 0.01, starMass: 50, heavy: 6, initMass: 8,
                springStiff: 2, springDamp: 0.01, springLen: 0.1,
                repulsiveForce: 5, objAttract: false, worldForces: true,
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
    10: [
        (
            info: "Schedule Background Synths",
            message: \task, name: \scheduleBackgroundSynths, act: 1
        ),
    ],
    20: [
        (
            info: "INTRO: Particles",
            message: \worldpar, params: [particles: 1, partGuide: "object"]
        ),
        (
            message: \task, name: \randomParticles, act: 1
        ),
    ],
    30: [
        (
            info: "Schedule Boids",
            message: \task, name: \boids, act: 1
        )
    ],
    40: [
        (
            info: "Schedule objects",
            message: \task, name: \objects, act: 1
        )
    ],
    50: [
        (
            info: "Schedule granular waves",
            message: \task, name: \granWave, act: 1
        ),
    ],
    60: [
        (
            info: "FIN: Remove all",
            message: \worldact, action: \remove, objects: \all
        ),
        (
            info: "particles OFF",
            message: \worldpar, params: [particles: 0]
        ),
        (
            info: "Stop Boids",
            message: \task, name: \boids, act: 0
        ),
        (
            info: "Stop Objects",
            message: \task, name: \objects, act: 0
        ),
        (
            info: "Stop granular waves",
            message: \task, name: \granWave, act: 0
        )
    ]
);

// Store global params of the piece in a dictionary.
parmDir.putPairs(thePiece[0][0][\params]);

// Tasks dictionary.
task = (
    scheduleBackgroundSynths: Task({
        var key, next, syn, xfade, count=0;
        var backgrounds = #[ // allowed background synths
            \sr__e__lowe, \sr__e__humm, \sr__e__radio, \sr__e__noisy, \sr__e__pulse, \sr__e__wasp];
        loop {
            // Pick up a key and the number of iterations based on weighted choice
            // with extremely low probability of chosing short periods.
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 1, 10].normalizeSum);

            dictObjSeq[key.asInteger][0].choose.do {
                next = msetObjSeq.next(key);
                syn = backgrounds[count % backgrounds.size]; // alternate between synths

                // No gaps: next synth's "birth" spans over 1/3 of the current synths lifecycle.
                xfade = next * 0.5;

                // Send synth creation message.
                groupNew.(
                    (
                        message: \g_new,
                        id: \background_bundle,
                        params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                            ["/s_new", \sr__s__ambisonic2, \next_node_id, 1, \group_id, // add spatializer to new group's tail
                                \inbus, 12, // getting signal from synth
                                \outbus, 0], // to main output
                            ["/s_new", syn, \next_node_id, 0, \group_id, // add synth to new group's head
                                \outbus, 12, // feeding into spatilizer
                                \att, [0.5, xfade].wchoose([0.2, 0.8]), // allow for short attack sometimes
                                \velocity, 0.88, \bufnum, scales[1].bufnum],
                            ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.5, \mul, 1pi, \outbus, 0],
                            ["/n_map", \group_id, \azimuth, 0],
                            ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08,
                                \mul, (2.sqrt - 0.8) * 0.5, \add, 2.sqrt - ((2.sqrt - 0.8) * 0.5), // range 0.8..2.sqrt
                                \outbus, 1],
                            ["/n_map", \group_id, \distance, 1],
                            ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.4, \add, 0.6, \outbus, 2],
                            ["/n_map", \group_id, \velocity, 2],
                            ["/s_new", \sr__k__sin, \next_node_id, 0, \group_id, \freq, 0.01, \mul, 0.4, \add, 0.6, \outbus, 3],
                            ["/n_map", \group_id, \az, 3]
                        ]
                    ),
                );

                // Synth lifecycle.
                next.wait;

                // Long release;
                groupFree.(
                    (
                        message: \g_free,
                        id: \background_bundle,
                        params: [ \release, xfade ]
                    )
                );
                count = count + 1;
            };
            0.01.wait;
        }
    }),
    objects: Task({
        var key, next, syn, obj, age;
        var objects = #[ // allowed boids synths: 2 sets of synths that "work together well"
            [\sr__e__gauss, \sr__e__entro, \sr__e__ringz],
            [\sr__e__probe, \sr__e__melo, \sr__e__analog]
        ];
        loop {
            // Object's age: equal probability for all sequences
            key = msetObjSeq.dict.keys.asArray.choose;

            dictObjSeq[key.asInteger][0].choose.do{ |i|
                syn = objects.choose; // first choose set
                2.do {
                    "=== objects task: generating object!".postln;
                    next = msetObjSeq.next(key);

                    // Age spans over to the next object's birth - no gaps!
                    // The lighter objects the faster they die, but their population is denser.
                    age = next * (1 + (1/(next.pow(0.33))));

                    // Send object creation message.
                    sendObjCreate.(
                        (
                            message: \worldobj,
                            synth: (name: syn.choose, params: [\bufnum, scales[1].bufnum]),
                            object: (age: age, mass: parmDir[\heavy], type: "a RedObject")
                        )
                    );

                    // give a new object a chance to hang on another hand
                    0.1.wait;
                };
                next.wait;
            };
            0.01.wait;
        }
    }),
    boids: Task({
        var keyNext, keyAge, next, syn, obj, age;
        var boids = #[ // allowed boids synths
            \sr__e__cmb, \sr__e__melo, \sr__e__pulse, \sr__e__wasp];
        loop {
            // Boid's age: short and ave sequences are the most probable
            keyAge = msetObjSeq.dict.keys.asArray.sort.wchoose([10, 7, 0.01].normalizeSum);

            // Wait until next: long sequences are the most probable.
            keyNext = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 1, 10].normalizeSum);

            dictObjSeq[keyNext.asInteger][0].choose.do{ |i|
                next = msetObjSeq.next(keyNext);
                age = msetObjSeq.next(keyAge);

                syn = boids.choose; // choose boid synth at random
                mass = next.sqrt.clip(1, 3); // mass is sqrt propotion to life cycle

                // Send object creation message.
                sendObjCreate.(
                    (
                        message: \worldobj,
                        synth: (name: syn, params: [\bufnum, scales[1].bufnum]),
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
            [                           \partSigmoidRatio, 0.8, \partAgeThresh, 100,\partInitAccel, 0.1],
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
    granWave: Task({
        var buff, age, next=20;
        var introSynths = [\sr__g__loop, \sr__g__slic, \sr__g__drone, \sr__g__reg, \sr__g__gust];
        // Probablity of choosing a particular synth decreases towards the end of the list.
        var introSynthProb = Array.fill(introSynths.size, {exprand(0.01, 1.00)}).normalizeSum.sort.reverse;

        inf.do { |j|
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

            4.wait; // wait attack time (will overlap with wave a little)

            buff = samples[(j % samples.size).asInt]; // alternate between samples
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
                    rrand((timeprop * 0.1).max(0.01), timeprop * 0.4).wait
                };
            }.fork; // fork that "blast"

            sendAct.(\remove, \all); // remove all objects from the World
            taskPlay.(task[\objects], false); // stop objects creation

            rrand(120, 240).wait; // wait before starting objects again
            sendSNew.(
                (synth: (
                    name: \sr__e__signal,
                    params: [\distance, rrand(1, 2.sqrt), \azimuth, 1pi.rand2]
                    )
                ),
            );
            taskPlay.(task[\objects], true); // start objects creation again
            rrand(300, 900).wait; // wait before the next wave
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
    guideBuff.free;
    samples.do { |buff| buff.free};

    win.close;
});

// =================
// SYNTHS RE-DEFINED
SynthDef(\sr__e__analog, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, in, out, signal;
    var rq, azThresh=0.7;
    var freq, trig, timer, mul, add;
    // Conversion.
    mul = 2250; add = 2750;
    trig = velocity > 0.33; // high velocity causes sharp switch
    timer = Timer.kr(trig);
    freq = TRand.kr(trig:Delay2.kr(Dust.kr(1)));
    cutoff = SelectX.kr(BinaryOpUGen('<', cutoff, 0) * 2,
        [ // Positive cutoff falls at the freq range 500..5000
            TWChoose.kr((timer > 0.25) * trig,
                [
                    LFNoise0.ar(freq, mul, add),
                    LFNoise1.ar(freq, mul, add),
                    LFNoise2.ar(freq).clip2 * mul + add // quadratic interpolation can push beyond normal range of +-1
                ],
                [0.1, 0.3, 0.6]
            ),
            5666 // zero or negative cutoff means constant
        ]
    );
    rq = SelectX.kr(BinaryOpUGen('==', cutoff, 5666) * 2,
        [ // If cutoff is variable, RQ depends on distance.
            distance.linlin(0, 2.sqrt, 0.1, 1),
            0.1 // constant cutoff means constant RQ
        ]
    );
    note = SelectX.kr(BinaryOpUGen('<', az, azThresh) * 2,
        [   // Go melodic above height threshold.
            DegreeToKey.kr(bufnum, (az-azThresh).linlin(0, 1-azThresh, 0, 12), 12, 1, offset),
            az.linlin(0, azThresh, (offset-6), offset) // bottom to middle change continuously
        ]
    );
    // Synthesis.
    in = Mix.fill(8, {LFSaw.ar((note + 0.1.rand2).midicps)});
    in = FreeVerb.ar(
        RLPF.ar(RLPF.ar(in, cutoff, rq), cutoff, rq),
        distance, distance/3.44, 0.2
    );
    signal = Normalizer.ar(in, (amp * velocity).scurve);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;

SynthDef(\sr__e__gauss, {
    arg bufnum=0, inbus=30, outbus=20,
    amp=1, master=1, gate=1, att=1, rel=1, ca= -3, cr= -3,
    ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
    offset=36, cutoff=0;
    var note, scale, in, out, signal;
    var cutOff, rq, dur, width;
    // Conversion.
    cutOff = distance.linexp(0.0, 1.0, 10000, 200); // different from arg!
    rq = distance.linexp(0, 2.sqrt, 1, 0.2);
    dur = SinOsc.ar(LinExp.kr(az, 0.001, 1, 0.05, 5000) * [1, 1.1]).range(0.0006, 0.01);
    width = SinOsc.ar(0.5 * [1, 1.1]).range(0.01, 0.3);
    // Synthesis.
    in = LFGauss.ar(dur, width)
        + SinOsc.ar(az.linexp(0, 1, 0.01, 5000) * [1, 1.1],
            mul:(az.clip(0, 1) * velocity).sqrt); // sqrt boosts mul
    in = Mix.fill(10, in);
    in = Compander.ar(
        in, in, 0.002, slopeBelow: 0.33, slopeAbove: 0.5,
        clampTime: 0.01, relaxTime: 0.01,
        mul:(amp * velocity).scurve
    );
    signal = FreeVerb.ar(
        RLPF.ar(RLPF.ar(Mix.ar(in), cutOff, rq), cutOff, rq),
        distance, distance/3.44, 0.2
    );
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;


SynthDef(\sr__e__probe, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, in, out, signal;
    var rate=1, dtl=0.01, dtr=0.05;
    // Conversion.
    rate = (velocity * 5).max(0.5) * exprand(3, 8);
    note = DegreeToKey.kr(bufnum, az * 15, 24, 1, 15);
    // Synthesis.
    in = LPZ2.ar(
        LFPulse.ar(
            note.midicps, 2pi.rand, 0.1,
            (
                Mix.ar(SinOsc.ar(rate * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand])).abs
            )
        ),
        mul: (amp * velocity).scurve
    );
    2.do({in = AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2)});
    signal = FreeVerb.ar(Mix(in), distance, distance/3.44, 0.2);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;

SynthDef(\sr__e__signal, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var note, in, out, signal;
    // Conversion.
    note = DegreeToKey.kr(bufnum, az * 15, 24, 1, 15).midicps;
    // Synthesis.
    in = SinOsc.ar(550, mul:LFPulse.ar(1.8, 0, 0.6, 0.2));
    signal = RLPF.ar(
        CombL.ar(Mix.ar(in), 0.1, 0.03, 0.15),
        distance.linlin(0, 2.sqrt, 10000, 500), 0.5, mul: amp);
    //Envelope.
    out = signal * master * EnvGen.kr(Env.linen(0.01, 1.6, 0.01, 1, \welch), doneAction: 2);
    Out.ar(outbus, out);
}).add;

SynthDef(\sr__e__entro, {
    arg bufnum=0, inbus=30, outbus=20,
        amp=1, master=1, gate=1, att=1, rel=1, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth=0, distance=1, velocity=0.5,
        offset=36, cutoff=0;
    var freq, shift, rq, in, out, signal;
    var options, trig, timer;
    // Conversion.
    rq = distance.linlin(0, 2.sqrt, 0.2, 1);
    freq = velocity.linexp(0, 1, 20, 1000);
    shift = ((velocity ** 0.2 * 30) ** 3).lag(0.5); // boost velocity
    trig = velocity > 0.3;
    timer = Timer.kr(trig);
    in = TChoose.ar((timer > 0.25) * trig, [
        RLPF.ar(Normalizer.ar(LorenzL.ar(az.linlin(0, 1, 10, SampleRate.ir),
            LFNoise0.kr(1, 2, 10), r: LFNoise0.kr(1, 20, 38), b: LFSaw.kr(0.2).exp.cubed), 1),
            LFPulse.kr(LFSaw.ar(0.2).exp.cubed, 0.5, 2500, 3500),
            velocity * 0.5),
        Saw.ar((1..15) * LFNoise0.kr(5, 10, 50) + SinOsc.ar((6..2) * 0.5))
        ]
    );
    in = Mix.ar(in) * velocity * amp * 0.15; // too loud comparing to the rest, attenuate vol
    signal = RLPF.ar(RLPF.ar(in, shift, rq), shift, rq);
    //Envelope.
    out = signal * master * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);
    Out.ar(outbus, out);
}).add;
)