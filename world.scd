// Sympli Romatikó
// module: World
// ---------------
(
var world, worldTrace, center, skel;
var worldParams, miscParams;
var star, physics, particles, springs, position;
var synths, sGroupId;
var oscParticle, oscPhysics, oscAction,
    oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost,
    oscRemoveFunc, oscGroupTree;
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
var win, viewTop, viewTopLeft, viewTopCenter, viewTopRight,
    viewWorld, viewLeft, viewRight, viewBottom,
    paneWidth, paneHeight, compView, compViewFlow, panel,
    sText, dropdown, slider, button, buttonCheckbox, updateButtonLabel;
var postListener, postMaxSize=1e+5;
var scale, translate, focal;
var paramsChanged;
var stat, clean;
var trigSynth, synthNames, trigCodes;
var keyboardFunc, postMsg, fileNames;
var eventInfo, switchEvent, processEvents, getKey;
var groupNew, groupRemove, sendPhysics, sendSNew, sendNSet, taskPlay;
var animateSeq, shade, current, next, count=0, blinked=0;
var ddSequence, btCurrNum, stCurrInfo, btNextNum, stNextInfo, timeLabel, updateGui;
var internalInLevels, internalOutLevels,
    oscInternalInLevels, oscInternalOutLevels;
var transparent=Color.grey(alpha:0.01),
    font=Font("Monaco", 14),
    fontSmall=Font("Monaco", 10),
    fontLarge=Font("Monaco", 14),
    fontLarge1=Font("Monaco", 18),
    fontGiant=Font("Monaco", 24),
    fontColor=Color.gray(0.8);
var tmp;

// INITIAL
//
// XXX - re-factor
// `physics` -> `world`::`EnTraerWorld`(TraerParticleSystem) // EnTraer == Entropia of Traer Physics
// all functions that work with particles and springs -> methods of `world`
//
//
worldParams = (
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
        midicc: 14,
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
        hint: "static image if in calibration mode",
    ),
);

// The World is a cube.
world = Dictionary.new;
world = (
    width: Window.screenBounds.height*0.82,
    height: Window.screenBounds.height*0.82,
    depth: Window.screenBounds.height*0.82
);
worldParams.keysValuesDo { |k, v| world[k] = v[\default] }; // set default params

worldTrace = Dictionary.newFrom(world); // tracing changes of the world

// dictionary of the synths symbolic IDs vs. server Nodes
synths =Dictionary.new;
sGroupId = s.nextNodeID; // Group for synths not connected to objects.
s.sendMsg("/g_new", sGroupId);

// skeletons
skel = (waitBeforeRemove: 5, limit: 1);
skeleton = Dictionary.new;
jointVisible = [\l_hand, \l_elbow, \neck, \r_elbow, \r_hand]; // visualize only these joints
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
    37, "l", 41, ";", 39, "\"", 42, "\\"
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

// Get only filenames from sequence paths.
fileNames = { |paths|
    paths[..1] ++ paths[2..].collect({|a| PathName(a).fileName })
};

// Miscelaneous parameters for GUI elements controllable by MIDI.
miscParams = Dictionary.new;

// Updates value of a GUI element upon sending a message to the world.
// Sets .value, not .valueAction, because the action is performed already.
updateGui = { |params|
    params.pairsDo { |parm, val|
        try { worldParams[parm][\gui].value_(val) }
    }
};

// SEQUENCE
//
// Obtain the key next/prev to current.
getKey = { |curr, next=1|
    var k, c;
    k = ~sequence.events.keys.asArray.asInteger.sort;
    c = k.indexOf(curr) ? -1;
    k[c + next] ? k[0]; // Go back to beginning upon reaching the upper threshold.
};


// Converts all event's [\info] keys into info string.
eventInfo = { |k=nil, lim=50|
    var infoStr, val, sF;
    val = ~sequence.events.atFail(k, {[]});
    sF = { |l| format(" %\n", if (l.size <= lim) {l} {l[..lim] ++ "..."})};
    infoStr = all{: sF.(l[\info].asString), l <- val, l.keys.includes(\info)};
    infoStr = "".catList(infoStr);
    infoStr[..(infoStr.size-2)]; // cut last \n
};

// Sets a label to a button in a current state.
updateButtonLabel = { |btn, label|
    var states=btn.states;
    states[btn.value][0] = label;
    btn.states = states;
};

// Switches to the next or prev event in a sequence
// and updates GUI.
switchEvent = { |nxt=1|
    if (~sequence.isNil.not) {
        if (~sequence.size > 0) {
            current = getKey.(current, nxt);
            updateButtonLabel.(btCurrNum, current);
            stCurrInfo.string = eventInfo.(current);

            next = getKey.(current, 1);
            updateButtonLabel.(btNextNum, next);
            stNextInfo.string = eventInfo.(next);

            // bring it on!
            blinked = 0; // blinking several times with red, then change to grey.
            if (animateSeq.not && (nxt > 0)) { animateSeq = true };
            processEvents.(current);
        }
    }
};

// Send World parameter(s).
sendPhysics = { |params|
    params = Dictionary.newFrom(params);
    params.keysValuesDo { |k, v|
        if (v == \default) { params[k] = worldParams[k][\default] }
    };
    params = params.asKeyValuePairs;
    ~sendMessage.('/physics', params);
    updateGui.(params)
};

// Run or stop task.
taskPlay = { |task, play=false|
    try {
        if (play) {
            task.play(doReset:true)
        } {
            task.stop.reset;
        }
    } { |err|
        postMsg.(format("Error while trying to switch task % on or off:\n%\n", task, err));
    };
};

// XXX - move this to envi.scd
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

// Send \n_set message to server.
sendNSet = { |data|
    s.listSendMsg(["/n_set",
        synths.at(data[\synth].atFail(\id), {nil})]
        ++ data[\synth].atFail(\params, {[]})
    )
};

groupNew = { |data, time=0.1|
    synths.put(data[\id], ~groupInitCustom.(data, time));
};

// Release all synths from group, wait until released, then remove group node from server.
groupRemove = { |data|
    var params=();
    try { params.putPairs(data.atFail(\params, {[]})) };
    ~groupFree.(synths[data[\id]], params.atFail(\release, {2}));
    synths.removeAt(data[\id]);
};


// Process specific key from sequence.
processEvents = { |key|
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
//
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
    .font_(font)
    .canFocus_(false)
};
buttonCheckbox = { |par, label, labelColor, bgColor, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .states_([
        [label, labelColor ? fontColor, bgColor ? transparent],
        [label, bgColor ? transparent, labelColor ? fontColor]
    ])
    .font_(font)
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


// GUI: Window
win = Window("world", Window.screenBounds.width@Window.screenBounds.height, false);
win.view.decorator = FlowLayout(win.view.bounds, 1@1, 1@1);
win.background = Color.black;

// GUI: Top-level layout
viewTop = compViewFlow.(win, scaleH:0.07);
viewLeft = compViewFlow.(win,
    scaleW:(0.5*(win.bounds.width-world.width)/win.bounds.width),
    scaleH:world.height/win.bounds.height
);
viewWorld = UserView(win, world.width@world.height);
viewRight = compViewFlow.(win,
    scaleW:(0.5*(win.bounds.width-world.width)/win.bounds.width),
    scaleH:world.height/win.bounds.height
);
viewBottom = compViewFlow.(win,
    scaleH:(win.bounds.height-(viewWorld.bounds.height+viewTop.bounds.height))/win.bounds.height
);

// GUI: scheduler
viewTopLeft = compViewFlow.(viewTop, scaleW:0.16);
viewTopCenter = compViewFlow.(viewTop, gap:8@4, scaleW:0.7);
viewTopRight = compViewFlow.(viewTop, scaleW:0.14);

// current event number and info
miscParams[\prev] = ( // make it controllable by midi
    midinote: 46,
    gui: btCurrNum
);
stCurrInfo = sText.(viewTopCenter, "...", stringFont:fontLarge1, scaleW:0.44, scaleH:1);
stCurrInfo.align = \right;
btCurrNum = button.(viewTopCenter, ">>",
    bgColor:Color.gray(0.15), scaleW:0.05
).action_({ |bt| switchEvent.(-1)});
// next (awaiting) event number and info
btNextNum = button.(viewTopCenter, "<<",
    bgColor:Color.gray(0.15), scaleW:0.05
).action_({ |bt|
    switchEvent.(1)
});
miscParams[\next] = ( // make it controllable by midi
    midinote: 43,
    gui: btNextNum
);
stNextInfo = sText.(viewTopCenter, "", stringFont:fontLarge1, scaleW:0.44, scaleH:1);

// time elapsed since the start
timeLabel = sText.(viewTopRight, ~convertTime.(0), stringFont:fontGiant, scaleW:1);
timeLabel.align = \right;

// open file with sequence
ddSequence = dropdown.(viewTopLeft, "sequence",
    items: fileNames.(~seqPaths),
    initVal: if (~seqPaths.size > 2) { 2 } { 0 },
    action: { |element|
        var val, states, top=2;

        animateSeq = false;
        case
        { element.value == 1 } {
            Dialog.openPanel({ |path|
                removeAll.();
                val = ~loadSequence.(path);
                element.items = fileNames.(~seqPaths);
                element.value = val;
            });
        }
        { element.value > 1 } {
            removeAll.();
            postMsg.(format("Loading sequence %...\n",
                PathName.new(~seqPaths[element.value]).fileName
            ));
            val = ~loadSequence.(~seqPaths[element.value]); // open from file
            if (val > top) { // place at the top
                ~seqPaths.insert(top, ~seqPaths.pop(val));
                element.items = fileNames.(~seqPaths);
                element.value = top;
            };
        };
        current = -1;
        updateButtonLabel.(btNextNum, getKey.(current, 1).asString);
        stNextInfo.string = eventInfo.(0);
    },
    initAction: true
);
button.(viewTopLeft,
    "stop", bgColor:Color.grey(0.2), scaleW:0.41, scaleH:0.5
).action_({ |bt| ~stopSequence.() });
button.(viewTopLeft,
    "reload", bgColor:Color.grey(0.2), scaleW:0.6, scaleH:0.5
).action_({ |bt|
    ddSequence.valueAction_(ddSequence.value);
});

// GUI: internal levels (dBFS)
panel = compViewFlow.(viewLeft, margin:10@10, scaleH:0.15, scaleW:0.1);
sText.(panel, "0", stringFont:fontSmall, scaleH:0.15, scaleW:0.8).align_(\right);
sText.(panel, "", stringFont:fontSmall, scaleH:0.65, scaleW:1); // gap
sText.(panel, "-80", stringFont:fontSmall, scaleH:0.2, scaleW:0.8).align_(\right);

internalInLevels = Array.fill(s.options.numInputBusChannels, {nil});
internalOutLevels = Array.fill(s.options.numOutputBusChannels, {nil});

tmp = s.options.numInputBusChannels / (
    s.options.numInputBusChannels + s.options.numOutputBusChannels
);
panel = compViewFlow.(viewLeft, margin:10@10, scaleH:0.15, scaleW:tmp);
s.options.numInputBusChannels.do { |j|
    internalInLevels[j] = LevelIndicator(panel, 19@(panel.bounds.height*0.8))
    .background_(Color.clear)
    .warning_(0.7)
    .critical_(0.9)
    .numTicks_(11)
    .numMajorTicks_(3)
    .drawsPeak_(true)
};
sText.(panel, "inputs", stringFont:fontSmall, scaleH:0.15, scaleW:1);
tmp = 0.85 * s.options.numOutputBusChannels / (
    s.options.numInputBusChannels + s.options.numOutputBusChannels
);
panel = compViewFlow.(viewLeft, margin:10@10, scaleH:0.15, scaleW:tmp);
s.options.numOutputBusChannels.do { |j|
    internalOutLevels[j] = LevelIndicator(panel, 19@(panel.bounds.height*0.8))
    .background_(Color.clear)
    .warning_(-6.dbamp)
    .critical_(-3.dbamp)
    .numTicks_(11)
    .numMajorTicks_(3)
    .drawsPeak_(true)
};
sText.(panel, "outputs", stringFont:fontSmall, scaleH:0.15, scaleW:1);

// GUI: post window
panel = compViewFlow.(viewLeft, margin:10@10, scaleH:0.7);
sText.(panel, "", scaleH:0.1, scaleW:1); // gap
panel.decorator.nextLine;
postListener = TextView(panel, (panel.bounds.width-15)@(panel.bounds.height*0.889))
   .editable_(false)
   .font_(fontSmall)
   .stringColor_(fontColor)
   .background_(transparent)
   .hasVerticalScroller_(false)
   .canFocus_(false);

// GUI: stat panel
stat = Dictionary.new;
panel = compViewFlow.(viewRight, margin:5@5, scaleH:0.15);
[
    (label: "particles", func: { physics.particles.size }),
    (label: "springs", func: { physics.springs.size }),
    (label: "attractions", func: { physics.attractions.size }),
    // (label: "entropy", func: {
    //     1.38065e-23 * log( // XXX - find and manage a proper formula!
    //         physics.particles.size.max(1)*
    //         physics.springs.size.max(1)*
    //         physics.attractions.size.max(1)
    //     )
    // }),
    (label: "skeletons", func: { format("% %", skeleton.size, skeleton.keys.asArray) }),
].do { |item|
    var key;
    sText.(panel, format("\t%", item.label), scaleW:0.7);
    item[\gui] = sText.(panel, "0", scaleW:0.3);
    key = item.label.asString.toLower.replace(" ", "_").asSymbol;
    stat[key] = item;
};

// slider controllers for physics params
panel = compViewFlow.(viewRight, scaleH:0.5, margin:10@30);
[
    \drag, \repulsion, \starMass,
    \gravX, \gravY, \gravZ,
    \springRestLen, \springStrength, \springDamp,
    \maxVel, \partInitAccel, \partFreq,
    \partDefaultMass, \partAgeThresh, \partSigmoidRatio,
].do { |key, n|
    worldParams[key][\gui] = slider.(panel, key, worldParams[key]);
    if ((n+1) % 3 == 0) { compViewFlow.(panel, scaleH:0.05)} // gap after every 3rd slider
};

// slider controllers for misc params
panel = compViewFlow.(viewRight, scaleH:0.15, margin:10@30);
miscParams[\serverVolume] = (
    midicc: 12, spec: \db,
    gui: slider.(panel, "sVol", (label: "s.vol", spec: \db))
    .action_({ |sl| s.volume.volume = sl.value })
    .value_(1)
);
miscParams[\maxDist] = (
    midicc: 12,
    gui: slider.(panel, "maxDist",
        (label: "max dist", spec: [1, 30, \lin, 0.1, ~speakers.maxDist])
    )
    .action_({ |sl| ~speakers.maxDist = sl.value })
    .value_(~speakers.maxDist)
);
miscParams[\depth] = (
    midicc: 15,
    gui: slider.(panel, "depth",
        (label: "depth", minval: 1, maxval: 10, step: 0.1, default: ~depth)
    ).action_({ |ez|
        ~depth = ez.value;
        ~sendMessage.('/audio', [\depth, ~depth])
    })
);

panel = compViewFlow.(viewRight, scaleH:0.2, margin:30@30, gap:10@10);
// button based physics params
[\particles, \mutualAttraction, \calibration].do { |key|
    worldParams[key][\gui] = buttonCheckbox.(
        panel,
        worldParams[key][\label],
        bgColor:Color.black, scaleW:0.267, scaleH:0.2
    )
    .value_(worldParams[key][\default])
    .action_({ |bt| sendPhysics.([key, bt.value]) })
};
// button based misc params
miscParams[\removeall] = (
    midinote: 70,
    gui: button.(panel,
        "X", bgColor:Color.black, scaleW:0.405, scaleH:0.2
    ).action_({ |bt| removeAll.() })
);
miscParams[\reset] = (
    midinote: 58,
    gui: button.(panel,
        "RESET", bgColor:Color.black, scaleW:0.405, scaleH:0.2
    ).action_({ |bt|
        worldParams.values.do { |element|
            if (element.keys.includes(\midicc) && element[\gui].isNil.not) {
                element[\gui].valueAction_(element[\default])
            }
        }
    })
);

// GUI: trigger objects keyboard)
keyboardFunc = { |synthName, params, spring=0, mass=1|
    ~sendParticle.(
        particle:(spring:spring, mass:mass),
        synth:(name: synthName, params: params)
    )
};
panel = compViewFlow.(viewBottom, margin:5@10);
trigSynth.do { |key, i|
    var vw;
    if (trigCodes[key].isNil.not) {
        vw = compViewFlow.(panel, scaleW:synthNames.size.reciprocal);
        vw.decorator = FlowLayout(vw.bounds);
        sText.(vw,
            synthNames[key].asString.replace("sr__e__", "").replace("sr__g__", ""),
            scaleW:1
        );
        button.(vw, trigCodes[key].toUpper, bgColor:Color.black, scaleH:0.4)
        .action_({ |bt|
            keyboardFunc.(synthNames[key], spring:1)
        });
        NumberBox(vw, (vw.bounds.width*0.9)@20)
            .clipLo_(0.01)
            .clipHi_(2)
            .step_(0.01)
            .align_(\right)
            .font_(font)
            .normalColor_(fontColor)
            .background_(Color.grey(alpha:0.5))
            .action_({ |nb|
                ~synths[synthNames[key]][\attenuate] = nb.value;
            })
            .value_(
                ~synths.atFail(
                        synthNames[key],
                        {~synths[\sr__e__silent]}
                )[\attenuate]
            )
    }
};


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
            clean.();
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
    // update stat
    stat.keysValuesDo { |key, unit|
        unit[\gui].string = unit.func.();
    };

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
    // Pen.color = Color.new255(48, 45, 92, 150);
    Pen.color = Color.new255(110, 45, 48, 100);
    Pen.fillOval(Rect.aboutPoint(center, world.width/2, world.height/2));

    // depth
    // Pen.color = Color.new255(108, 107, 152, 50);
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
            springMissed = applySpring.(end[0], end[1]);
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
            s.sendMsg("/n_set", particles[particle][\node],
                // particle params
                \ax, ax,
                \ay, ay,
                \az, az,
                \azimuth, azimuth,
                \distance, distance,
                \elevation, elevation,
                \velocity, mag3D.(particle.velocity).distort.pow(10), // scale by sigmoid func (distort), smooth by .pow
                \amp, (
                    particle.mass.clip(0.01, 0.8) // the main contributor to object's loudness is its mass
                    + (mag3D.(particle.velocity) * 0.01) // subtle "colors" due to velocity
                ).clip(0, 1),

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
    Pen.color = Color.grey(0.5);
    Pen.width = 4;
    skeleton.values.do { |sk|
        jointVisible.size.do { |j|
            try {
                Pen.moveTo(Point(sk[jointVisible[j]].position.x, sk[jointVisible[j]].position.y));
                Pen.lineTo(Point(sk[jointVisible[j+1]].position.x, sk[jointVisible[j+1]].position.y));
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

    physics.tick;
};


// Handle collisions with World boundaries.
handleBoundaryCollisions = { |p|
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


// Returns display of a particle "role" (a Star, a skeleton's joint or an ordinary particle).
decodeParticle = { |particle|
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


// Register individual spring in the global dictionary.
registerSpring = { |spring|
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


//
getParticlesSkelVis = {
    all {: v[k], v <- skeleton.values, k <- v.keys,
        jointVisible.includes(k)
    } ? []
};


//
getParticlesHidden = {
    all {: v[k], v <- skeleton.values, k <- v.keys,
        jointVisible.includes(k).not
    } ? []
};


//
getParticlesOnSprings = {
    (
        all {: [g.a, g.b], g <- physics.springs} ? []
    ).flatten
};


// Registers all springs from List in the global dictionary.
registerSprings = { |springsList|
    springsList.do { |spring|
        registerSpring.(spring)
    }
};


// Translates spring end from joint name to particle.
resolveSpringEnd = { |end|
    if (springSrcSkel.includes(end)) {
        try {
            end = skeleton[skeleton.keys.asArray[0]][end]
        } {
            end = nil
        }
    };
    end
};


// Finds
getSpringForParticle = { |particle|
    var spring;
    physics.springs.do { |sp|
        if ([sp.a, sp.b].includes(particle)) { spring = sp }
    };
    spring
};


// Figures out full synth name in a form "\sr__%__%"
// based on its short name, or a node, or a living particle.
getSynthName = { |shortName, node, particle|
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


// Sets worlds parameters to spring.
setSpringProp = { |spring, particle|
    if (spring.isNil) {
        spring = getSpringForParticle.(particle)
    };
    spring.setDamping(world.springDamp);
    spring.setRestLength(world.springRestLen);
    spring.setStrength(world.springStrength);
};


// Apply spring: choose a source and connect particle to it.
applySpring = { |particle, source, ks, d, r|
    var spring;
    if (source.isNil) { source = defineSource.() };
    source = resolveSpringEnd.(source);
    particle = resolveSpringEnd.(particle);
    if (particle.isNil.not && source.isNil.not) {
        spring = physics.makeSpring(source, particle,
            ks ? world.springStrength, d ? world.springDamp, r ? world.springRestLen);
    };
    spring
};


// Apply forces:
// - skeleton's hands ALWAYS attracts all particles, including Star, regardless of the `mutual` state
// - Star ALWAYS attract all objects, excluding skeleton's hands
// - ordinary objects attract each other only if `mutual` is true
applyAttractions = { |particle, mutual=false|
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


// Choose a source (skeleton with the "lightest" hand).
chooseSource = {
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


// Select source of force depending on the presence of skeleton.
defineSource = { |starAllowed=false|
    if (skeleton.keys.size > 0) {
        chooseSource.()
    } {
        if (starAllowed) { star } { nil }
    }
};


// Define guide (where obj appears) depending on objects velocity.
defineGuide = {
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

// Get object's guide, if any.
getGuide = { |particle|
    var spring, guide;
    spring = getSpringForParticle.(particle);
    if (spring.isNil.not) {
        guide = spring.a
    };
    guide
};


// Init new particle.
initParticle = { |mass, x, y, z, age, vel|
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


// Particle system.
particleSystem = { |guide|
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
            ~groupInit.(world.partSynth, params:[\att, 2.0.rand])
        );
    }
};


// Remove spring.
removeSpring = { |spring|
    springs.removeAt(spring.identityHash);
    physics.removeSpring(spring);
};


// Remove attraction.
removeAttraction = { |attraction|
    physics.removeAttraction(attraction);
};


// Remove a particle.
removeParticle = { |particle|
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


// Remove all particles from the world and stop all synths.
removeAll = {
    particles.keys.do { |p, i|
        unregisterParticle.(particles[p][\node]);
        removeParticle.(p);
    }
};


// Register and unregister particle are separate functions
// from init and remove to support the case when an existing
// particle is being re-attached to a different node on the server.
//
// Register particle in the dictionary along with Server nodeId.
registerParticle = { |particle, nodeId|
    var taskSendMsg, keys=[];
    particles.put(particle, (node: nodeId));
    taskSendMsg = Task({
        inf.do { |j|
            try { keys = particles[particle].keys } { keys = [] };
            if ((keys.includes("synth")) || (j >= 20)) { // wait 2sec
                taskSendMsg.stop;
            };
            s.sendMsg("/g_queryTree", nodeId); // to fill out synth name
            0.1.wait;
        };
    }).start;
};


// Removes particle record from the dictionary.
unregisterParticle = { |nodeId|
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
// Creates a particle for each joint of the skeleton.
skeletonParticles = { |id, joint, x, y, z|
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


// Removes skeleton particles (cannot be removed as ordinary particles).
skeletonRemove = { |id|
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
// 3-d vector(s) magnitude.
// `vec` can be either dictionary-like object (x:x, y:y, z:z), in which case
// a siggle float value of the magnitude is returned, or a collection of such
// objects, which result in a collection of magnitudes.
mag3D = { |vec|
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


// Simple sigmoid function.
sigmoid = { |ratio, value| 1 / (1 + exp((ratio * value).neg))};


// Project 3D coordinates on the plane.
// pos = Dictionary[x, y, z]
// space = Dictionary[width, height, depth]
xyz2plane = { arg pos, space, scale=1, focal=0.5;
    var x, y, z, ox, oy;
    z = space.depth - pos.z / (space.depth * scale);
    z = z.linlin(0, space.depth, focal, 1);
    x = pos.x * z;
    y = pos.y * z;
    ox = 1 - z * (space.width * 0.5) + x;
    oy = 1 - z * (space.height * 0.5) + y;
    [ox, oy]
};


// Returns azimuth, distance and elevation for a position defined as [x, y, z]
xyz2ade = { |position|
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


// Converts (azimuth, distance, elevation) to (x, y, z)
ade2xyz = { |position, maxDist|
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


// Returns x, y and z in required format.
xyz = { |position|
    [
        position.x / world.width,
        position.y / world.height,
        position.z.linlin(0, world.depth, 1, 0) // inverse
    ]
};


// XXX - change this with re-directing all POST messages
// post message to local listener
postMsg = { |msg|
    msg = msg.asString;
    if (msg.endsWith("\n").not) { msg = msg ++ "\n" };
    {
        if (postListener.string.size > postMaxSize) { // do not grow too long
            postListener.string = postListener.string[(postListener.string.size-postMaxSize)..]
        };
        postListener.string = postListener.string ++ msg ++ "\n";
        postListener.stringColor_(fontColor);
        postListener.select(postListener.string.size, 1); // autoscroll
    }.defer;
    msg.post;
};


// OSC
//
// Catch messages related to particles.
oscParticle = OSCFunc({ |msg, time, addr, recvPort|
    var particle, node, age, mass, x, y, z, spring, registered;
    // postf("from % received %\n", addr, msg);
    postMsg.(format("from % received %\n", addr, msg));
    node = msg[2];
    msg[1].switch(
        1, { // create particle
            mass = msg[4];
            try {
                #x, y, z, age = msg[5..]
            } {
                #x, y, z, age = nil ! 4
            };
            particle = initParticle.(mass, x, y, z, age);
            registerParticle.(particle, node);
            if (msg[3].booleanValue) {
                spring = applySpring.(particle);
                registered = registerSpring.(spring);
            };
            if (msg[3].booleanValue.not || registered.isNil) {
                // "spring" can be specified, but failed
                // in this case apply attractions
                applyAttractions.(particle, world.mutualAttraction)
            };
        },
        0, { // remove particle
            particle = unregisterParticle.(node);
            removeParticle.(particle);
        }
    );
}, '/particle');


// Catch messages related to physics.
oscPhysics = OSCFunc({ |msg, time, addr, recvPort|
    var x, y, z;
    // postf("from % received %\n", addr, msg);
    postMsg.(format("from % received %\n", addr, msg));
    msg[1].switch(
        \gravity, {
            #x, y, z = msg[2..].asFloat;
            world.gravX = x;
            world.gravY = y;
            world.gravZ = z;
        },
        \gravX, { world.gravX = msg[2].asFloat },
        \gravY, { world.gravY = msg[2].asFloat },
        \gravZ, { world.gravZ = msg[2].asFloat },
        \drag, { world.drag = msg[2].asFloat },
        \repulsion, { world.repulsion = msg[2].asFloat },
        \mutualAttraction, { world.mutualAttraction = msg[2].asInteger },
        \particles, { world.particles = msg[2].asInteger },
        \star, {
            msg[2].switch(
                \fixed, { star.makeFixed },
                \free, { star.makeFree },
                \mass, {
                    try {
                        world.starMass = msg[3].asFloat
                    }
                },
                \pos, {
                    try {
                        #x, y, z = msg[3..].asFloat
                    } {
                        #x, y, z = [world.width.rand, world.height.rand, world.depth.rand]
                    };
                    star.position.set(x, y, z);
                }
            );
        },
        { // default action
            try { world[msg[1]] = msg[2]};
        }
    );
}, '/physics');


// Catch action messages.
oscAction = OSCFunc({ |msg, time, addr, recvPort|
    // postf("from % received %\n", addr, msg);
    postMsg.(format("from % received %\n", addr, msg));
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
        }
    );
}, '/action');


// Catch messages related to skeleton.
oscSkeletonLost = OSCFunc({ |msg, time, addr, recvPort|
    // postf("from % received %\n", addr, msg);
    postMsg.(format("from % received %\n", addr, msg));
    skeletonRemove.(msg[1]);
}, '/lost_skel');


oscSkeletonNew = OSCFunc({ |msg, time, addr, recvPort|
    // postf("from % received %\n", addr, msg);
    postMsg.(format("from % received %\n", addr, msg));
    skeletonParticles.(msg[1]);
}, '/new_skel');

oscSkeletonJoint = OSCFunc({ |msg, time, addr, recvPort|
    var id, joint, x, y, z;
    // postf("from % received %\n", addr, msg);
    id = msg[2].asInteger;
    joint = msg[1];
    #x, y, z = [
        msg[3].linlin(-0.1, 1.1, 0, world.width),
        msg[5].linlin(0.3, 3.4, 0, world.height),
        msg[4].linlin(-0.15, 0.99, 0, world.depth)
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
    var synth, i=0, node=msg[2].asInteger;
    // postf("from % received %\n", addr, msg);
    { synth.isNil }.while({
        i = i + 1;
        if ("sr__(e|g|p)__".matchRegexp(msg[i].asString)) {
            synth = msg[i].asString.stripWhiteSpace;
            synth = synth[7..]; // only synth type and name
        };
        if ((i >= msg.size) && (synth.isNil)) { synth = node.asString };
    });
    particles.keysValuesDo { |part, dict|
        if (dict[\node] == node) { dict[\synth] = synth }
    };
}, '/g_queryTree.reply');

// XXX - GET msgs from remote server!
oscInternalInLevels = OSCFunc({ |msg, time, addr, recvPort|
    {
        internalInLevels.do { |elem, j|
            elem.peakLevel = msg[3+(j*2)].ampdb.linlin(-80, 0, 0, 1);
            elem.value = msg[3+(j*2+1)].ampdb.linlin(-80, 0, 0, 1);
        }
    }.defer;
}, '/internalInLevels');

oscInternalOutLevels = OSCFunc({ |msg, time, addr, recvPort|
    {
        internalOutLevels.do { |elem, j|
            elem.peakLevel = msg[3+(j*2)].ampdb.linlin(-80, 0, 0, 1);
            elem.value = msg[3+(j*2+1)].ampdb.linlin(-80, 0, 0, 1);
        }
    }.defer;
}, '/internalOutLevels');

// Remove all OSC functions.
oscRemoveFunc = {
    oscParticle.free;
    oscSkeletonNew.free;
    oscSkeletonLost.free;
    oscSkeletonJoint.free;
    oscGroupTree.free;
    oscInternalInLevels.free;
    oscInternalOutLevels.free;
};


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
        if (animateSeq) {
            count = count + 1;

            // blinking "next event" info.
            shade = (count % 8) * 0.1;
            if (blinked < 40) { // = 8 * 5times
                stCurrInfo.stringColor = Color.red(shade);
                stNextInfo.stringColor = Color.green(shade);
                blinked = blinked + 1;
            } {
                stCurrInfo.stringColor = fontColor;
                stNextInfo.stringColor = fontColor;
            };
            timeLabel.string = ~convertTime.(count / 10);

            if (count % 10 == 0) {
                // TODO: process timemarks
            };
        };
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

// clean everything on exit
clean = {
    oscRemoveFunc.();
    removeAll.();
    win.close;
    MIDIIn.disconnect;
};

CmdPeriod.doOnce({
    clean.();
});

win.front;
)