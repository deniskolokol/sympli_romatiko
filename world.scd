// Sympli Romatikó
// module: World
// ---------------
(
var world, worldTrace, center, skel;
var miscParams;
var star, physics, particles, springs;
var oscParticle, oscPhysics, oscAction,
    oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost,
    oscGroupTree;
var initParticle, removeParticle, removeAll,
    registerParticle, unregisterParticle, particleSystem,
    applyAttractions, removeAttraction, handleBoundaryCollisions,
    registerSpring, registerSprings, applySpring, removeSpring,
    getSpringForParticle, setSpringProp;
var resolveSpringEnd, decodeParticle;
var skeleton, skeletonParticles, skeletonRemove,
    defineGuide, getGuide, defineSource, chooseSource,
    jointVisible, springSrcSkel;
var getParticlesOnSprings, getParticlesSkelVis, getParticlesHidden;
var mag3D, sigmoid, xyz, xyz2ade, ade2xyz, xyz2plane;
var ax, ay, az, azimuth, distance, elevation,
    guide, gx, gy, gz,
    gAzimuth, gDistance, gElevation;
var attractionsPhysical, springsPhysical, springMissed,
    particlesOnSprings, particlesSkelVis, particlesHidden,
    partColor, partSize;
var listenerPos, currSpeaker, getSynthName;
var win, viewTop, viewSeqList, viewTopCenter, viewSeqTime,
    viewWorld, viewConn, viewLeft, viewRight, viewBottom,
    winSrvBottomLeft, winSrvBottomRight, viewSeqEvents,
    paneWidth, paneHeight, compView, compViewFlow, panel,
    sText, dropdown, listView, slider, knob, button, buttonCheckbox,
    updateButtonLabel;
var winSrv, palette, meterView, srvTreeView;
var postView, postMaxSize=25000;
var scale, translate, focal;
var paramsChanged;
var cleanExit;
var trigSynth, synthNames, trigCodes;
var fileNames;
var postMsg, updatePostColors, getMsgColor, postColors=List.new;
var eventInfo, switchEvent, processEvents, getKey;
var groupNew, groupRemove, sendPhysics, sendSNew, sendNSet, taskPlay;
var animateSeq, shade, current, next, count=0, blinked=0, tick=0;
var ddSequence, btCurrNum, stCurrInfo, btNextNum, stNextInfo, timeLabel, updateGui;
var transparent=Color.grey(alpha:0.01),
    font=Font("Monaco", 14),
    fontSmall=Font("Monaco", 10),
    fontMedium=Font("Monaco", 12),
    fontLarge=Font("Monaco", 14),
    fontLarge1=Font("Monaco", 18),
    fontGiant=Font("Monaco", 24),
    fontColor=Color.gray(0.7);
var waitNextEvent= -1;
var tmp;

// INITIAL
//
// dictionary of the synths symbolic IDs vs. server Nodes
var synths = Dictionary.new;

// XXX - re-factor
// `physics` -> `world`::`EnTraerWorld`(TraerParticleSystem) // EnTraer == Entropia of Traer Physics
// all functions that work with particles and springs -> methods of `world`
//
//
var worldParams = (
    drag: (
        label: "drag",
        minval: 0.000,
        maxval: 0.500,
        step: 0.001,
        default: 0.001,
        midicc: 24,
    ),
    repulsion: (
        label: "repulsion",
        minval: 1,
        maxval: 100,
        step: 5,
        default: 100,
        midicc: 25,
    ),
    maxVel: (
        label: "max vel",
        minval: 0.5,
        maxval: 10,
        step: 0.1,
        default: 5,
    ),
    starMass: (
        label: "star mass",
        minval: 0.1,
        maxval: 5,
        step: 0.1,
        default: 1,
        midicc: 26,
    ),
    gravX: (
        label: "grav X",
        minval: -2.1,
        maxval: 2.0,
        default: 0,
        midicc: 27,
    ),
    gravY: (
        label: "grav Y",
        minval: -2.1,
        maxval: 2.0,
        default: 0,
        midicc: 28,
    ),
    gravZ: (
        label: "grav Z",
        minval: -2.1,
        maxval: 2.0,
        default: 0,
        midicc: 29,
    ),
    // springs
    springRestLen: (
        label: "rest len",
        minval: 1,
        maxval: 15,
        step: 1,
        default: 2,
        midicc: 31,
    ),
    springStrength: (
        label: "strength",
        minval: 0.1,
        maxval: 2,
        default: 1,
        midicc: 32,
    ),
    springDamp: (
        label: "damp",
        minval: 0.1,
        maxval: 2,
        default: 2,
        midicc: 33,
    ),
    // particles
    particles: (
        label: "particl",
        default: false,
        midinote: 45,
        hint: "run particles",
    ),
    partSigmoidRatio: (
        label: "sigmoid",
        minval: 0.3,
        maxval: 0.9,
        default: 0.7,
        midicc: 34,
        hint: "steepness of sigmoid function determiming probability of particle being born",
    ),
    partAgeThresh: (
        label: "part age",
        minval: 0.1,
        maxval: 2,
        default: 0.84,
        midicc: 36,
        hint: "maximum particle age in cycles (sec)",
    ),
    partInitAccel: (
        label: "part accel",
        minval: 0.5,
        maxval: 30,
        default: 5,
        hint: "particle initial acceleration",
    ),
    partDefaultMass: (
        label: "part mass",
        minval: 0.1,
        maxval: 1,
        default: 0.5,
    ),
    partFreq: (
        label: "part freq",
        minval: 0.02,
        maxval: 0.9,
        default: 0.8,
        midicc: 35,
        hint: "generate new particle \partFreq times per second",
    ),
    partSynth: (
        label: "part synth",
        default: \sr__e__pulse,
    ),
    mutualAttraction: (
        label: "mutual",
        default: true,
        midinote: 44,
    ),
    calibration: (
        label: "calibr",
        default: true,
        midinote: 69,
        hint: "display image if in calibration mode",
    ),
    internalBuf: (
        label: "internal buf",
        default: false,
        hint: "granular synths use internal buffer instead of samples",
    ),
);

// The World is a cube with measurements relative to the screen height.
tmp = (Window.screenBounds.height*0.623).floor;
world = (width: tmp, height: tmp, depth: tmp);
worldParams.keysValuesDo { |k, v| world[k] = v[\default] }; // set default params

worldTrace = Dictionary.newFrom(world); // tracing changes of the world

// skeletons
skel = (waitBeforeRemove: 5, limit: 1);
skeleton = Dictionary.new;
jointVisible = [ // visualize only these joints
    \l_hand, \l_elbow, \l_shoulder, \neck, \head, \neck, \r_shoulder, \r_elbow, \r_hand
];
springSrcSkel = #[\r_hand, \l_hand]; // joints that springs can be attached to
listenerPos = ( // as default - center of the world
    x: world.width * 0.5,
    y: world.height * 0.5,
    z: world.depth * 0.5
);

// Keycodes for triggering obj creation with a synth.
trigCodes = [
    12, "q", 13, "w", 14, "e", 15, "r", 17, "t", 16, "y",
    32, "u", 34, "i", 31, "o", 35, "p", 33, "[", 30, "]",
    1,  "s", 2,  "d", 3,  "f", 5,  "g", 4,  "h", 38, "j", 40, "k",
    37, "l", 41, ";", 39, "\"", 42, "\\", 47, "\?"
];

// collect keys and synths in a form of dict, unsorted
synthNames = Dictionary.newFrom(
    (all {: [~synths[k][\key], k],
        k <- ~synths.keys,
        trigCodes.includes(~synths[k][\key])
    }).flatten
);

// sort it according to the order of elements in trigCodes
trigSynth = (
    all {: [key, synthNames[key]],
        key <- all{: k, k <- trigCodes, trigCodes.indexOf(k).even}
    }
).flatten;

// convert trigCodes to dictionary for easier access
trigCodes = Dictionary.newFrom(trigCodes);

fileNames = { |paths|
    // Get only filenames from sequence paths.
    paths[..1] ++ paths[2..].collect({ |path|
        PathName(path.asString.asAbsolutePath).fileName;
    });
};

// Miscelaneous parameters for GUI elements controllable by MIDI.
miscParams = Dictionary.new;

updateGui = { |params|
    // Updates value of a GUI element upon sending a message to the world.
    // Sets .value, not .valueAction, because the action is performed already.
    params.pairsDo { |parm, val|
        try { worldParams[parm][\gui].value_(val) }
    }
};

// SEQUENCE
//
getKey = { |curr, next=1|
    // Obtain the key next/prev to current.
    var k, c;
    k = ~sequence.events.keys.asArray.asInteger.sort;
    c = k.indexOf(curr) ? -1;
    k[c + next] ? k[0]; // Go back to beginning upon reaching the upper threshold.
};

eventInfo = { |k=nil, lim=50|
    // Converts all event's [\info] keys into info string.
    var infoStr, val, sF;
    val = ~sequence.events.atFail(k, {[]});
    sF = { |l| format(" %\n", if (l.size <= lim) {l} {l[..lim] ++ "..."})};
    infoStr = all{: sF.(l[\info].asString), l <- val, l.keys.includes(\info)};
    infoStr = "".catList(infoStr);
    infoStr[..(infoStr.size-2)]; // cut last \n
};

updateButtonLabel = { |btn, label|
    // Sets a label to a button in a current state.
    var states=btn.states;
    states[btn.value][0] = label;
    btn.states = states;
};

switchEvent = { |nxt=1|
    // Switches to the next or prev event in a sequence
    // and updates GUI.
    var wait;
    if (~sequence.isNil.not) {
        if (~sequence.size > 0) {
            current = getKey.(current, nxt);
            updateButtonLabel.(btCurrNum, current);
            stCurrInfo.string = eventInfo.(current);
            if (current == 0) { count = 0 }; // reset clock

            next = getKey.(current, 1);
            updateButtonLabel.(btNextNum, next);
            stNextInfo.string = eventInfo.(next);

            // bring it on!
            blinked = 0; // blinking several times with red, then change to grey.
            if (animateSeq.not && (nxt > 0)) { animateSeq = true };
            processEvents.(current);

            // reset waiting time globally
            waitNextEvent = -1;
            wait = List.new;
            ~sequence.events[current].do { |msg|
                wait.add(msg.atFail(\wait, {-1}))
            };
            // update waiting time until the next event
            waitNextEvent = wait.maxItem;
            postMsg.(format("INFO: Waiting time for next event: %\n", waitNextEvent));
        }
    }
};

sendPhysics = { |params|
    // Send World parameter(s).
    params = Dictionary.newFrom(params);
    params.keysValuesDo { |k, v|
        if (v == \default) { params[k] = worldParams[k][\default] }
    };
    params = params.asKeyValuePairs;
    ~sendMessage.('/physics', params);
    updateGui.(params)
};

taskPlay = { |task, play=false|
    // Run or stop task.
    try {
        if (play) {
            task.play(doReset:true)
        } {
            task.stop.reset;
        }
    } { |err|
        postMsg.(format("ERROR: cannot switch task % on or off:\n%\n", task, err));
    };
};


sendSNew = { |data|
    // Sends synth to server, registers node in `synths`.
    var node = ~initSynth.(data[\name], params: data[\params]);
    synths.put(data[\id], node);
};


sendNSet = { |data|
    // Sends \n_set message to server.
    ~scsynth.listSendMsg(["/n_set",
        synths.at(data[\synth].atFail(\id), {nil})]
    ++ data[\synth].atFail(\params, {[]})
    )
};

groupNew = { |data, time=0.1|
    // Sends group to server, registers node in `synths`.
    var node = ~initGroup.(data, time);
    synths.put(data[\id], node);
};

groupRemove = { |data|
    // Release all synths from group, wait until released,
    // then remove group node from server.
    var params=();
    try { params.putPairs(data.atFail(\params, {[]})) };
    ~groupFree.(synths[data[\id]], params.atFail(\release, { 1 }));
    synths.removeAt(data[\id]);
};


processEvents = { |key|
    // Process specific key from sequence.
    ~sequence.events.atFail(key, {[]}).do { |d, l|
        d[\message].switch(
            \physics, {
                sendPhysics.(d[\params])
            },
            \audio, {
                ~sendMessage.('/audio', d[\params])
            },
            \particle, {
                ~sendParticle.(d[\particle], d[\synth])
            },
            \task, {
                taskPlay.(~sequence.tasks[d[\name]], d[\act].booleanValue)
            },
            \s_new, { sendSNew.(d) },
            \n_set, { sendNSet.(d) },
            \g_new, { groupNew.(d) },
            \g_free, { groupRemove.(d) },
            { ~sendMessage.(d[\message], d[\params]) }
        )
    }
};


// GUI: elements
paneWidth = { |par, scale=1| (par.bounds.width * scale - 6).floor };
paneHeight = { |par, scale=1| (par.bounds.height * scale - 6).floor };
compView = { |par, color, scaleW=1, scaleH=1|
    CompositeView(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH)
    ).background_(color ? transparent);
};
compViewFlow = { |par, color, margin, gap, scaleW=1, scaleH=1|
    var vw;
    vw = compView.(par, color, scaleW, scaleH);
    vw.decorator = FlowLayout(vw.bounds, margin ? 1@1, gap ? 1@1);
    vw
};
sText = { |par, string, stringColor, stringFont, scaleH, scaleW=0.5|
    var st, height;
    if (scaleH.isNil) {
        // height = st.sizeHint.height.max(20); // XXX - how to do that before creation of StaticText?
        height = 20;
    } {
        height = paneHeight.(par, scaleH);
    };
    st = StaticText(par, paneWidth.(par, scaleW)@height);
    st.string = string;
    st.font = stringFont ? font;
    st.stringColor = stringColor ? fontColor;
    st
};
listView = { |par, items, action, initVal=0, scaleH=1, scaleW=1|
    var labelWidth=0, listView;
    listView = ListView(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .items_(items)
    .action_(action)
    .font_(fontMedium)
    .background_(transparent)
    .stringColor_(fontColor)
    .hiliteColor_(Color.grey(alpha:0.6))
    .selectedStringColor_(Color.white);
    listView
};
dropdown = { |par, label, items, action, initVal=0, initAction=false, scale=1|
    var ezpum, labelWidth=0;
    if (label.isNil.not) { labelWidth = label.size * 9};
    ezpum = EZPopUpMenu(par,
        bounds: paneWidth.(par, scale)@20,
        label: label,
        items: items,
        globalAction: action,
        initVal: initVal,
        initAction: initAction,
        labelWidth: labelWidth
    )
    .font_(font);
    ezpum.setColors(
        stringBackground:transparent,
        stringColor:fontColor,
        menuBackground: transparent,
        menuStringColor:fontColor,
        background:transparent
    );
    ezpum
};
button = { |par, label, labelColor, bgColor, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .states_([[label, labelColor ? fontColor, bgColor ? transparent]])
    .font_(fontMedium)
    .canFocus_(false)
};
buttonCheckbox = { |par, label, labelColor, bgColor, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .states_([
        [label, labelColor ? fontColor, bgColor ? transparent],
        [label, bgColor ? transparent, labelColor ? fontColor]
    ])
    .font_(fontMedium)
    .canFocus_(false)
};
slider = { |par, name, val, layout='horz', scale=1|
    var ezs, label, bounds;
    bounds = paneWidth.(par)@20;
    label = format(" % ", val.atFail(\label, { name }).asString);
    if (layout != 'horz') { bounds = 40@(paneHeight.(par) * max(scale, 0.9)) };
    ezs = EZSlider(par, bounds, label, ~valAsApec.(val),
        { |ez| ~sendMessage.('/physics', [name, ez.value]) },
        layout:layout, labelWidth:80, numberWidth:40)
    .font_(fontSmall);

    ezs.setColors(
        stringColor:fontColor,
        sliderBackground:Color.black,
        numBackground:Color.grey(alpha:0.5),
        numNormalColor:fontColor,
        background:transparent
    );
};
knob = { |par, label, spec, action, initVal=0, layout='vert', scaleW=1, scaleH=1|
    EZKnob(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH),
        label, spec,
        { |ez| action.(ez.value) }, initVal,
        layout: layout
    )
    .font_(fontSmall)
    .setColors(subtract(par.background, par.background.alpha));
};

// GUI: Server window
winSrv = Window.new(
    ~scsynth.name ++ " levels (dBFS)",
    Rect(0, Window.screenBounds.height-200, 590, 660),
    resizable: false, border: false
);
winSrv.view.decorator = FlowLayout(winSrv.view.bounds, 1@1, 1@1);
palette = QPalette.dark;
palette.setColor(Color.black, \window);
winSrv.view.palette = palette;
// internal levels
panel = compViewFlow.(winSrv, scaleH:0.3, scaleW:0.57);
meterView = EntroServerMeterView(~scsynth, panel, 0@0, 210);

// GUI: sequence panel
panel = compViewFlow.(winSrv, scaleH:0.3, scaleW:0.43);
viewSeqList = compViewFlow.(panel, scaleH:0.25, scaleW:0.65);
viewSeqTime = compViewFlow.(panel, margin:5@5, gap:5@5, scaleH:0.25, scaleW:0.35);
viewSeqEvents = compViewFlow.(panel, gap:8@4, scaleH:0.63);
// time elapsed since the start
timeLabel = sText.(viewSeqTime, ~convertTime.(0), stringFont:fontLarge1, scaleW:1, scaleH:0.7);
timeLabel.align = \center;
// current event number and info
btCurrNum = button.(viewSeqEvents, ">>", bgColor:Color.gray(0.15), scaleH: 0.55, scaleW: 0.15)
.action_({ |bt| switchEvent.(-1) });
stCurrInfo = sText.(viewSeqEvents, "...", stringFont:fontLarge, scaleH:0.55, scaleW:0.85);
// next (awaiting) event number and info
btNextNum = button.(viewSeqEvents, "<<", bgColor:Color.gray(0.15), scaleH: 0.55, scaleW: 0.15)
.action_({ |bt| switchEvent.(1) });
stNextInfo = sText.(viewSeqEvents, "", stringFont:fontLarge, scaleH:0.55, scaleW:0.85);
miscParams[\prev] = (
    midinote: 46,
    gui: btCurrNum
);
miscParams[\next] = (
    midinote: 43,
    gui: btNextNum
);
// open file with sequence
ddSequence = dropdown.(
    viewSeqList,
    items: fileNames.(~seqPaths),
    initVal: if (~seqPaths.size > 2) { 2 } { 0 },
    action: { |element|
        var val, path, top=2;
        animateSeq = false;
        case
        { element.value == 1 } { // open dialog to load sequence
            Dialog.openPanel({ |path|
                removeAll.();
                val = ~loadSequence.(path);
                element.items = fileNames.(~seqPaths);
                element.value = val;
            });
        }
        { element.value > 1 } { // load seqence from file
            removeAll.();
            path = ~seqPaths[element.value].asString;
            postMsg.(format("INFO: Loading sequence %...\n",
                PathName.new(path).fileName
            ));
            val = ~loadSequence.(path); // open from file
            if (val > top) { // place at the top
                ~seqPaths.insert(top, ~seqPaths.pop(val));
                element.items = fileNames.(~seqPaths);
                element.value = top;
            };
            if (val == 0) {postMsg.("ERROR: Loading sequence has failed!")} {postMsg.("OK...")};
        };
        current = -1;
        updateButtonLabel.(btNextNum, getKey.(current, 1).asString);
        stNextInfo.string = eventInfo.(0);
    },
    initAction: true
);
button.(viewSeqList,
    "stop", bgColor:Color.grey(0.2), scaleW:0.41, scaleH:0.55
).action_({ |bt|
    "INFO: removing custom groups / synths".postln;
    synths.keys.do { |k| groupRemove.((id: k)) };
    ~stopSequence.();
    animateSeq = false; // stop clock
});
button.(viewSeqList,
    "reload", bgColor:Color.grey(0.2), scaleW:0.63, scaleH:0.55
).action_({ |bt|
    ddSequence.valueAction_(ddSequence.value);
});
miscParams[\rec] = (
    gui: buttonCheckbox.(panel,
        "REC.", labelColor: Color.red, bgColor:Color.black, scaleW:0.5, scaleH:0.2
    ).action_({ |bt| postMsg.(~recordAudio.(bt.value)) })
);
miscParams[\intBuf] = (
    gui: buttonCheckbox.(panel,
        "int buf", labelColor: Color.red, bgColor:Color.black, scaleW:0.5, scaleH:0.2
    )
    .action_({ |bt|
        var synthIn;
        if(bt.value == 1, {
            //recording synth
            synthIn = Synth(\sr__r__buffloop, [
                \bufnum, ~internalBuff.bufnum,  \busnum, ~inbus,
                \volIn, 1, \loop, 1, \gate, 1, \dur, 1]);
        }, {
            synthIn.free;
        });
        sendPhysics.([\internalBuf, bt.value])
    })
);


// world params panel
// Warning: filled out later!
winSrvBottomLeft = compViewFlow.(winSrv, 2@2, scaleH:0.72, scaleW:0.57);

// GUI: sequence control
winSrvBottomRight = compViewFlow.(winSrv, scaleH:0.75, scaleW:0.43);

// server tree view
srvTreeView = TextView(winSrvBottomRight,
    winSrvBottomRight.bounds.width@winSrvBottomRight.bounds.height
)
.editable_(false)
.font_(Font("Monaco", 10).boldVariant)
.stringColor_(Color.gray(0.7))
.background_(transparent)
.hasVerticalScroller_(true)
.canFocus_(false);
winSrv.front;


// GUI: World window
win = Window("world",
    Rect(winSrv.bounds.width, 22,
        Window.screenBounds.width-winSrv.bounds.width,
        Window.screenBounds.height-22
    ),
    resizable:false, border:false
);
win.view.decorator = FlowLayout(win.view.bounds, 1@1, 1@1);
win.background = Color.black;

// GUI: Top-level layout
//
// viewLeft is a container for world and internal post window
viewLeft = compViewFlow.(win, scaleW: (world.width+8)/win.bounds.width);
viewTop = compViewFlow.(viewLeft, scaleH:0.001); // placeholder
viewWorld = UserView(viewLeft, world.width@world.height);
viewBottom = compViewFlow.(viewLeft,
    scaleH:(win.bounds.height-(viewWorld.bounds.height+viewTop.bounds.height))/win.bounds.height
);
viewRight = compViewFlow.(win,
    scaleW:(win.bounds.width-viewLeft.bounds.width)/win.bounds.width,
);

// GUI: slider controllers for physics params
panel = compViewFlow.(winSrvBottomLeft, scaleH:0.78);
[
    \drag, \repulsion, \starMass,
    \gravX, \gravY, \gravZ,
    \springRestLen, \springStrength, \springDamp,
    \maxVel, \partInitAccel, \partFreq,
    \partDefaultMass, \partAgeThresh, \partSigmoidRatio,
].do { |key, n|
    worldParams[key][\gui] = slider.(panel, key, worldParams[key]);
    if ((n+1) % 3 == 0) { compViewFlow.(panel, scaleH:0.04)} // gap after every 3rd slider
};

// slider controllers for misc params
panel = compViewFlow.(winSrvBottomLeft, scaleH:0.15);
miscParams[\serverVolume] = (
    midicc: 12,
    spec: \db,
    gui: slider.(panel, "sVol", (label: "s.vol", spec: \db))
    .action_({ |sl| ~scsynth.volume.volume = sl.value })
    .value_(1)
);
tmp = [0.5, 30.0, \lin, 0.1, ~speakers.maxDist].asSpec;
miscParams[\maxDist] = (
    midicc: 14,
    spec: tmp,
    gui: slider.(panel, "maxDist", (
        label: "max dist", minval: tmp.minval, maxval: tmp.maxval,
        step: tmp.step, default: tmp.default
    ))
    .action_({ |sl| ~speakers.maxDist = sl.value })
    .value_(~speakers.maxDist)
);
tmp = [1, 10, \lin, 0.1, ~depth].asSpec;
miscParams[\depth] = (
    midicc: 15,
    spec: tmp,
    gui: slider.(panel, "depth", (
        label: "depth", minval: tmp.minval, maxval: tmp.maxval,
        step: tmp.step, default: tmp.default
    ))
    .action_({ |ez|
        ~depth = ez.value;
        ~sendMessage.('/audio', [\depth, ~depth])
    })
);

panel = compViewFlow.(winSrvBottomLeft, margin:5@5, gap:5@5, scaleH:0.12);
// button based misc params
miscParams[\removeall] = (
    midinote: 70,
    gui: button.(panel,
        "X", bgColor:Color.black, scaleW:0.19, scaleH:0.7
    ).action_({ |bt| removeAll.() })
);
// reset physics params to defaults
miscParams[\reset] = (
    midinote: 58,
    gui: button.(panel,
        "RESET", bgColor:Color.black, scaleW:0.19, scaleH:0.7
    ).action_({ |bt|
        worldParams.values.do { |element|
            if (element.keys.includes(\midicc) && element[\gui].isNil.not) {
                element[\gui].valueAction_(element[\default])
            }
        }
    })
);
sText.(panel, " ", stringFont:fontSmall, scaleH:0.5, scaleW:0.05); // gap
// button based physics params
[\particles, \mutualAttraction, \calibration].do { |key|
    worldParams[key][\gui] = buttonCheckbox.(
        panel,
        worldParams[key][\label],
        bgColor:Color.black, scaleW:0.19, scaleH:0.7
    )
    .value_(worldParams[key][\default])
    .action_({ |bt| sendPhysics.([key, bt.value]) })
};

// GUI: local post window
panel = compViewFlow.(viewBottom);
postView = TextView(panel, panel.bounds.width@panel.bounds.height)
.editable_(false)
.font_(fontMedium)
.stringColor_(fontColor)
.background_(transparent)
.hasVerticalScroller_(false)
.canFocus_(false);

// GUI: running synths and connections
viewConn = UserView(viewRight, viewRight.bounds.width@viewWorld.bounds.height);
// connections = {};
viewConn.drawFunc = { |view|
    // TEST - 5 .ar synths, 3 .kr
    // XXX TODO: `synths` should be the same format as `particles`!
    // XXX TODO: add key \connections to both `synths` and `particles`
    var synthsPart = (
        (hash: -2657291): (
            'node': 1023,
            'synth': "humm",
            'params': (\freq: 450, \detune: \c2)
            ),
        (hash: 980355): (
            'node': 1012,
            'synth': "wind",
            'params': (\cutoff: \c1, \rq: \c0)
            ),
        (hash: 717767): (
            'node': 1015,
            'synth': "pole"
        ),
        (hash: 370145): (
            'node': 1010,
            'synth': "pole"
        ),
    );
    var synthsCust = (
        \intro_bic: (
            'node': 1015,
            'synth': "buzz",
            'params': (\cutoff: \c0, \rq: \c1, \delay: \c0, \room: \c2)
        )
    );
    var synthsLFO = (
        // XXX do we have to display kr bus number here?
        "6298284": (
            'node': 1023,
            'synth': "ksine",
            'params': (\out: 0)
            ),
        "8280242": (
            'node': 1012,
            'synth': "keyscale",
            'params': (\out: 1, \in: \r_hand)
            ),
        "9600413": (
            'node': 1015,
            'synth': "klfno0",
            'params': (\out: 2)
        ),
    );
    var reshape = { |src|
        all {: (
            id: k,
            node: src[k][\node],
            synth: src[k][\synth],
            params: src[k][\params]
        ),
        k <- src.keys };
    };
    var drawSynth = { |syn, oX, oY, boxWidth, parm, ctl|
        // `parm`: params label (for example, "node [outbus]"), displayed under the synth name
        // `ctl`: [mute, solo], each value is Boolean
        var rect;
        if (ctl.isNil) {ctl=[true, true]};
        oX = oX * (boxWidth + 5); // adjust to the boxWidth
        // main synth container
        rect = Rect(oX, oY, boxWidth, 45);
        Pen.strokeColor = Color.white;
        if (syn['id'].class != Event) { // XXX - change to TraerParticle after testing!
            // the background of custom synth differs from particle synth
            Pen.fillColor = Color.grey(0.15);
            Pen.fillRect(rect);
        };
        Pen.strokeRect(rect);
        // synth name and node
        Pen.color = fontColor;
        Pen.stringAtPoint(syn[\synth].asString, [oX+5, oY+5].asPoint);
        Pen.stringAtPoint(parm.asString, [oX+5, oY+25].asPoint);
        // ctrl panel: "remove"
        Pen.strokeRect(Rect(oX+(boxWidth-16), oY, 15, 15));
        Pen.stringAtPoint("x", [oX+(boxWidth-12), oY].asPoint);
        // ctrl panel: "mute"
        if (ctl[0]) {
            Pen.strokeRect(Rect(oX+(boxWidth-16), oY+15, 15, 15));
            Pen.stringAtPoint("M", [oX+(boxWidth-12), oY+15].asPoint);
        };
        // ctrl panel: "solo"
        if (ctl[1]) {
            Pen.strokeRect(Rect(oX+(boxWidth-16), oY+30, 15, 15));
            Pen.stringAtPoint("S", [oX+(boxWidth-12), oY+30].asPoint);
        };
    };
    // all synths of a particular class sorted by node
    var synthsAr = (reshape.(synthsPart) ++ reshape.(synthsCust)).sortBy('node');
    var synthsKr = reshape.(synthsLFO).sortBy('node');

    // set 'nerd-ish' font to the whole view
    Pen.font_(Font("Andale Mono")).smoothing_(true);

    // .ar
    synthsAr.do { |syn, i|
        drawSynth.(
            syn, oX: i, oY: view.bounds.height-50,
            boxWidth: (view.bounds.width/synthsAr.size)-5,
            parm: syn[\node]
        );
    };

    // .kr
    synthsKr.do { |syn, i|
        drawSynth.(
            syn, oX: i, oY: 5,
            boxWidth: (view.bounds.width/synthsKr.size)-5,
            parm: format("% [%]",
                syn[\node],
                syn[\params].atFail(\out, {~outbus})
            ),
            ctl: [false, false]
        );
    }
};

// GUI: .ar synths selection
panel = compViewFlow.(viewRight, scaleW: 0.2, scaleH: 0.365);
listView.(
    panel,
    items: ~synths.keys.asArray,
    action: { |lv|
        var params=[];
        if (world[\internalBuf].booleanValue) {
            params = params ++ [\bufnum, ~internalBuff.bufnum]
        };
        ~sendParticle.(
            particle:(spring:1, mass:1),
            synth:(name: lv.items.at(lv.value), params: params)
        )
    }
);

// synth params
// XXX TODO
panel = compViewFlow.(viewRight, scaleW: 0.635, scaleH: 0.4);
2.do { |i|
    var stripeWidth = (panel.bounds.width/2).round;
    var pan, stSynth;
    pan = compViewFlow.(panel, scaleW: 0.5);
    stSynth = sText.(pan,
        ~synths.keys.asArray.choose, // XXX
        stringFont:fontMedium, scaleW:1, scaleH: 0.1
    );
    // knobs
    6.do({ |j|
        EZKnob(pan,
            Rect(
                (j/3).trunc*30+10,
                stSynth.bounds.height+(j%3*90)+30,
                stripeWidth*0.45,
                stripeWidth*0.6
            ),
            ~defaultParams.ar[j], ~specs.at(~defaultParams.ar[j]),
            { |ez| ez.value.postln },
            layout: \vert2
        )
        .font_(fontSmall)
        .setColors(
            stringBackground:transparent,
            stringColor:fontColor,
            numBackground:Color.grey(alpha:0.5),
            numNormalColor:fontColor,
            background:transparent,
        );
    });
    // sliders
    2.do { |j|
        sText.(pan, "", scaleW:0.15, scaleH: 0.4);
        EZSlider(pan,
            Rect(
                j%2*60+10,
                (pan.bounds.height*0.55).trunc,
                stripeWidth*0.3,
                pan.bounds.height*0.3
            ),
            ~defaultParams.ar[j+6], ~specs.at(~defaultParams.ar[j+6]),
            { |ez| ez.value.postln },
            unitWidth:30, numberWidth:60, layout:\vert
        )
        .font_(fontSmall)
        .setColors(
            stringColor:fontColor,
            sliderBackground:Color.black,
            numBackground:Color.grey(alpha:0.5),
            numNormalColor:fontColor,
            background:transparent
        )
    };
};

// .kr synths selection
panel = compViewFlow.(viewRight, scaleW: 0.2, scaleH: 0.365);
listView.(
    panel,
    items: ~lfos.keys.asArray,
    action: { |lv| lv.items.at(lv.value).postln }
);


viewWorld.mouseDownAction = { |view, x, y, modifiers, buttonNumber, clickCount|
    var speakerPos, speakerSize, speakers2Remove, processed=false;
    case
    { [0, 256].includes(modifiers) } { // no modifiers
        physics.particles.do { |particle|
            if (
                ((x - particle.position.x).abs <= 20) &&
                ((y - particle.position.y).abs <= 20)
            ) {
                if (clickCount == 2) { // double-click removes a particle
                    if (particle != star) { // star cannot be removed
                        unregisterParticle.(particles[particle][\node]);
                        removeParticle.(particle);
                    };
                } {
                    particle.position.set(x, y, particle.position.z)
                };
                processed = true;
            };
        };

        if (processed.not) { // process speakers only if no particles were processed
            // XXX - add here sending updated speakers positions to all nodes in `synths`
            ~speakers.items.do { |speaker, i|
                speakerPos = ade2xyz.(speaker, ~speakers.maxDist);
                speakerSize = speakerPos.z.linlin(0, world.depth, 40, 15);
                if (
                    ((x - speakerPos.x).abs <= (speakerSize / 2)) &&
                    ((y - speakerPos.y).abs <= (speakerSize / 2))
                ) {
                    if (clickCount == 2) {
                        ~speakers.removeSpeaker(i);
                        currSpeaker = nil;
                    } {
                        currSpeaker = i;
                    };
                };
            };
            #azimuth, distance, elevation = xyz2ade.([x, y].asPoint);
            try {
                ~speakers.items[currSpeaker].dist = distance.linlin(0, 1, 0, ~speakers.maxDist);
                ~speakers.items[currSpeaker].azim = azimuth;
            } { |err|
                if (err.class != PrimitiveFailedError ) { err.throw }
            };
        };
    }
    { modifiers == 262144 } { // Ctrl + Mouse - add speaker
        #azimuth, distance, elevation = xyz2ade.((x:x, y:y, z:world.depth*0.5));
        distance = distance.linlin(0, 1, 0, ~speakers.maxDist);
        ~speakers.items.add((dist: distance, azim: azimuth, elev: elevation)
        );
    }
    { modifiers == 524288 } { // Alt + Mouse
        star.position.set(x, y, 0) // moves the Star
    }
    { modifiers == 131072 } { // Shift + Mouse
    }
};
viewWorld.mouseMoveAction = viewWorld.mouseDownAction;
viewWorld.mouseUpAction = {
    currSpeaker = nil
};

win.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
    // [view, char, modifiers, unicode, keycode].postln;
    case
    { keycode == 8 } { // C
        if (modifiers == 262144) { // Ctrl + C
            cleanExit.();
        }
    }
    { keycode == 3 } { // F
        if (modifiers == 262144) { // Ctrl + F
            if (win.bounds == Window.screenBounds) {
                win.endFullScreen
            } {
                win.fullScreen
            }
        }
    }
    { keycode == 53 } { // ESC
        if (win.bounds == Window.screenBounds) {
            win.endFullScreen
        }
    }
    { keycode == 45 } { // [N]ext
        { btNextNum.valueAction_(true) }.defer
    }
    { modifiers == 1048576 } { // Cmd
        if (win.bounds == Window.screenBounds) {
            win.endFullScreen
        }
    }

    // X - remove all particles and synths
    { keycode == 7 && [0, 256].includes(modifiers) } { removeAll.() }

    // "+" ("=") - increase speaker elevation
    { keycode == 24 && [0, 256].includes(modifiers) } {
        if (currSpeaker.isNil.not) {
            ~speakers.items[currSpeaker].elev = min(
                ~speakers.items[currSpeaker].elev + 0.00872664, 0.5pi
            ).round(0.00872664) // round to 0.5 degrees
        }
    }

    // "-" - decrease speaker elevation
    { keycode == 27 && [0, 256].includes(modifiers) } {
        if (currSpeaker.isNil.not) {
            ~speakers.items[currSpeaker].elev = max(
                ~speakers.items[currSpeaker].elev - 0.00872664, -0.5pi
            ).round(0.00872664) // round to 0.5 degrees
        }
    }
};

viewWorld.drawFunc = { |view|
    Pen.font_(Font("Andale Mono")).smoothing_(true);
    if (world.calibration.booleanValue) {
        Pen.scale(1, 1);
        Pen.translate(0, 0);
        center = [world.width/2, world.height/2].asPoint;
        scale = star.position.z.linlin(0, world.depth, 0.2, 1);
        translate = scale.linlin(0.2, 1, world.height/2, 0);
        focal = star.position.x.linlin(0, world.width, 0, 100);
        // Pen.scale(scale, scale);
        // Pen.translate(translate, translate);
    } {
        center = xyz2plane.(
            [world.width/2, world.height/2],
            world, scale, focal
        ).asPoint;
    };

    // draw floor
    Pen.color = Color.white;
    Pen.strokeRect(Rect.aboutPoint(center, world.width, world.height));

    // maxDist
    Pen.color = Color.new255(110, 45, 48, 100);
    Pen.fillOval(Rect.aboutPoint(center, world.width/2, world.height/2));

    // depth
    Pen.color = Color.new255(182, 107, 108, 50);
    Pen.fillOval(Rect.aboutPoint(
        center,
        ~depth.linlin(1, 10, 20, world.height*0.5),
        ~depth.linlin(1, 10, 20, world.height*0.5)));

    // calibration marks & lines
    Pen.color = fontColor;
    Pen.stringAtPoint("-0.25", [5, 5].asPoint);
    Pen.stringAtPoint("0", [5, (world.height - 15) * 0.5].asPoint);
    Pen.stringAtPoint("0.25", [5, world.height - 20].asPoint);
    Pen.stringAtPoint("0.5", [(world.width - 25) * 0.5, world.height - 20].asPoint);
    Pen.stringAtPoint("0.75", [world.width - 35, world.height - 20].asPoint);
    Pen.stringAtPoint("1", [world.width - 15, (world.height - 15) * 0.5].asPoint);
    Pen.stringAtPoint("-0.75", [world.width - 45, 5].asPoint);
    Pen.stringAtPoint("-0.5", [(world.width - 35) * 0.5, 5].asPoint);
    Pen.line([world.width * 0.5, 25].asPoint, [world.width*0.5, world.height-25].asPoint);
    Pen.line([25, world.height * 0.5].asPoint, [world.width-25, world.height*0.5].asPoint);
    Pen.line([25, 25].asPoint, [world.width*0.14, world.height*0.14].asPoint);
    Pen.line([world.width*0.86, world.height*0.86].asPoint, [world.width-25, world.height-25].asPoint);
    Pen.line([world.width-25, 25].asPoint, [world.width*0.86, world.height*0.14].asPoint);
    Pen.line([world.width*0.14, world.height*0.86].asPoint, [25, world.height-25].asPoint);
    Pen.stroke;

    // speakers
    ~speakers.items.do { |speaker, i|
        var pos, speakerSize;
        pos = ade2xyz.(speaker, ~speakers.maxDist);
        speakerSize = pos.z.linlin(0, world.depth, 40, 15);

        Pen.color = Color.grey(pos.z.linlin(0, world.depth, 1, 0.7));
        // distance
        Pen.line(
            [listenerPos.x, listenerPos.y].asPoint,
            [pos.x, pos.y].asPoint
        );
        Pen.stringAtPoint((speaker.dist.round(0.1)).asString++" m",
            [pos.x-(speakerSize*0.5), pos.y+(speakerSize*0.6)].asPoint
        );
        // azimuth
        Pen.addArc([listenerPos.x, listenerPos.y].asPoint,
            i*35+35, 1pi, 1pi-speaker.azim.linlin(-1pi, 1pi, 0, 2pi)
        );
        Pen.stringAtPoint((speaker.azim * 180 / 1pi).round.asString, // XXX - raddeg?
            [
                world.width/2-(i*32+32),
                world.height*0.492+(speaker.azim/(speaker.azim).abs*9)
            ].asPoint
        );
        // elevation
        Pen.stringAtPoint(
            ((speaker.elev * 180 / 1pi).round(0.1)).asString,
            [pos.x-(speakerSize*0.5), pos.y-speakerSize].asPoint
        );
        Pen.stroke;

        Pen.fillRect(Rect(pos.x-(speakerSize*0.5), pos.y-(speakerSize*0.5), speakerSize, speakerSize));
        Pen.color = Color.black;
        Pen.stringAtPoint((i+1).asString,
            [pos.x - (speakerSize*0.1), pos.y-(speakerSize*0.1)].asPoint
        );
    };

    paramsChanged = false;
    if (worldTrace != world) {
        paramsChanged = true;
        worldTrace = Dictionary.newFrom(world);
        // some should be updated directly
        star.mass = world.starMass;
        physics.setGravity(world.gravX, world.gravY, world.gravZ);
        physics.setDrag(world.drag);
    };

    // Control skeletons.
    skeleton.keys.do { |id|
        try {
            if ((Date.getDate.secStamp.asInteger - skeleton[id][\update].asInteger) >= skel.waitBeforeRemove) {
                skeletonRemove.(id);
                paramsChanged = true;
            }
        }
    };

    // Particle system.
    if (world.particles.booleanValue) {
        if (view.frame % (view.frameRate * world.partFreq).round == 0) {
            particleSystem.(defineGuide.())
        }
    };

    // Springs should stick to hands even after skeleton is lost and then appears again.
    // Track connections of springs in a global dictionary.
    springsPhysical = all {: g.identityHash, g <- physics.springs} ? [];
    springs.keysValuesDo { |springId, end|
        if (springsPhysical.includes(springId).not) {
            // end = [ <joint id e.g. \r_hand>, TraerParticle ]
            springMissed = applySpring.(end[1], end[0]);
        }
    };
    // Update global dictionary of springs.
    if (springMissed.isNil.not) { // only if new springs created
        springs = IdentityDictionary.new;
        registerSprings.(physics.springs);
    };

    // Remove attractions that stuck after a particle's death.
    attractionsPhysical = Array.newFrom(physics.attractions);
    attractionsPhysical.do { |attr|
        if (
            physics.particles.includes(attr.getOneEnd).not ||
            physics.particles.includes(attr.getTheOtherEnd).not
        ) { removeAttraction.(attr) }
    };

    // WARNING!
    // The following block of code should go BEFORE particle for the sake of better
    // visualisation of particles as connectors of skeleton joins, springs and attractions.
    //
    // Visualize springs.
    physics.springs.do { |spring, i|
        Pen.color = Color.white;
        Pen.moveTo(Point(spring.a.position.x, spring.a.position.y));
        Pen.lineTo(Point(spring.b.position.x, spring.b.position.y));
        Pen.stroke;
    };
    // Visualize attractions.
    physics.attractions.do { |attr, i|
        Pen.color = Color.yellow(alpha:0.3);
        Pen.moveTo(Point(attr.a.position.x, attr.a.position.y));
        Pen.lineTo(Point(attr.b.position.x, attr.b.position.y));
        Pen.stroke;
    };
    // Visualize joins connections.
    Pen.color = Color.green(0.5);
    skeleton.values.do { |sk|
        jointVisible.size.do { |j|
            try {
                Pen.moveTo(Point(
                    sk[jointVisible[j]].position.x,
                    sk[jointVisible[j]].position.y));
                Pen.lineTo(Point(
                    sk[jointVisible[j+1]].position.x,
                    sk[jointVisible[j+1]].position.y));
                Pen.width = sk[jointVisible[j+1]].position.z.linlin(0, world.depth, 3, 20);
                Pen.stroke;
            }
        };

        // XXX
        //
        // var curve;
        // var drawCurve = { |crv, j|
        //     try {
        //         Pen.moveTo(Point(sk[crv[j]].position.x, sk[crv[j]].position.y));
        //         Pen.lineTo(Point(sk[crv[j+1]].position.x, sk[crv[j+1]].position.y));
        //         Pen.stroke;
        //     }
        // };
        // if (world.calibration.booleanValue) {
        //     curve = ['head', 'neck', 'torso'];
        //     curve.do { |joint, j| drawCurve.(curve, j) };
        //     curve = ['l_hand', 'l_elbow', 'l_shoulder', 'neck', 'r_shoulder', 'r_elbow', 'r_hand'];
        //     curve.do { |joint, j| drawCurve.(curve, j) };
        //     curve = ['l_foot', 'l_knee', 'l_hip', 'torso', 'r_hip', 'r_knee', 'r_foot'];
        //     curve.do { |joint, j| drawCurve.(curve, j) };
        // } {
        //     jointVisible.size.do { |j|
        //         try {
        //             Pen.moveTo(Point(sk[jointVisible[j]].position.x, sk[jointVisible[j]].position.y));
        //             Pen.lineTo(Point(sk[jointVisible[j+1]].position.x, sk[jointVisible[j+1]].position.y));
        //             Pen.stroke;
        //         }
        //     }
        // };
    };
    // WARNING - end

    // Manage particles.
    particlesSkelVis = getParticlesSkelVis.();
    particlesHidden = getParticlesHidden.();
    particlesOnSprings = getParticlesOnSprings.();
    Array.newFrom(physics.particles).do { |particle|
        // Re-apply world forces, if there was any change in its parameters
        if (paramsChanged) {
            if (particlesOnSprings.includes(particle)) {
                // if particle is on spring, change spring's properties
                setSpringProp.(particle:particle);
            } {
                // if particle isn't on spring, re-apply attractions
                if (particlesHidden.includes(particle).not) { // exclude hidden particles
                    applyAttractions.(particle, world.mutualAttraction);
                }
            };
        };
        handleBoundaryCollisions.value(particle);

        // send parameters to the group on Server
        if (particles.keys.includes(particle)) {
            #ax, ay, az = xyz.(particle.position);
            #azimuth, distance, elevation = xyz2ade.(particle.position);
            if (particlesOnSprings.includes(particle)) {
                guide = getGuide.(particle);
                #gx, gy, gz = xyz.(guide.position);
                #gAzimuth, gDistance, gElevation = xyz2ade.(guide.position);
            } { // in the absense of guide, a particle is a guide for itself.
                guide = particle;
                #gx, gy, gz = [ax, ay, az];
                #gAzimuth, gDistance, gElevation = [azimuth, distance, elevation];
            };
            ~scsynth.sendMsg("/n_set", particles[particle][\node],
                // particle params
                \ax, ax,
                \ay, ay,
                \az, az,
                \azimuth, azimuth,
                \distance, distance,
                \elevation, elevation,
                \momentum, mag3D.(particle.velocity).distort.pow(10), // scale by sigmoid func (distort), smooth by .pow

                // guide params
                \gx, gx,
                \gy, gy,
                \gz, gz,
                \gzimuth, gAzimuth,
                \gDistance, gDistance,
                \gElevation, gElevation,

                // general
                \depth, ~depth,
            );
        };

        // Visualize particles.
        if (particlesHidden.includes(particle).not) {
            case
            {particle == star} {
                partColor = Color.red(alpha:star.position.z.linlin(0, world.depth, 0.7, 0.3));
                partSize = 40
            }
            { particlesSkelVis.includes(particle) } {
                partColor = Color.white;
                partSize = 10
            }
            {
                partColor = Color(particle.mass.linlin(0, 1, 0.2, 1), // the heavier the object, the redder it appears
                    particle.mass.linlin(0, 1, 0.7, 1), particle.mass.linlin(0, 1, 1, 0.1));
                partSize = 5;
                Pen.color = Color.grey(particle.position.z.linlin(0, world.depth, 1, 0.5));
                Pen.stringAtPoint(particles[particle][\synth].asString.stripWhiteSpace,
                    [
                        (particle.position.x+10).clip(10, world.width-45),
                        (particle.position.y+10).clip(10, world.height-15),
                    ].asPoint,
                    Font("Helvetica", 14));
            };
            Pen.color = partColor;
            z = partSize * particle.position.z.linlin(0, world.depth, 1, 0.1);
            Pen.fillOval(Rect.aboutPoint(Point(particle.position.x, particle.position.y), z, z));
        };

        // Age control: particles age "backwards",
        // i.e. age = 0 is a death and positive age is afterlife.
        if (particle.age >= 0) { particle.dead = true };
        if (particle.dead) {
            unregisterParticle.(particles[particle][\node]);
            removeParticle.(particle)
        };
    };

    // draw stat (on top of everything else, all values updated in a current cycle)
    Pen.color = Color.green(0.5);
    Pen.stringAtPoint("particles", [world.width*0.5-260, world.height-20].asPoint);
    Pen.color = Color.green;
    Pen.stringAtPoint(physics.particles.size.asString, [world.width*0.5-185, world.height-20].asPoint);

    Pen.color = Color.green(0.5);
    Pen.stringAtPoint("skeletons", [world.width*0.5-155, world.height-20].asPoint);
    Pen.color = Color.green;
    Pen.stringAtPoint(format("% %", skeleton.size, skeleton.keys.asArray), [world.width*0.5-75, world.height-20].asPoint);

    Pen.color = Color.green(0.5);
    Pen.stringAtPoint("springs", [world.width*0.5+30, world.height-20].asPoint);
    Pen.color = Color.green;
    Pen.stringAtPoint(physics.springs.size.asString, [world.width*0.5+90, world.height-20].asPoint);

    Pen.color = Color.green(0.5);
    Pen.stringAtPoint("attractions", [world.width*0.5+120, world.height-20].asPoint);
    Pen.color = Color.green;
    Pen.stringAtPoint(physics.attractions.size.asString, [world.width*0.5+210, world.height-20].asPoint);

    // audio through is connected either to skeletons head
    // or to the star
    if (skeleton.keys.size > 0) {
        guide = skeleton[skeleton.keys.minItem][\head];
    } {
        guide = star;
    };
    #ax, ay, az = xyz.(guide.position);
    #azimuth, distance, elevation = xyz2ade.(guide.position);
    ~scsynth.sendMsg("/n_set", ~nodeAudioThrough,
        // particle params
        \ax, ax,
        \ay, ay,
        \az, az,
        \azimuth, azimuth,
        \distance, distance,
        \elevation, elevation,
        \momentum, mag3D.(guide.velocity).distort.pow(10), // scale by sigmoid func (distort), smooth by .pow

        // guide params
        \gx, ax,
        \gy, ay,
        \gz, az,
        \gzimuth, azimuth,
        \gDistance, distance,
        \gElevation, elevation,

        // general
        \depth, ~depth,
    );

    physics.tick;
};

handleBoundaryCollisions = { |p|
    // Handle collisions with World boundaries.
    if (p.position.x < 0 or:{p.position.x > world.width}) {
        p.velocity.set(-0.9 * p.velocity.x, p.velocity.y, p.velocity.z);
    };
    if(p.position.y < 0 or:{p.position.y > world.height}) {
        p.velocity.set(p.velocity.x, -0.9 * p.velocity.y, p.velocity.z);
    };
    if(p.position.z < 0 or:{p.position.z > world.depth}) {
        p.velocity.set(p.velocity.x, p.velocity.y, -0.9 * p.velocity.z);
    };
    p.position.set(
        p.position.x.clip(0, world.width),
        p.position.y.clip(0, world.height),
        p.position.z.clip(0, world.depth));
};

decodeParticle = { |particle|
    // Returns display of a particle "role" (a Star,
    // a skeleton's joint or an ordinary particle).
    var result;
    if (particle == star) {
        result = "Star"
    } {
        skeleton.keysValuesDo { |skel, joints|
            springSrcSkel.do { |jt|
                if (joints[jt] == particle) {
                    result = format("% - %", skel, jt)
                };
            };
        };
    };
    if (result.isNil) { try { result = particle.identityHash } };
    result
};

registerSpring = { |spring|
    // Register individual spring in the global dictionary.
    var endA, endB;
    if (spring.isNil.not) {
        #endA, endB = [spring.a, spring.b];
        skeleton.keysValuesDo { |skel, joints|
            springSrcSkel.do { |jt|
                if (joints[jt] == endA) { endA = jt };
                if (joints[jt] == endB) { endB = jt };
            };
        };
        springs[spring.identityHash] = [endA, endB];
    }
};

getParticlesSkelVis = {
    //
    all {: v[k], v <- skeleton.values, k <- v.keys,
        jointVisible.includes(k)
    } ? []
};

getParticlesHidden = {
    //
    all {: v[k], v <- skeleton.values, k <- v.keys,
        jointVisible.includes(k).not
    } ? []
};

getParticlesOnSprings = {
    //
    (
        all {: [g.a, g.b], g <- physics.springs} ? []
    ).flatten
};

registerSprings = { |springsList|
    // Registers all springs from List in the global dictionary.
    springsList.do { |spring|
        registerSpring.(spring)
    }
};

resolveSpringEnd = { |end|
    // Translates spring end from joint name to particle.
    try {
        skeleton[skeleton.keys.asArray[0]][end]
    } { |error|
        nil
    };
};

getSpringForParticle = { |particle|
    // Finds spring connected by any of its ends to a given particle.
    var spring;
    physics.springs.do { |sp|
        if ([sp.a, sp.b].includes(particle)) { spring = sp }
    };
    spring
};

getSynthName = { |shortName, node, particle|
    // Figures out full synth name in a form "\sr__%__%"
    // based on its short name, or a node, or a living particle.
    var synthName="", checkNames;
    if (particle.isNil.not) {
        shortName = particles[particle][\synth]
    };
    if (node.isNil.not) {
        shortName = all {: particles[p][\synth], p <- particles, p[\node] == node};
        shortName = shortName[0]
    };
    if (shortName.isNil.not) {
        checkNames = all {: format("\sr__%__%", nm, shortName.asString), nm <- ["e", "g", "p"]};
        checkNames.do { |name|
            if (~synths.keys.includes(name.asSymbol)) {
                synthName = name
            };
        };
    };
    synthName.asSymbol
};

setSpringProp = { |spring, particle|
    // Sets worlds parameters to spring.
    if (spring.isNil) {
        spring = getSpringForParticle.(particle)
    };
    spring.setDamping(world.springDamp);
    spring.setRestLength(world.springRestLen);
    spring.setStrength(world.springStrength);
};

applySpring = { |particle, src, ks, d, r|
    // Apply spring: choose a source and connect particle to it.
    var spring, source;
    source = resolveSpringEnd.(src);
    if (source.isNil) { source = defineSource.() };
    if (source.isNil.not && particle.isNil.not) {
        spring = physics.makeSpring(source, particle,
            ks ? world.springStrength, d ? world.springDamp, r ? world.springRestLen);
    };
    spring
};

applyAttractions = { |particle, mutual=false|
    // Apply forces:
    // - skeleton's hands ALWAYS attracts all particles,
    //   including Star, regardless of the `mutual` state
    // - Star ALWAYS attract all objects, excluding skeleton's hands
    // - ordinary objects attract each other only if `mutual` is true
    var skeletonParticles=List.new, excludeParticles=List.new;
    List.newFrom(physics.attractions).do { |attr|
        if ((attr.a == particle) || (attr.b == particle)) {
            physics.removeAttraction(attr);
        }
    };
    // Attraction of the Star.
    if (particle != star) {
        physics.makeAttraction(star, particle, star.mass * 1000, 50);
    };
    // Gather lists of skeleton joints, that should /should not attract particles.
    skeleton.values.do { |skel|
        // exclude skeleton's particles that are not in springSrcSkel
        excludeParticles = all {: skel[joint], joint <- skel.keys,
            springSrcSkel.includes(joint).not
        } ? [];
        springSrcSkel.do { |joint|
            skeletonParticles.add(skel[joint])
        }
    };
    // Attraction to hands (different from mutual).
    if (skeletonParticles.isNil.not) {
        skeletonParticles.do { |skeletonParticle|
            if (excludeParticles.includes(particle).not) { // particle can be a skeleton's joint
                physics.makeAttraction(skeletonParticle, particle,
                    (particle.mass * (world.repulsion * 0.1)).neg, world.depth * 0.01
                );
            }
        };
    };
    // Exclude the Star, too.
    excludeParticles.add(star);
    // Mututal attraction / repulsion.
    if (mutual.booleanValue) {
        physics.particles.do { |part|
            if (
                (particle != part)
                && excludeParticles.includes(particle).not
                && excludeParticles.includes(part).not
                && skeletonParticles.includes(particle).not
                && skeletonParticles.includes(part).not
            ) {
                physics.makeAttraction(particle, part, (particle.mass * world.repulsion).neg, 10);
            }
        }
    };
};

chooseSource = {
    // Choose a source (skeleton with the "lightest" hand).
    var mass, sources = IdentityDictionary.new;
    skeleton.keysValuesDo { |num, skel|
        springSrcSkel.do { |joint|
            mass = 0;
            physics.springs.do { |spring|
                // joint is always a source
                if (spring.a == skel[joint]) {
                    mass = mass + spring.b.mass
                };
            };
            sources.put(skel[joint], mass);
        };
    };
    // choose the one with minimum load
    sources.findKeyForValue(sources.values.minItem)
    ??
    // if there are none, the probabilities of picking any of them are equal
    skeleton.choose[springSrcSkel.choose]
};

defineSource = { |starAllowed=false|
    // Select source of force depending on the presence of skeleton.
    if (skeleton.keys.size > 0) {
        chooseSource.()
    } {
        if (starAllowed) { star } { nil }
    }
};

defineGuide = {
    // Define guide (where obj appears) depending on objects velocity.
    var guides = IdentityDictionary[star -> mag3D.(star.velocity)];
    skeleton.keysValuesDo { |skel, joints|
        springSrcSkel.do { |jt|
            // WARNING! Skeleton joints do not possess velocity,
            // the following doesn't work:
            //guides[joints[jt]] = mag3D.(joints[jt].velocity);

            // but always prefer skeleton joints to the Star
            guides[joints[jt]] = guides[star] * ([2, 5].choose);
        };
    };
    // the faster the object, the bigger a chance to become a guide
    guides.findKeyForValue(guides.values.wchoose(guides.values.exp.normalizeSum))
};

getGuide = { |particle|
    // Get object's guide, if any.
    var spring, guide;
    spring = getSpringForParticle.(particle);
    if (spring.isNil.not) {
        guide = spring.a
    };
    guide
};

initParticle = { |mass, x, y, z, age, vel|
    // Init new particle.
    var particle, guide;
    if ([x, y, z].any({ |i| i < 0 })) { // negative coordinates ask for guide
        guide = defineGuide.();
        #x, y, z = [guide.position.x, guide.position.y, guide.position.z];
    } {
        #x, y, z = [x ? world.width.rand, y ? world.height.rand, z ? world.depth.rand]
    };
    particle = physics.makeParticle(mass ? world.partDefaultMass, x, y, z);
    try {
        particle.velocity.set(vel[0], vel[1], vel[2])
    };
    // Particles age "backwards": age == 0 is death, age >= 0 is afterlife.
    try {
        particle.age = (age * 60).abs.neg;
    } {
        particle.age = inf.neg;
    };
    particle
};

particleSystem = { |guide|
    // Particle system.
    var vel, prob;
    // probability of the birth of particle depends on the guide's velocity
    vel = guide.velocity;
    if (vel == 0) { vel = world.maxVel };
    prob = sigmoid.(
        ratio:world.partSigmoidRatio,
        value:mag3D.(vel).linlin(0, world.maxVel, world.maxVel.neg, world.maxVel));
    if (prob.coin.booleanValue) {
        registerParticle.(
            initParticle.(0.2, guide.position.x, guide.position.y, guide.position.z,
                world.partAgeThresh.logistic,
                [vel.x, vel.y, vel.z].neg * world.partInitAccel.max(0.01)),
            ~initSynth.(world.partSynth, params:[\att, 0.5.rand])
        );
    }
};

removeSpring = { |spring|
    //
    springs.removeAt(spring.identityHash);
    physics.removeSpring(spring);
};

removeAttraction = { |attraction|
    //
    physics.removeAttraction(attraction);
};

removeParticle = { |particle|
    //
    // remove springs
    physics.springs.do { |spring|
        if ([spring.a, spring.b].includes(particle)) {
            removeSpring.(spring)
        }
    };
    // remove registered springs, if any
    springs.keysValuesDo { |key, val|
        if (val.includes(particle)) {
            springs.removeAt(key);
        }
    };
    // remove attractions
    physics.attractions.do { |attr|
        if ([attr.getOneEnd, attr.getTheOtherEnd].includes(particle)) {
            removeAttraction.(attr)
        }
    };
    physics.removeParticle(particle);
};

removeAll = {
    // Remove all particles from the world and stop all synths.
    particles.keys.do { |p, i|
        unregisterParticle.(particles[p][\node]);
        removeParticle.(p);
    }
};

registerParticle = { |particle, nodeId|
    // Register particle in the dictionary along with Server nodeId.
    //
    // Register and unregister particle are separate functions
    // from init and remove to support the case when an existing
    // particle is being re-attached to a different node on the server.
    var taskSendMsg, keys=[];
    particles.put(particle, (node: nodeId));
    taskSendMsg = Task({
        inf.do { |j|
            try { keys = particles[particle].keys } { keys = [] };
            if ((keys.includes("synth")) || (j >= 20)) { // wait 2sec
                taskSendMsg.stop;
            };
            ~scsynth.sendMsg("/g_queryTree", ~rootAr); // to fill out synth name
            0.1.wait;
        };
    }).start;
};

unregisterParticle = { |nodeId|
    // Removes particle record from the dictionary.
    var particle;
    particles.keysValuesDo { |part, dict|
        if (dict[\node] == nodeId) { particle = part }
    };
    particles.removeAt(particle);
    ~groupFree.(nodeId);
    particle
};


// SKELETON
//
skeletonParticles = { |id, joint, x, y, z|
    // Creates a particle for each joint of the skeleton.
    var part;
    if (skeleton.keys.includes(id).not) {
        if (skeleton.keys.asArray.size < skel.limit) {
            skeleton[id] = (complete: false)
        }
    };
    if (joint.isNil.not) {
        if (skeleton.keys.includes(id)) {
            if (skeleton[id].keys.includes(joint).not) {
                part = initParticle.(world.starMass, x, y, z);
                part.makeFixed;
                skeleton[id][joint] = part;
            };
            skeleton[id][joint].position.set(x, y, z);
            skeleton[id][\update] = Date.getDate.secStamp;
        };
    };
};

skeletonRemove = { |id|
    // Removes skeleton particles (cannot be removed
    // as ordinary particles).
    var springsPhysical;
    skeleton[id].do { |p|
        List.newFrom(physics.springs).do { |spring|
            if ([spring.a, spring.b].includes(p)) {
                physics.removeSpring(spring);
            }
        };
        List.newFrom(physics.attractions).do { |attr|
            if ([attr.getOneEnd, attr.getTheOtherEnd].includes(p)) {
                removeAttraction.(attr)
            }
        };
        physics.removeParticle(p);
    };
    skeleton.removeAt(id)
};


// HELPER FUNCTIONS
//
mag3D = { |vec|
    // 3-d vector(s) magnitude.
    // `vec` can be either dictionary-like object (x:x, y:y, z:z), in which case
    // a siggle float value of the magnitude is returned, or a collection of such
    // objects, which result in a collection of magnitudes.
    var func = { |vector| (vector.x.sumsqr(vector.y) + vector.z.pow(2)).sqrt};
    var result = 0;
    try {
        result = func.(vec)
    } {
        result = List.new;
        vec.do { |vector| result.add(func.(vector)) };
        result = result.asArray;
    };
    result
};

sigmoid = { |ratio, value|
    //
    1 / (1 + exp((ratio * value).neg))
};

xyz2plane = { arg pos, space, scale=1, focal=0.5;
    // Project 3D coordinates on the plane.
    // pos = Dictionary[x, y, z]
    // space = Dictionary[width, height, depth]
    var x, y, z, ox, oy;
    z = space.depth - pos.z / (space.depth * scale);
    z = z.linlin(0, space.depth, focal, 1);
    x = pos.x * z;
    y = pos.y * z;
    ox = 1 - z * (space.width * 0.5) + x;
    oy = 1 - z * (space.height * 0.5) + y;
    [ox, oy]
};

xyz2ade = { |position|
    // Returns azimuth, distance and elevation for a position defined as [x, y, z]
    var pos, elev;
    pos = Complex(
        position.x.linlin(0, world.width, 1, -1), // y
        position.y.linlin(0, world.height, -1, 1) // x
    );
    elev = position.z.linlin(0, world.depth, 0.5pi, -0.5pi); // inverse
    [
        pos.theta, // azimuth
        pos.rho, // distance from center
        elev // elevation
    ]
};

ade2xyz = { |position, maxDist|
    // Converts (azimuth, distance, elevation) to (x, y, z)
    var pos, distAdj;
    var mC = 2.sqrt; // max in Cartesian plane (from center to wall)
    distAdj = position.dist.linlin(0, maxDist, 0, mC); // adjust distance on [0, maxDist]
    pos = Polar(distAdj, position.azim).asCartesian;
    (
        x: pos.x.linlin(mC.neg, mC, world.width, 0),
        y: pos.y.linlin(mC.neg, mC, 0, world.height),
        z: position.elev.linlin(-0.5pi, 0.5pi, world.depth, 0) // inverse
    )
};


xyz = { |position|
    // Returns x, y and z in required format.
    [
        position.x / world.width,
        position.y / world.height,
        position.z.linlin(0, world.depth, 1, 0) // inverse
    ]
};


updatePostColors = { |colors, start|
    // Updates post colors when postView size shrinks.
    colors.size.do { |i|
        colors[i][\start] = colors[i][\start] - start
    };
    all {: k, k <-colors, k[\start] > 0 };
};

getMsgColor = { |msg|
    //
    case
    { msg.beginsWith("INFO") } { Color.new255(11, 96, 224) }
    { msg.beginsWith("DEBUG") } { Color.new255(113, 138, 0) }
    { msg.beginsWith("WARNING") } { Color.white }
    { msg.beginsWith("ERROR") } { Color.new255(158, 33, 33) }
    { fontColor };
};


// XXX - change this with re-directing all POST messages
postMsg = { |msg|
    // post message to local listener
    var msgColor, start, color;
    msg = msg.asString;
    if (msg.endsWith("\n").not) { msg = msg ++ "\n" };
    msgColor = getMsgColor.(msg);
    {
        // do not grow too long
        if (postView.string.size > postMaxSize) {
            start = postView.string.size - postMaxSize;
            postView.string = postView.string[start..];
            postColors = updatePostColors.(postColors, start);
        };
        postColors.add((start: postView.string.size, num: msg.size, color: msgColor));
        postView.string = postView.string ++ msg;
        postColors.do { |c|
            postView.setStringColor(c[\color], c[\start], c[\num]);
        };
        postView.select(postView.string.size, 1); // autoscroll
    }.defer;
};


// OSC
//
// Catch messages related to particles.
oscParticle = OSCFunc({ |msg, time, addr, recvPort|
    var particle, node, age, source, mass, x, y, z, spring, registered;
    postMsg.(format("%:%: %\n", addr.ip, addr.port, msg[0]));
    node = msg[2];
    msg[1].switch(
        1, { // create particle
            mass = msg[4];
            try {
                #x, y, z, age, source = msg[5..]
            } {
                #x, y, z, age, source = nil ! 5
            };
            postMsg.(format(
                "    create node:%\n    pos(x, y, z): %, %, %\n    mass: %\n    age: %\n    source: %\n    spring: %\n\n",
                node, x, y, z, mass, age, source, msg[3].booleanValue
            ));
            particle = initParticle.(mass, x, y, z, age);
            registerParticle.(particle, node);
            if (msg[3].booleanValue) {
                spring = applySpring.(particle, source);
                registered = registerSpring.(spring);
            };
            if (msg[3].booleanValue.not || registered.isNil) {
                // "spring" can be specified, but failed
                // in this case apply attractions
                postMsg.("WARNING: spring requested but failed, applying attractions");
                applyAttractions.(particle, world.mutualAttraction)
            };
        },
        0, { // remove particle
            postMsg.(format("    remove node:%\n", node));
            particle = unregisterParticle.(node);
            removeParticle.(particle);
        }
    );
}, '/particle');


// Catch messages related to physics.
oscPhysics = OSCFunc({ |msg, time, addr, recvPort|
    postMsg.(format("%:%: %\n", addr.ip, addr.port, msg[0]));
    msg[1..].pairsDo { |key, val|
        postMsg.(format("    %: %\n", key, val));
        if (key == \star) {
            val.switch(
                \fixed, { star.makeFixed },
                \free, { star.makeFree },
            )
        } {
            try { world[key] = val }
        }
    };
    postMsg.("\n");
}, '/physics');


// Catch action messages.
oscAction = OSCFunc({ |msg, time, addr, recvPort|
    var data, synthId;
    postMsg.(format("%:%: %\n    %: %\n\n", addr.ip, addr.port, msg[0], msg[1], msg[2..]));
    msg[1].switch(
        \remove, {
            if (msg[2] == \all) {
                removeAll.()
            } {
                removeParticle.(unregisterParticle.(msg[2].asInteger));
            }
        },
        \event, {
            if (msg[2].asInteger <= 0) {
                { btCurrNum.valueAction_(true) }.defer
            } {
                { btNextNum.valueAction_(true) }.defer
            }
        },
        \add, {
            // What other acts can be sent to the World?
        },
        // XXX - finish it
        \srv_msg, {
            msg[2].switch(
                \s_new, {  },
                \n_set, {
                    data = Dictionary.newFrom(msg[3..]);
                    synthId = data[\id];
                    data.removeAt(\id);
                    sendNSet.((\synth: (\id: synthId, \params: data.asKeyValuePairs)))
                },
                \g_new, {  },
                \g_free, {  },
                { ~sendMessage.(d[\message], d[\params]) }
            );
            // /n_set
        }
    );
}, '/action');


// Catch messages related to skeleton.
oscSkeletonLost = OSCFunc({ |msg, time, addr, recvPort|
    postMsg.(format("%:%: %\n", addr.ip, addr.port, msg));
    skeletonRemove.(msg[1]);
}, '/lost_skel');


oscSkeletonNew = OSCFunc({ |msg, time, addr, recvPort|
    postMsg.(format("%:%: %\n", addr.ip, addr.port, msg));
    skeletonParticles.(msg[1]);
}, '/new_skel');

oscSkeletonJoint = OSCFunc({ |msg, time, addr, recvPort|
    var id, joint, x, y, z;
    // postf("from % received %\n", addr, msg);
    id = msg[2].asInteger;
    joint = msg[1];
    #x, y, z = [
        msg[3].linlin(0.0, 1.0, 0, world.width),
        msg[5].linlin(0.0, 5.0, 0, world.height),
        msg[4].linlin(0.0, 1.0, 0, world.depth)
    ];
    // XXX
    // if (world.calibration.booleanValue) {
    //     #x, y, z = [
    //         msg[3].linlin(-0.1, 1.1, 0, world.width),
    //         msg[4].linlin(-0.15, 0.99, 0, world.depth),
    //         msg[5].linlin(0.3, 3.4, 0, world.height)
    //     ];
    // } {
    //     #x, y, z = [
    //         msg[3].linlin(-0.1, 1.1, 0, world.width),
    //         msg[5].linlin(0.3, 3.4, 0, world.height),
    //         msg[4].linlin(-0.15, 0.99, 0, world.depth)
    //     ];
    // };
    skeletonParticles.(id, joint, x, y, z);
}, '/joint');

oscGroupTree = OSCFunc({ |msg, time, addr, recvPort|
    // Parses /g_queryTree.reply:
    // [ /g_queryTree.reply, 0, 1008, 2, 1014, -1, bass__a2, 1010, 2, 1012, -1, atru__a2, ... ]
    // and fills out synth name for a particle as well as formats server tree
    var name, part;
    // postMsg.(format("%:%: %\n", addr.ip, addr.port, msg));
    part = particles.select { |p| p.at(\synth).isNil };
    part.keysValuesDo { |p, dict|
        try {
            name = msg[msg.indexOf(dict[\node])+2];
            name = name.asString.split($_);
            dict[\synth] = name[0];
        }
    };
    // fill out srv tree
    if (msg[2] == 0) {
        {
            srvTreeView.string = ~formatSrvTree.(msg);
            srvTreeView.stringColor = Color.gray(0.7);
            srvTreeView.setStringColor(Color.green, 0, 6);
        }.defer
    };
}, '/g_queryTree.reply');

// PHYSICS
//
physics = TraerParticleSystem.new;
particles = IdentityDictionary.new;
springs = IdentityDictionary.new;

// Star is in the center.
star = initParticle.(world.starMass, world.width/2, world.height/2, world.depth/2);
applyAttractions.(star, world.mutualAttraction);

// Animate!
viewWorld.animate = true;

{ // GLOBAL APP CLOCK. Resolution: 100 milliseconds (0.1 of a second)
    while {win.isClosed.not} {
        tick = tick + 1;
        if (tick > 1e+6) { tick = 0 };

        // fill out srvTree
        if (tick % 20 == 0) { ~scsynth.sendMsg("/g_queryTree", 0) };

        if (animateSeq) {
            count = count + 1;
            shade = (count % 8) * 0.1;
            if (blinked < 24) { // = 8 * 3times
                // blinking next event info AFTER switch
                stCurrInfo.stringColor = Color.red(shade);
                stNextInfo.stringColor = Color.green(shade);
                blinked = blinked + 1;
            } {
                if ((waitNextEvent < 4) && (waitNextEvent > 0)) {
                    // blinking next event info BEFORE switch (in 4 sec)
                    stNextInfo.stringColor = Color.red(shade);
                } {
                    // static color
                    stCurrInfo.stringColor = fontColor;
                    stNextInfo.stringColor = fontColor;
                }
            };
            timeLabel.string = ~convertTime.(count / 10);
            // process waiting time
            waitNextEvent = waitNextEvent - 0.1;
            if ((waitNextEvent <= 0.0) && (waitNextEvent > -0.2)) {
                ~sendMessage.('/action', [\event, 1]);
            };
        };

        viewConn.refresh;

        0.1.wait;
    }
}.fork(AppClock);

// physics and miscellaneous parameters controlled by MIDI
MIDIIn.connectAll;
(worldParams.values ++ miscParams.values).do { |element|
    if (element.keys.includes(\midicc) && element[\gui].isNil.not) {
        MIDIFunc.cc({ |val, ccNum, chan, srcID|
            {
                element[\gui].valueAction_(
                    ~valAsApec.(element).map(\midinote.asSpec.unmap(val))
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

cleanExit = {
    // clean world from particles
    removeAll.();
    // remove OSC functions
    oscParticle.free;
    oscSkeletonNew.free;
    oscSkeletonLost.free;
    oscSkeletonJoint.free;
    oscGroupTree.free;
    // stop meter view explicitly to remove synths for internal levels
    meterView.stop;
    // close all windows
    win.close;
    winSrv.close;
    // disconnect MIDI
    MIDIIn.disconnectAll;
};

CmdPeriod.doOnce({
    cleanExit.();
});

win.front;
)