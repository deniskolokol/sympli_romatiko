(
var sequence; // main dictionary with the sequence of scheduled tasks
var worldSize; // assume the World is a cube
var param, parmDir = Dictionary.new; // Global params of the piece dictionary.
var sGroupId; // root group
var receiver; // communication
var task; // tasks dictionary
var guideBuff, samples, scales, voices; // buffers (sound files and scales)
var trigSynth, synthNames, keyNames; // available SynthDefs
var synths=Dictionary.new; // temp dictionary of the synths symbolic IDs vs. server Nodes
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime
var key, current, next, syn, obj, age, mass, dummyParam, physics=(); // object's properties
var win, info, elapsed, keyboard, keyboardFunc, updateGui, // interface
    stCurrNum, stCurrInfo, stNextNum, stNextInfo,
    timeLabel, slider, knob, button, buttonCheckbox,
    panePar, pane, paneWidth, paneHeight, midiView, miscParams=();
var valAsApec;
var shade, count=0, animate=false; // schedule animation
var getKey, displayEventInfo, convertTime, clipInc; // helper functions
var processEvents, groupNew, groupRemove, taskPlay, sendWorld,
    sendParticle, sendSNew, sendPhysics, sendAudio, sendAct; // acting functions


// INITIAL
//
// Net Address and Port of the Receiver.
receiver = NetAddr.new("127.0.0.1", 57120);
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

samplesDir = "~/Music/Sympli_Romatiko/samples/";
samples = List.new;
voices = List.new;
PathName.new(samplesDir +/+ "drums").entries.do { |f, i|
    try { samples.add(Buffer.readChannel(s, f.fullPath, channels: [0])) }
};
PathName.new(samplesDir +/+ "voices").entries.do { |f, i|
    try { voices.add(Buffer.readChannel(s, f.fullPath, channels: [0])) }
};
guideBuff = Buffer.readChannel(s,
    PathName(samplesDir +/+ "drums/drumguide.wav").fullPath, channels: [0]
);


scales = List.new; // fill scales
[
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 1, 3, 7, 8], // the rest are specific to sequence's parts
    FloatArray[0, 2],
    FloatArray[0, 3],
    FloatArray[1, 3],
].do { |c, i|
    scales.add(Buffer.loadCollection(s, c));
};

trigSynth = [ // keycodes for triggering obj creation with a synth
    12, \sr__e__wasp,   // q
    13, \sr__e__radio,  // w
    14, \sr__e__humm,   // e
    15, \sr__e__gauss,  // r
    17, \sr__e__entro,  // t
    16, \sr__e__noisy,  // y
    32, \sr__e__probe,  // u
    34, \sr__e__cmb,    // i
    31, \sr__e__lowe,   // o
    35, \sr__e__melo,   // p
    33, \sr__e__ringz,  // [
    30, \sr__e__pulse,  // ]
    1,  \sr__g__reg,    // s
    2,  \sr__g__drone,  // d
    3,  \sr__g__gust,   // f
    5,  \sr__g__slic,   // g
    4,  \sr__g__loop,   // h
    38, \sr__g__scratch,// j
    40, \sr__g__unst,   // k
    37, \sr__g__chunk,  // l
    41, \sr__e__therem, // ;
    39, \sr__e__silent, // "
    42, \sr__e__analog, // \ (the answer to the ultimate question ))
];
synthNames = Dictionary.newFrom(trigSynth);
// TO-DO: names should be obtained automatically
keyNames = (12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y",
    32: "u", 34: "i", 31: "o", 35: "p", 33: "[", 30: "]",
    1:  "s", 2:  "d", 3:  "f", 5:  "g", 4:  "h", 38: "j", 40: "k",
    37: "l", 41: ";", 39: "\"", 42: "\\");

worldSize = 800;

physics = (
    drag: (label: "drag", minval: 0.000, maxval: 0.500, step: 0.001, default: 0.001, midicc: 24),
    repulsion: (label: "repulsion", minval: 1, maxval: 100, step: 5, default: 100, midicc: 25),
    starMass: (label: "star mass", minval: 0.1, maxval: 5, step: 0.1, default: 1, midicc: 26),
    gravX: (label: "grav X", minval: -2.1, maxval: 2.0, default: 0, midicc: 27),
    gravY: (label: "grav Y", minval: -2.1, maxval: 2.0, default: 0, midicc: 28),
    gravZ: (label: "grav Z", minval: -2.1, maxval: 2.0, default: 0, midicc: 29),
    partSigmoidRatio: (label: "sigmoid", minval: 0.3, maxval: 0.9, default: 0.7, midicc: 34),
    partFreq: (label: "part freq", minval: 0.02, maxval: 0.9, default: 0.8, midicc: 35),
    partAgeThresh: (label: "part age", minval: 0.1, maxval: 2, default: 0.84, midicc: 36),
    partInitAccel: (label: "accel", minval: 0.5, maxval: 30, default: 5, midicc: 14),
    springRestLen: (label: "rest len", minval: 1, maxval: 15, step: 1, default: 2, midicc: 31),
    springStrength: (label: "strength", minval: 0.1, maxval: 2, default: 1, midicc: 32),
    springDamp: (label: "damp", minval: 0.1, maxval: 2, default: 2, midicc: 33),
    mutualAttraction: (label: "mutual", default: true, midinote: 44),
    particles: (label: "particl", default: false, midinote: 45)
);
physics.keys.do { |key|
    physics[key][\gui] = nil; // GUI element that controls the parameter
};
dummyParam = (param: "<NONE>", minval: 0, maxval: 1, step: 0.01, default: 0);
valAsApec = { |param|
    param.atFail(\spec, {[
            param.atFail(\minval, {0}), param.atFail(\maxval, {1}),
            param.atFail(\warp, {\lin}),
            param.atFail(\step, {0}),
            param.atFail(\default, {0})
        ]}
    ).asSpec
};

sequence = ( );

// Store global params of the piece in a dictionary.
parmDir.putPairs(sequence[0][0][\params]);

// Tasks dictionary.
task = (
    randomParticles: Task({
        var key, next;
        var particleParams = [ // list of acceptable configurations
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.3, \partAgeThresh, 1.67, \partInitAccel, 10 ],
            [                           \partSigmoidRatio, 0.7, \partAgeThresh, 0.20, \partInitAccel, 30 ],
            [\partSynth, \sr__e__melo,  \partSigmoidRatio, 0.7, \partAgeThresh, 0.78, \partInitAccel, 2.0],
            [\partSynth, \sr__e__cmb,   \partSigmoidRatio, 0.4, \partAgeThresh, 0.20, \partInitAccel, 30 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.7, \partAgeThresh, 1.08, \partInitAccel, 8.0],
            [\partSynth, \sr__e__pulse, \partSigmoidRatio, 0.2, \partAgeThresh, 1.03, \partInitAccel, 20 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.2, \partAgeThresh, 1.67, \partInitAccel, 1.0],
        ];
        inf.do { |i|
            2.do { |j|
                key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.3, 0.6, 0.1]);
                next = msetObjSeq.next(key);
                next = (next + rand2(next * 0.25));
                sendPhysics.(
                    (message: \physics, params: particleParams[i % particleParams.size]),
                );
                next.wait;
            };
            0.01.wait;
        }
    }),

    // INTRO:
    // Picks up a key and the number of iterations randomly (average
    // sequences are the most probable, long are the least probable).
    //
    // A new particle's age spans over to the next object birth (no gaps).
    // The lighter the object the faster it dies, but demography is denser.
    //
    intro: Task({
        var key, next, synth, x, y, z, age, node;
        loop {
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 10, 1].normalizeSum);
            dictObjSeq[key.asInteger][0].choose.do{ |i|
                next = msetObjSeq.next(key);
                age = next * (1 + (1/(next.pow(0.33))));
                mass = next.sqrt.clip(0.1, 0.3);
                #x, y, z = (worldSize ! 3).rand;
                synth = (name: [\sr__e__humm, \sr__e__radio][i % 2], // alternate
                    params:[\att, rrand(1, 2), \bufnum, scales[4].bufnum]);
                sendParticle.(synth: synth, particle: (mass:mass, x:x, y:y, z:z, age:age));
                if (0.7.coin) {
                    synth = (name: [\sr__e__lowe, \sr__e__radio, \sr__e__humm].wchoose([0.6, 0.2, 0.2]));
                    sendParticle.(synth: synth, particle: (mass:mass, x:x, y:y, z:z,
                        age:age + ((age * 0.25).rand2)));
                };
                next.wait;
            };
            0.01.wait;
        }
    }),
    voices: Task({
        var buff, syn, age, x, y, z, prob=0.2;
        inf.do { |j|
            buff = voices[(j % voices.size).asInt];
            buff.postln;
            age = buff.numFrames / buff.numChannels / buff.sampleRate;
            #x, y, z = { rrand(worldSize, worldSize * ([0.1, 0.9].choose)) } ! 3;
            case
            // when voices are introduced, they should be clearly recognizable
            {j <= 5} { syn = \sr__g__loop }
            {(j > 5) && (j <= 10)} {syn = [\sr__g__loop, \sr__g__loopdel, \sr__g__unst].choose}
            {j > 10} {
                // later on "smooth them out" into a voice meshup
                // they should appear closer to the center of the world
                #x, y, z = { (worldSize / 2 + rand2(worldSize * 0.15))} ! 3;
                prob = 0.6; // bigger chance that the next sample will cross with the current one
                syn = [\sr__g__loop, \sr__g__unst, \sr__g__reg].wchoose([0.5, 0.3, 0.2]);
                // and occasionally send a light __scratch with the same sample and age
                if (0.3.coin) {
                    sendParticle.(
                        particle: (mass:0.1, x:x, y:z, z:z, age:age),
                        synth: (name:\sr__g__scratch, params:[\att, 3, \bufnum, buff.bufnum])
                    );
                };
            };
            // main "voice particle"
            sendParticle.(
                particle: (mass:0.5, x:x, y:z, z:z, age:age),
                synth: (name:syn, params:[\att, 2, \bufnum, buff.bufnum])
            );
            // vary waiting time - every now and then send the next particle
            // without waiting until the end of the sample
            if (prob.coin) { (age * 0.25).wait } { (age + rrand(4, 10)).wait }
        }
    }),
    sporadicAnalogCutoff: Task({
        var x, y, z;
        loop {
            x = (1.0.sum3rand * 100).abs + [100, 500].choose;
            #y, z = ({ (1.0.sum3rand * 150).abs + 100 } ! 2);
            sendParticle.(
                particle: (mass:0.6, x:x, y:z, z:z, age:rrand(3, 4)),
                synth: (name:\sr__e__analog, params:[\cutoff, -1, \att, 0.2, \rel, rrand(4, 6)])
            );
            (10 + 2.0.rand2).wait;
        }
    }),
    sporadicPulse: Task({
        loop {
            (20 + rand2(20 * 0.25)).wait;
            sendParticle.(
                particle: (age: rrand(2.7, 5.0), mass: 0.9, spring:[1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__pulse, params: [\att, 2, \rel, 3]));
            (20 + rand2(20 * 0.5)).wait;
        }
    }),
    sporadicCMB: Task({
        loop {
            sendParticle.(
                particle: (age: rrand(2, 5), mass: 0.9, spring: [1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__cmb, params: [\att, 1.5, \rel, 3]));
            (30 + rand2(30 * 0.25)).wait;
        }
    }),
    sporadicMelo: Task({
        loop {
            (20 + rand2(20 * 0.25)).wait;
            sendParticle.(
                particle: (age: rrand(5, 10), mass: 0.9, spring: [1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__melo, params: [\att, 1.5, \rel, 3, \bufnum, scales[0].bufnum]));
            ((20 + rand2(20 * 0.25))/2).wait;
        }
    }),
    switchScale: Task({
        var sca = scales[0..1];
        inf.do{ |i|
            s.sendMsg("/n_set", nil, \bufnum, sca[i % sca.size].bufnum);
            (1..3).choose.wait;
            s.sendMsg("/n_set", nil, \bufnum, nil);
            (60..120).choose.wait;
        }
    }),
    granWave: Task({
        var buff, age, timeprop, next=20;
        var introSynths = [\sr__g__loop, \sr__g__slic, \sr__g__drone, \sr__g__reg, \sr__g__gust];
        // Probablity of choosing a particular synth decreases towards the end of the list.
        var introSynthProb = Array.fill(introSynths.size, {exprand(0.01, 1.00)}).normalizeSum.sort.reverse;
        // WARNING!
        // For this particlular piece we play it only twice, instead of inf.do
        2.do{ |j|
            // Start fade-in synth before the wave.
            age = rrand(5, 8);
            sendParticle.(
                particle: (mass:0.5, spring:1, age:age),
                synth: (
                    name:introSynths.wchoose(introSynthProb),
                    params:[\att, 4, \rel, 3.0.rand, \bufnum, guideBuff.bufnum])
            );
            // Wait attack time with little overlap with a wave.
            4.wait;
            // Alternate between samples.
            buff = samples[(j % samples.size).asInt];
            {
                200.do { |i|
                    timeprop = (i / 199.0) ** 3;
                    sendSNew.(
                        (synth: (
                            name: \sr__u__grain,
                            params: [\bufnum, buff.bufnum, \busnum, audioThruBus[i % audioThruBus.size],
                                \rate, 1 + timeprop.rand2.pow(2), \pos, rrand(0.0, timeprop), \amp, exprand(0.05, 1.00)]
                            )
                        ),
                    );
                    rrand((timeprop * 0.1).max(0.01), timeprop * 0.4).wait
                };
            }.fork;
            rrand(20, 45).wait;
        }
    })
);

// Send synth to server.
sendSNew = { |data|
    var node;
    node = s.nextNodeID;
    try { // Ignore the case when doneAction = 2.
        synths.put(data[\synth][\id], node);
    };
    s.listSendMsg(["/s_new", data[\synth][\name], node, 0, sGroupId]
        ++ data[\synth].atFail(\params, {[]})
    );
};


// Sends bundle to server, places everything mentioned to the top level group.
// This is different from ~groupInit by allowing for an arbitrary number of
// synths and flexible group's structure.
groupNew = { |data, time=0.1|
    var node, messages;
    node = s.nextNodeID;
    messages = data[\params];
    messages.do { |l, i|
        l.do { |m, j| // replace keywords with node ids
            m.switch(
                \group_id, { messages[i][j] = node },
                \next_node_id, { messages[i][j] = s.nextNodeID }
            )
        }
    };
    messages = [["/g_new", node]] ++ messages; // add group creation
    s.listSendBundle(time, messages);
    synths.put(data[\id], node);
};


// Release all synths from group, wait until released, then remove group node from server.
groupRemove = { |data|
    var params=();
    try { params.putPairs(data.atFail(\params, {[]})) };
    ~groupFree.(synths[data[\id]], params.atFail(\release, {2}));
    synths.removeAt(data[\id]);
};


// Sends message to the World.
sendWorld = { |msg|
    receiver.sendBundle(0.01, msg);
};


// Sends particle creation message to the World:
// [create:1, node, spring:0|1, mass:9, x:470, y:300, z:250, age:inf]
// Returns Server node.
sendParticle = { |particle, synth|
    var node, spring, pos, x, y, z, age;
    pos = [particle.x, particle.y, particle.z];
    #x, y, z = Array.fill(pos.size, { |i| pos[i] ? worldSize.rand});
    node = ~groupInit.(synth[\name], ~surround, params:synth[\params]);
    sendWorld.(['/particle', 1, node, particle.atFail(\spring, {0}),
        particle.mass, x, y, z, particle.atFail(\age, {inf})]);
    node
};


// Sends parameter to the World.
sendPhysics = { |data|
    receiver.sendBundle(0.001, ['/physics'] ++ data[\params]);
    updateGui.(data[\params])
};


// Send audio parameters.
sendAudio = { |data|
    receiver.sendBundle(0.001, ['/audio'] ++ data[\params])
};


// Send action to the World.
sendAct = { |data|
    receiver.sendBundle(0.001, ['/action'] ++ data[\params])
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
    k = sequence.keys.asArray.asInteger.sort;
    c = k.indexOf(current) ? -1;
    k[c + next] ? k[0]; // Go back to beginning upon reaching the upper threshold.
};


// Increments integers with a limit: resets to `lo` every time in + step reaches `hi`.
clipInc = { |in=0, step=1, lo=0, hi=inf| ((in + step).clip(lo, hi) % hi).clip(lo, hi)};


// Convert all event's [\info] keys into info string.
displayEventInfo = { |k=nil, lim=50|
    var infoStr, val, sF;
    val = sequence.atFail(k, {[]});
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


// Process specific key from sequence.
processEvents = { |k=nil|
    var val = sequence.atFail(k, {[]});
    val.do { |d, l|
        d[\message].switch(
            \physics, { // send World parameter(s)
                sendPhysics.(d)
            },
            \audio, { // send audio parameter(s)
                sendAudio.(d)
            },
            \task, { // launch/stop a task
                taskPlay.(task[d[\name]], d[\act].booleanValue)
            },
            \particle, { // single object creation
                sendParticle.(particle:d[\particle], synth:d[\synth])
            },
            \s_new, { // send a new synth message directly to the server
                sendSNew.(d)
            },
            \n_set, { // send params directly to the synth on the server
                s.listSendMsg(["/n_set",
                    synths.at(d[\synth].atFail(\id), {nil})]
                    ++ d[\synth].atFail(\params, {[]})
                )
            },
            \g_new, { // send bundle to the server, place everything into the group
                groupNew.(d)
            },
            \g_free, { // release group
                groupRemove.(d)
            },
            { // default function
                sendWorld.(d[\params])
            }
        )
    }
};

// GUI.
//
paneWidth = { |par, scale=0.5| (par.bounds.width * scale - 6).floor };
paneHeight = { |par, scale=1| (par.bounds.height * scale - 10).floor };
slider = { |par, val, layout='horz', scale=1|
    var bounds = paneWidth.(par)@20;
    if (layout != 'horz') { bounds = 40@(paneHeight.(par) * scale) };
    EZSlider(par, bounds, val.atFail(\label, { val.param }), valAsApec.(val),
        { |ez| sendPhysics.((message: \physics, params: [val.param, ez.value])) },
        layout:layout)
    .font_(Font("Monaco", 12))
};
knob = { |par, val, param|
    EZKnob(par, paneWidth.(par,1)@100, val.atFail(\label, { param }), valAsApec.(val),
        { |ez| sendPhysics.((message: \physics, params: [param, ez.value])) })
    .font_(Font("Monaco", 12))
};
button = { |par, val, param, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH)).states_([
        [val.atFail(\label, { param }), Color.black, Color.white]
    ])
    .value_(val.atFail(\default, {0}).asInteger)
    .font_(Font("Monaco", 10))
    .canFocus_(false);
};
buttonCheckbox = { |par, val, param, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH)).states_([
        [val.atFail(\label, { param }), Color.black, Color.white],
        [val.atFail(\label, { param }), Color.white, Color.black]
    ])
    .value_(val.atFail(\default, {0}).asInteger)
    .action_({ |bt| sendPhysics.((message: \physics, params: [param, bt.value])) })
    .font_(Font("Monaco", 10))
    .canFocus_(false);
};

win = Window("sequencing and scheduling", Rect(700, 800, 610, Window.screenBounds.height))
    .acceptsMouseOver_(true);
win.view.decorator = FlowLayout(win.view.bounds);

info = CompositeView(win, 500@165);
info.decorator = FlowLayout(info.bounds);
stCurrNum = StaticText(info, 70@60).font_(Font("Monaco", 32))
    .background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stCurrInfo = StaticText(info, 410@60).font_(Font("Monaco", 12))
    .background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stNextNum = StaticText(info, 70@90).font_(Font("Monaco", 32))
    .background_(Color.grey(0.4)).stringColor_(Color.white);
stNextInfo = StaticText(info, 410@90).font_(Font("Monaco", 14))
    .background_(Color.grey(0.4)).stringColor_(Color.white);

elapsed = CompositeView(win, 85@150);
timeLabel = StaticText(elapsed, 85@80).font_(Font("Monaco", 18));

// MIDI interface (parameters)
midiView = CompositeView(win, 600@400);
midiView.decorator = FlowLayout(midiView.bounds);
// LEFT PANE
panePar = CompositeView(midiView, paneWidth.(midiView)@paneHeight.(midiView))
    .background_(Color.grey(grey:0.7));
panePar.decorator = FlowLayout(panePar.bounds);
// LEFT PANE LEFT SIDE
pane = CompositeView(panePar, paneWidth.(panePar, 0.33)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
[\drag, \repulsion, \starMass].do { |key|
    physics[key][\gui] = knob.(pane, physics[key], key);
};
pane = CompositeView(panePar, paneWidth.(panePar, 0.17)@paneHeight.(panePar, 0.85));
miscParams[\serverVolume] = (
    midicc: 12, spec: \db,
    gui: slider.(pane, (param: "s.vol", label: "s.vol", spec: \db), \vert)
               .action_({ |sl| s.volume.volume = sl.value })
               .value_(1)
);
// LEFT PANE RIGHT SIDE
pane = CompositeView(panePar, paneWidth.(panePar, 0.33)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
[\gravX, \gravY, \gravZ].do { |key|
    physics[key][\gui] = knob.(pane, physics[key], key);
};
pane = CompositeView(panePar, paneWidth.(panePar, 0.17)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
slider.(pane, dummyParam, \vert);
// LEFT PANE BOTTOM
pane = CompositeView(panePar, paneWidth.(panePar, 0.8)@paneHeight.(panePar, 0.17));
pane.decorator = FlowLayout(pane.bounds);
miscParams[\prev] = (
    midinote: 46,
    gui: button.(pane, dummyParam, "<<", 0.6, 0.5).action_({ |bt|
        stCurrNum.string = current = getKey.(current, -1);
        stCurrInfo.string = displayEventInfo.(current);
        stNextNum.string = next = getKey.(current, 1);
        stNextInfo.string = displayEventInfo.(next);
        processEvents.(current);
    })
);
miscParams[\next] = (
    midinote: 43,
    gui: button.(pane, dummyParam, ">>", 0.6, 0.5).action_({ |bt|
        if (animate.not) {animate = true}; // bring it on!
        stCurrNum.string = current = getKey.(current);
        stCurrInfo.string = displayEventInfo.(current);
        stNextNum.string = next = getKey.(current, 1);
        stNextInfo.string = displayEventInfo.(next, 50);

        processEvents.(current);
    })
);
miscParams[\removeall] = (
    midinote: 70,
    gui: button.(pane, dummyParam, "X", 0.6, 0.5).action_({ |bt|
        sendWorld.([\action, \remove, \all]);
    })
);
miscParams[\reset] = (
    midinote: 58,
    gui: button.(pane, dummyParam, "RESET", 0.6, 0.5).action_({ |bt|
        physics.values.do { |element|
            if (element.keys.includes(\midicc) && element[\gui].isNil.not) {
                element[\gui].valueAction_(element[\default])
            }
        }
    })
);
pane = CompositeView(panePar, paneWidth.(panePar, 0.2)@paneHeight.(panePar, 0.17));
physics[\mutualAttraction][\gui] = buttonCheckbox.(
    pane, physics[\mutualAttraction], \mutualAttraction
);

// RIGHT PANE
panePar = CompositeView(midiView, paneWidth.(midiView)@paneHeight.(midiView))
    .background_(Color.grey(grey:0.7));
panePar.decorator = FlowLayout(panePar.bounds);
// RIGHT PANE LEFT SIDE
pane = CompositeView(panePar, paneWidth.(panePar, 0.33)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
[\partSigmoidRatio, \partFreq, \partAgeThresh].do { |key|
    physics[key][\gui] = knob.(pane, physics[key], key);
};
pane = CompositeView(panePar, paneWidth.(panePar, 0.17)@paneHeight.(panePar, 0.85));
physics[\partInitAccel][\gui] = slider.(pane, physics[\partInitAccel], \vert);

// RIGHT PANE RIGHT SIDE
pane = CompositeView(panePar, paneWidth.(panePar, 0.33)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
[\springRestLen, \springStrength, \springDamp].do { |key|
    physics[key][\gui] = knob.(pane, physics[key], key);
};
pane = CompositeView(panePar, paneWidth.(panePar, 0.17)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
param = (param: "depth", minval: 1, maxval: 10, step: 0.1, default: 5);
miscParams[\depth] = (
    midicc: 15, minval: param[\minval], maxval: param[\maxval], step: param[\step],
    gui: slider.(pane, param, \vert)
    .action_({ |ez|
        ~depth = ez.value;
        sendAudio.((params: [\depth, ~depth]));
    })
);
// RIGHT PANE BOTTOM
pane = CompositeView(panePar, paneWidth.(panePar, 0.8)@paneHeight.(panePar, 0.17));
pane.decorator = FlowLayout(pane.bounds);
4.do { button.(pane, dummyParam, "<NONE>", 0.6, 0.5) };
pane = CompositeView(panePar, paneWidth.(panePar, 0.2)@paneHeight.(panePar, 0.17));
physics[\particles][\gui] = buttonCheckbox.(pane, physics[\particles], \particles);

// KEYBOARD
keyboard = CompositeView(win, 600@170).background_(Color.grey(grey:0.7));
keyboardFunc = { |synthName, params, spring=0, mass=1|
    sendParticle.(
        synth: (name: synthName, params: params),
        particle: (spring:spring, mass:mass));
};
keyboard.decorator = FlowLayout(keyboard.bounds);
trigSynth.do { |key, i|
    var view, buff;
    if (i % 2 == 0) {
        if (synthNames[key].asString.beginsWith("sr__e__")) { buff = scales.choose };
        if (synthNames[key].asString.beginsWith("sr__g__")) { buff = voices.choose };
        view = CompositeView(keyboard, 45@70);
        view.decorator = FlowLayout(view.bounds);
        Button(view, 41@45).states_(
            [[keyNames[key].toUpper, Color.black, Color.white]])
        .canFocus_(false)
        .action_({ |bt| keyboardFunc.(synthNames[key], params: [\bufnum, buff.bufnum], spring:1) });
        StaticText(view, 41@25).string_(
            synthNames[key].asString.replace("sr__e__", "").replace("sr__g__", ""))
        .align_(\topLeft)
        .font_(Font("Monaco", 12))
        .stringColor_(Color.white);
    };
};
win.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    //[char, modifiers, unicode, keycode].postln;
    case
    { keycode == 6 } { // Z - info
        if( [0, 256].includes(modifiers), {
            postf("window: left %, top %, width %, height %\n",
                win.bounds.left, win.bounds.top, win.bounds.width, win.bounds.height);
        });
    }
    { keycode == 7 && [0, 256].includes(modifiers) } { sendWorld.([\action, \remove, \all]) }
    { synthNames.keys.includes(keycode) } {
        modifiers.switch(
            0, { keyboardFunc.(synthNames[keycode], spring:1) },
            256, { keyboardFunc.(synthNames[keycode], spring:1) },
            131072, { keyboardFunc.(synthNames[keycode], spring:0) } // Shift + <key> - no spring
        )
    }
};

// Updates value of a GUI element upon sending a message to the world.
// Sets .value, not .valueAction, because the action is performed already.
updateGui = { |params|
    params.pairsDo { |parm, val|
        try { physics[parm][\gui].value_(val) }
    }
};


{ // GLOBAL APP CLOCK. Resolution: 100 milliseconds (0.1 of a second)
    while {win.isClosed.not} {
        if (animate) {
            count = count + 1;

            // blinking "next event" info.
            shade = (count % 8) * 0.1;
            stNextNum.background = Color.grey(shade);
            stNextInfo.background = Color.grey(shade);
            timeLabel.string = convertTime.(count / 10);
            win.refresh;

            if (count % 10 == 0) {
                // XXX
                // process timemarks
            };
        };
        0.1.wait;
    }
}.fork(AppClock);

win.front;

// physics and miscellaneous parameters controlled by MIDI
MIDIIn.connectAll;
(physics.values ++ miscParams.values).do { |element|
    if (element.keys.includes(\midicc) && element[\gui].isNil.not) {
        MIDIFunc.cc({ |val, ccNum, chan, srcID|
            {
                element[\gui].valueAction_(
                    valAsApec.(element).map(\midinote.asSpec.unmap(val))
                )
            }.defer;
        }, element[\midicc], 0);
    };
    if (element.keys.includes(\midinote) && element[\gui].isNil.not) {
        MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
            {
                element[\gui].valueAction_(1 - element[\gui].value)
            }.defer;
        }, element[\midinote], 0);
    }
};

CmdPeriod.doOnce({
    // Free buffers.
    guideBuff.free;
    samples.do { |buff| buff.free};
    scales.do  { |buff| buff.free};
    voices.do  { |buff| buff.free};
    MIDIIn.disconnect;
    win.close;
});
)
