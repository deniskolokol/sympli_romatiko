// Sympli Romatikó
// module: Scheduler
// ---------------
(
var sequence; // main dictionary with the sequence of scheduled events and tasks
var param; // global params
var sGroupId; // root group
var defaultBuff;

// available SynthDefs
var trigSynth, synthNames, keyNames;

// dictionary of the synths symbolic IDs vs. server Nodes
var synths=Dictionary.new;

// object's properties
var key, current, next, syn, obj, age, mass, dummyParam, physics=();

// GUI
var win, seq, elapsed, keyboard, keyboardFunc, updateGui,
    stCurrNum, stCurrInfo, stNextNum, stNextInfo, timeLabel,
    slider, knob, button, buttonCheckbox, dropdown,
    panePar, pane, paneWidth, paneHeight, midiView, miscParams,
    seqFiles, seqPaths, seqPathsFile, seqMenu, openSequence, loadSequence;
var valAsApec;

// schedule animation
var shade, count=0, animate=false;

// helper functions
var getKey, eventInfo, convertTime, getIndex,
    fileNames, numChannels;

// acting functions
var groupNew, groupRemove, removeAll, taskPlay, stopAllTasks,
    sendAct, sendWorld, sendParticle, sendSNew, sendPhysics, sendAudio,
    switchEvent, processEvents;


// INITIAL
//
sequence=Dictionary.new;

// Group for synths.
sGroupId = s.nextNodeID;
s.sendMsg("/g_new", sGroupId);

// Keycodes for triggering obj creation with a synth.
trigSynth = [
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
    39, \sr__e__neural, // "
    42, \sr__e__analog, // \ (the answer to the ultimate question ))
];
synthNames = Dictionary.newFrom(trigSynth);
// TO-DO: names should be obtained automatically
keyNames = (12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y",
    32: "u", 34: "i", 31: "o", 35: "p", 33: "[", 30: "]",
    1:  "s", 2:  "d", 3:  "f", 5:  "g", 4:  "h", 38: "j", 40: "k",
    37: "l", 41: ";", 39: "\"", 42: "\\");

physics = (
    drag:             ( label: "drag",      minval: 0.000, maxval: 0.500, step: 0.001, default: 0.001, midicc: 24   ),
    repulsion:        ( label: "repulsion", minval: 1,     maxval: 100,   step: 5,     default: 100,   midicc: 25   ),
    starMass:         ( label: "star mass", minval: 0.1,   maxval: 5,     step: 0.1,   default: 1,     midicc: 26   ),
    gravX:            ( label: "grav X",    minval: -2.1,  maxval: 2.0,                default: 0,     midicc: 27   ),
    gravY:            ( label: "grav Y",    minval: -2.1,  maxval: 2.0,                default: 0,     midicc: 28   ),
    gravZ:            ( label: "grav Z",    minval: -2.1,  maxval: 2.0,                default: 0,     midicc: 29   ),
    partSigmoidRatio: ( label: "sigmoid",   minval: 0.3,   maxval: 0.9,                default: 0.7,   midicc: 34   ),
    partFreq:         ( label: "part freq", minval: 0.02,  maxval: 0.9,                default: 0.8,   midicc: 35   ),
    partAgeThresh:    ( label: "part age",  minval: 0.1,   maxval: 2,                  default: 0.84,  midicc: 36   ),
    partInitAccel:    ( label: "accel",     minval: 0.5,   maxval: 30,                 default: 5,     midicc: 14   ),
    springRestLen:    ( label: "rest len",  minval: 1,     maxval: 15,    step: 1,     default: 2,     midicc: 31   ),
    springStrength:   ( label: "strength",  minval: 0.1,   maxval: 2,                  default: 1,     midicc: 32   ),
    springDamp:       ( label: "damp",      minval: 0.1,   maxval: 2,                  default: 2,     midicc: 33   ),
    mutualAttraction: ( label: "mutual",                                               default: true,  midinote: 44 ),
    particles:        ( label: "particl",                                              default: false, midinote: 45 )
);
physics.keys.do { |key|
    physics[key][\gui] = nil; // GUI element that controls the parameter
};
miscParams = Dictionary.new;
dummyParam = (param: "<NONE>", minval: 0, maxval: 1, step: 0.01, default: 0);
valAsApec = { |param|
    param.atFail(\spec, {
        [
            param.atFail(\minval, {0}), param.atFail(\maxval, {1}),
            param.atFail(\warp, {\lin}),
            param.atFail(\step, {0}),
            param.atFail(\default, {0})
        ]
    }).asSpec
};

// Load sequence paths
if (~currentDir.isNil) {
    ~currentDir = PathName(thisProcess.nowExecutingPath).pathOnly
};
seqPathsFile = ~currentDir +/+ "seq.txt";
seqPaths = List.newFrom(["", "Load..."]);
try { // to load from settings file
    seqPaths = seqPaths ++ File(seqPathsFile, "r").readAllString.interpret;
};

defaultBuff = Buffer.loadCollection(s, FloatArray[0, 3, 7, 10]);

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


// local wrappers of messages to the World.
sendWorld = { |data| ~sendMessage.(data[\message], data[\params]) };

sendAudio = { |params| ~sendMessage.('/audio', params) };

sendAct = { |params| ~sendMessage.('/action', params) };

sendParticle = { |particle, synth| ~sendParticle.(particle, synth) };

sendPhysics = { |data|
    var params;
    params = Dictionary.newFrom(data[\params]);
    params.keysValuesDo { |k, v|
        if (v == \default) {
            params[k] = physics[k][\default]
        }
    };
    params = params.asKeyValuePairs;
    ~sendMessage.('/physics', params);
    updateGui.(params)
};

// Remove all objects from the World and release all synths
removeAll = {
    sendAct.([\remove, \all]);
    stopAllTasks.();
    synths.values.do { |node|
        groupRemove.((id: node))
    };
};


// Run or stop task.
taskPlay = { |task, play=false|
    task.postln;
    try {
        if (play) {
            task.play(doReset:true)
        } {
            task.stop.reset;
        }
    } { |err|
        postf("Error while trying to switch task % on or off:\n%\n", task, err);
    };
};


// Converts all event's [\info] keys into info string.
eventInfo = { |k=nil, lim=50|
    var infoStr, val, sF;
    val = sequence.events.atFail(k, {[]});
    sF = { |l| format(" %\n", if (l.size <= lim) {l} {l[..lim] ++ "..."})};
    infoStr = all{: sF.(l[\info].asString), l <- val, l.keys.includes(\info)};
    "".catList(infoStr)
};


// Converts timecode to readable format.
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
    format("%:%", minstring, secstring);
};


// Obtains index of val in container (list, array, etc.)
// WARNING! Quick and dirty, not universal!
getIndex = { |container, val|
    var ind;
    if (val.class == String) {
        container.do { |el, i| if (el == val) { ind = i } };
    } {
        ind = container.indexOf(val)
    };
    ind
};


stopAllTasks = {
    if (sequence.size > 0) {
        sequence.tasks.do { |task|
            taskPlay.(task, false)
        }
    }
};


// Loads sequence from file.
loadSequence = { |path|
    postf("Loading schedule %...\n", PathName.new(path).fileName);
    removeAll.();
    if (this.executeFile(path).isNil.not) {
        postf("OK\n\n");
        sequence = ~sequence;
        if (seqPaths.asString.contains(path).not) { // XXX
            seqPaths.insert(2, path); // to the top, but after ["", "Load.."]
        };
        getIndex.(seqPaths, path)
    } {
        postf("Not OK\n\n");
        try {
            seqPaths.removeAt(getIndex.(seqPaths, path));
        };
        0 // if unsuccessful, return 1st element ("")
    }
};


// Obtain the key next/prev to current.
getKey = { |current, next=1|
    var k, c;
    k = sequence.events.keys.asArray.asInteger.sort;
    c = k.indexOf(current) ? -1;
    k[c + next] ? k[0]; // Go back to beginning upon reaching the upper threshold.
};


// Get only filenames from sequence paths.
fileNames = { |paths|
    paths[..1] ++ paths[2..].collect({|a| PathName(a).fileName })
};


// Opens sequence from file.
openSequence = { |element|
    var val;
    animate = false;
    case
    { element.value == 1 } {
        Dialog.openPanel({ |path|
            val = loadSequence.(path); // XXX - shouldn't items be first?
            element.items = fileNames.(seqPaths); // XXX - update properly!
            element.value = val;
            win.name = format("sequence: %", PathName.new(path).fileName);
        });
    }
    { element.value > 1 } {
        val = loadSequence.(seqPaths[element.value]); // open from file
        element.value = val;
        win.name = format("sequence: %",
            PathName.new(seqPaths[element.value]).fileName
        );
    }
    { // otherwise
        win.name = "sequencing and scheduling";
    };

    current = -1;
    stNextNum.string = getKey.(current:current, next:1);
    stNextInfo.string = eventInfo.(0);
    timeLabel.string = convertTime.(0);
};

// Switches to the next or prev event in a sequence
// and updates GUI.
switchEvent = { |nxt=1|
    if (sequence.isNil.not) {
        if (sequence.size > 0) {
            stCurrNum.string = current = getKey.(current, nxt);
            stCurrInfo.string = eventInfo.(current);
            stNextNum.string = next = getKey.(current, 1);
            stNextInfo.string = eventInfo.(next);
            if (animate.not && (nxt > 0)) {animate = true}; // bring it on!

            processEvents.(current);
        }
    }
};


// Process specific key from sequence.
processEvents = { |key|
    sequence.events.atFail(key, {[]}).do { |d, l|
        d[\message].switch(
            \physics, { // send World parameter(s)
                sendPhysics.(d)
            },
            \audio, { // send audio parameter(s)
                sendAudio.(d[\params])
            },
            \task, { // launch/stop a task
                taskPlay.(sequence.tasks[d[\name]], d[\act].booleanValue)
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
                sendWorld.(d)
            }
        )
    }
};

// Figures out first output channel and total number of output channels.
numChannels = {
    var numCh;
    numCh = ~surround[~surround.size-1..].asInteger;
    if (numCh == 0) { ~surround[~surround.size-2..].asInteger };
    [~outbus, numCh]
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
dropdown = { |par, label, items, action, initVal=0, initAction=false, scale=1|
    var labelWidth=0;
    if (label.isNil.not) { labelWidth = label.size * 9};
    EZPopUpMenu(par,
        bounds: paneWidth.(par, scale)@20,
        label: label,
        items: items,
        globalAction: action,
        initVal: initVal,
        initAction: initAction,
        labelWidth: labelWidth
    )
    .font_(Font("Helvetica", 11));
};


win = Window("sequencing and scheduling", Rect(700, 800, 610, Window.screenBounds.height))
    .acceptsMouseOver_(true);
win.view.decorator = FlowLayout(win.view.bounds);

seq = CompositeView(win, (win.bounds.width-10)@165);
seq.decorator = FlowLayout(seq.bounds);

// current event's number and info
stCurrNum = StaticText(seq, 70@60).font_(Font("Monaco", 32))
    .background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stCurrInfo = StaticText(seq, 410@60).font_(Font("Monaco", 12))
    .background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));

// open file with sequence
pane = CompositeView(seq, 103@60);
pane.decorator = FlowLayout(pane.bounds);
StaticText(pane, (pane.bounds.width-10)@20).font_(Font("Monaco", 11))
    .stringColor_(Color.gray(0.2)).string_("Sequence");
// next (awaiting) event's number and info
stNextNum = StaticText(seq, 70@90).font_(Font("Monaco", 32))
    .background_(Color.grey(0.4)).stringColor_(Color.white);
stNextInfo = StaticText(seq, 410@90).font_(Font("Monaco", 14))
    .background_(Color.grey(0.4)).stringColor_(Color.white);
// time elapsed since the start
elapsed = CompositeView(seq, 103@90).background_(Color.grey(0.4));
elapsed.decorator = FlowLayout(elapsed.bounds);
timeLabel = StaticText(elapsed, elapsed.bounds.width@elapsed.bounds.height)
    .font_(Font("Monaco", 20)).stringColor_(Color.white)
    .string_(convertTime.(0));
// Warning! Order is important: pane first, then stNextNum and stNextInfo,
// then dropdown with sequence name (dropdown is placed on a pane,
// but its .action fills strings of stNextNum and stNextInfo)
seqFiles = fileNames.(seqPaths);
dropdown.(pane,
    items: seqFiles,
    initVal: if (seqFiles.size > 2) { 2 } { 0 },
    action: openSequence,
    initAction: true
);

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
        switchEvent.(-1)
    })
);
miscParams[\next] = (
    midinote: 43,
    gui: button.(pane, dummyParam, ">>", 0.6, 0.5).action_({ |bt|
        switchEvent.(1)
    })
);
miscParams[\removeall] = (
    midinote: 70,
    gui: button.(pane, dummyParam, "X", 0.6, 0.5).action_({ |bt| removeAll.() })
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
3.do { button.(pane, dummyParam, "<NONE>", 0.6, 0.5) };
miscParams[\record] = (
    midinote: 59,
    gui: buttonCheckbox.(pane, dummyParam, "REC", 0.6, 0.5).action_({ |bt|
        var dirname, filename;
        if (bt.value == 1) {
            dirname = ~currentDir +/+ "rec";
            if (File.type(dirname) == \not_found) {
                File.mkdir(dirname)
            };
            filename = dirname +/+ "sr__rec__0";
            PathName(dirname).filesDo { |fname|
                fname = fname.fileNameWithoutExtension;
                if ("sr__rec__[0-9]+".matchRegexp(fname)) {
                    if (File.type(dirname +/+ PathName(fname).nextName) == \not_found) {
                        filename = dirname +/+ PathName(fname).nextName;
                    }
                };
            };
            filename = filename ++ ".aif";
            s.recChannels = sum(numChannels.());
            s.recHeaderFormat = "AIFF";
            s.recSampleFormat = "int16";
            AppClock.sched(0, {
                fork { s.prepareForRecord(filename); s.sync; s.record }
                }
            );
        } {
            s.stopRecording
        }
    })
);
pane = CompositeView(panePar, paneWidth.(panePar, 0.2)@paneHeight.(panePar, 0.17));
physics[\particles][\gui] = buttonCheckbox.(pane, physics[\particles], \particles);

// KEYBOARD
keyboard = CompositeView(win, 600@170).background_(Color.grey(grey:0.7));
keyboardFunc = { |synthName, params, spring=0, mass=1|
    sendParticle.(
        synth: (name: synthName, params: params),
        particle: (spring:spring, mass:mass)
    );
};
keyboard.decorator = FlowLayout(keyboard.bounds);

trigSynth.do { |key, i|
    var view, buff;
    if (i % 2 == 0) {
        if (sequence.size > 0) {
            if (synthNames[key].asString.beginsWith("sr__e__")) {
                buff = sequence.scales[0]
            };
            if (synthNames[key].asString.beginsWith("sr__g__")) {
                buff = sequence.voices.choose
            };
        } {
            buff = defaultBuff
        };
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
        if ([0, 256].includes(modifiers)) {
            postf("window: left %, top %, width %, height %\n",
                win.bounds.left, win.bounds.top, win.bounds.width, win.bounds.height);
        }
    }
    { synthNames.keys.includes(keycode) } {
        if (modifiers == 131072) { // Shift + <key> - no spring
            keyboardFunc.(synthNames[keycode], spring:0)
        } {
            keyboardFunc.(synthNames[keycode], spring:1)
        }
    }
    { keycode == 7 && [0, 256].includes(modifiers) } { removeAll.() }
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
            elapsed.background = Color.grey(shade);
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
    try {
        seqPathsFile = File.new(seqPathsFile, "w");
        seqPathsFile.write(seqPaths[2..].asCompileString); // drop ["", "Load.."]
        seqPathsFile.close;
    };
    // Free buffers.
    MIDIIn.disconnect;
    win.close;
});
)
