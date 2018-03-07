// Sympli Romatikó
// module: World
// ---------------
(
var skel, physics, springs, particles, particle, star;
var world, center, canvas, frame, item, color;
var miscParams, event, updateWorldParm;
var oscParticle, oscPhysics, oscAction,
    oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost,
    oscGroupTree, reportOSC, reportEvent;
var drawCalibration, drawSkel, drawSkelJoints, drawSkelParticle,
    drawCube, drawGraph, drawStrob;
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
var mag3D, sigmoid, xyz, xyz2ade, ade2xyz, xyz2plane, getPointPlane;
var ax, ay, az, azimuth, distance, elevation,
    guide, gx, gy, gz, gAzimuth, gDistance, gElevation;
var transX, transY, transZ, transRate=0.005;
var attractionsPhysical, springsPhysical, springMissed,
    particlesOnSprings, particlesSkelVis, particlesHidden,
    partColor, partSize;
var listenerPos, currSpeaker;
var ccCurrSynthParam, labelAr, labelKr, guiAr, guiKr, guiSynthCtrls, mute;
var win, viewTop, viewSeqList, viewTopCenter, viewSeqTime,
    viewWorld, viewConn, viewLeft, viewRight, viewBottom,
    panelSrvLeft, panelSrvRight, viewSeqEvents, stPastEvents, stFutureEvents,
    paneWidth, paneHeight, compView, compViewFlow, panel,
    sText, dropdown, listView, slider, knob, button, buttonCheckbox,
    scrollInfo;
var winSrv, palette, meterView;
var postView, postMaxSize=1500;
var scale, translate, focal;
var paramsChanged;
var cleanExit;
var fileNames;
var postMsg, updatePostColors, getMsgColor, postColors=List.new;
var eventInfo, switchEvent, processEvents, getKey;
var groupNew, groupRemove, sendSNew, sendNSet, taskPlay;
var animateSeq, shade, current, next, count=0, blinked=0, tick=0;
var ddSequence, btCurrNum, stCurrInfo, btNextNum, stNextInfo, timeLabel;
var updateGui, updateGuiElement;
var transparent=Color.grey(alpha:0.01),
    techColor=Color.green(0.5),
    font=Font("Monaco", 14),
    fontSmall=Font("Monaco", 10),
    fontMedium=Font("Monaco", 12),
    fontLarge=Font("Monaco", 14),
    fontLarge1=Font("Monaco", 18),
    fontGiant=Font("Monaco", 24),
    fontColor=Color.gray(0.7),
    colorStar=Color.red,
    colorJoint=Color.new255(173, 58, 0),
    colorParticle=Color.white;
var waitNextEvent= -1;
var kwargs;
var patt = Pn(Pshuf(#[0, 0, 0, 0, 0.1, 0.25, 0.5, 0.75, 1, 1], 8), inf).asStream;
var tmp; // Warning: use this variable only in drawFunc!

// // XXX 3d
// var cubes=Dictionary.new;
// var registerCube = { |particle|
//     if (particle == star) { color = Color.red } { color = Color.green };
//     item = Canvas3DItem.cube
//     .color_(color)
//     .width_(0.5)
//     .transform(Canvas3D.mScale(0.1));
//     canvas.add(item);
//     cubes[particle] = item
// };

//
var prettyPrintDict = { |data, output="", level=0|
    var report = { |k, v|
        format("%%: %\n", "".catList(Array.fill(level, "    ")), k, v ? '');
    };
    data.keysValuesDo { |key, val|
        if ([Dictionary, Event].includes(val.class)) {
            output = prettyPrintDict.(val, output ++ report.(key), level+1)
        } {
            output = output ++ report.(key, val);
        }
    };
    output
};
var eventPool = (
    items: List.new,
    append: { |self, item|
        self.report(item);
        self.items.add(item)
    },
    delete: { |self, index=0|
        try {
            self.items.removeAt(index)
        } { |err|
            postMsg.(format("% (%)\n", err.errorString, err.class))
        }
    },
    popItem: { |self|
        var top = self.items[0];
        self.delete;
        top
    },
    report: { |self, item|
        postMsg.(format("$> added to eventPool\n"));
        postMsg.(format("%\n", prettyPrintDict.(item, level:1)));
    }
);

// XXX - experimental
var pointFrom, pointTo, numUnitsX, numUnitsY,
    gridUnit=10, isGrid=false, scaleDepth=1, focalPoint=3, renew=100, hold=0,
    lineColor, xyA, xyB, xyDevA, xyDevB, deviation;
var drawLine = { |pointA, pointB, lineColor, lineWidth=1|
    Pen.width = lineWidth;
    Pen.strokeColor = lineColor ? Color.white;
    Pen.moveTo(pointA.x@pointA.y);
    Pen.lineTo(pointB.x@pointB.y);
    Pen.stroke;
};
var focalStream = Pbrown(0.3, Pwrand([0.7, 1, 3], #[10, 2, 1].normalizeSum, inf), 0.1, inf).asStream;
var scaleStream = Pgbrown(0.3, Pwrand([0.7, 1, 1.5], #[5, 2, 1].normalizeSum, inf), 0.1, inf).asStream;
var randomize = { |n, dev, factor=0.25|
    n + (1.rand2 * rrand(dev, dev * factor))
};
var visCount=0;
var paths = [
    [
        [\head, \neck],
        [\l_hand, \l_elbow, \l_shoulder, \l_hip, \l_knee, \l_foot],
        [\r_hand, \r_elbow, \r_shoulder, \r_hip, \r_knee, \r_foot],
        [\r_shoulder, \l_shoulder],
        [\r_hip, \l_hip],
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \neck, \r_shoulder, \r_elbow, \r_hand],
        [\l_shoulder, \torso, \r_shoulder],
        [\l_foot, \l_knee, \l_hip, \torso, \r_hip, \r_knee, \r_foot]
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \r_hip, \r_knee, \r_foot],
        [\r_hand, \r_elbow, \r_shoulder, \l_hip, \l_knee, \l_foot],
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \l_hip, \l_knee, \l_foot],
        [\r_hand, \r_elbow, \r_shoulder, \r_hip, \r_knee, \r_foot],
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \r_shoulder, \r_elbow, \r_hand],
        [\l_foot, \l_knee, \l_hip, \r_hip, \r_knee, \r_foot],
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \l_hip, \l_knee, \l_foot],
        [\r_hand, \r_elbow, \r_shoulder, \r_hip, \r_knee, \r_foot],
        [\l_hand, \r_hand],
        [\l_elbow, \r_elbow],
        [\l_shoulder, \r_shoulder],
        [\l_hip, \r_hip],
        [\l_knee, \r_knee],
        [\l_foot, \r_foot],
    ]
];
var currPath = paths.choose;
// XXX - experimental end


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
    // particle system
    particleSystem: (
        label: "particl",
        default: false,
        midinote: 45,
        hint: "run particle system",
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
        default: "pulse",
    ),
    // misc
    skelSimulSpeed: (
        label: "simul vel",
        minval: 0.001,
        maxval: 0.005,
        default: 0.002,
        midicc: 34,
        hint: "speed of skeleton simulation",
    ),
    mutualAttraction: (
        label: "mutual",
        default: true,
        midinote: 44,
    ),
    internalBuf: (
        label: "internal buf",
        default: false,
        hint: "granular synths use internal buffer instead of samples",
    ),
    draw: (
        label: "drawing mode",
        default: \calibration,
        hint: "drawing mode description",
    ),
);

var reshape = { |src|
    var rec, res=List.new;
    src.keys.do { |k|
        rec = (
            id: k,
            node: src[k][\node],
            synth: src[k][\synth],
            params: src[k].atFail(\params, {Dictionary.new}),
        );
        rec[\out] = rec[\params].atFail(\out, {~outbus});
        res.add(rec)
    };
    res
};
// WARNING! all synths of a particular class should be help in the same dict for display!
// .ar - sorted by node
var synthsAr = ( );
// .kr - dictionary of LFOs with node as a key
var synthsLFO = ( );
// .kr - sorted by outbus
var synthsKr = ( );
// Skeleton simulation
var skelData;
var loadSkelData = {
    postf("Reading skeleton simulation data\n");
    skelData = File(~currentDir +/+ "experiments/joints.log", "r").readAllString.interpret;
};
var skelSimul = Task({
    var i=0, coords;
    inf.do {
        // process
        if (i == skelData.size) {i = 0};
        coords = skelData[i][1..];
        ~sendMessage.(\joint, [skelData[i][0], 1] ++ coords);
        i = i + 1;
        world.skelSimulSpeed.wait;
    }
});

// The World is a cube with measurements relative to the screen height.
world = (width: ~worldSize, height: ~worldSize, depth: ~worldSize);
// set default params
worldParams.keysValuesDo { |k, v| world[k] = v[\default]};

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

fileNames = { |paths|
    // Get only filenames from sequence paths.
    paths.collect { |path|
        PathName(path.asString.asAbsolutePath).fileName;
    };
};

// Miscelaneous parameters for GUI elements controllable by MIDI.
miscParams = Dictionary.new;


// Updates value of a GUI element.
// If `action` is true, .valueAction is performed otherwise .value.
updateGuiElement = { |parm, val, action=false|
    if (worldParams[parm].keys.includes(\gui)) {
        if (action) {
            { worldParams[parm][\gui].valueAction_(val) }.defer
        } {
            { worldParams[parm][\gui].value_(val) }.defer
        }
    }
};


// Updates values of multiple GUI elements.
// If `action` is true, .valueAction is performed otherwise .value.
updateGui = { |params, action=false|
    params.pairsDo { |parm, val|
        updateGuiElement.(parm, val, action);
    }
};

// SEQUENCE
//

// Obtains the key next/prev to current.
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


//
scrollInfo = { |curr, next|
    var updateButtonLabel = { |btn, label|
        // Sets a label to a button in a current state.
        var states=btn.states;
        states[btn.value][0] = label;
        btn.states = states;
    };
    var eventsFeed = { |start, stop, feed=""|
        ~sequence.events.keys.select((_ >= start) && (_ < stop))
        .asArray.sort.do { |key|
            feed = feed ++ eventInfo.(key) ++ "\n\n"
        };
        feed[..(feed.size-2)]; // cut one last \n
    };
    updateButtonLabel.(btCurrNum, curr);
    updateButtonLabel.(btNextNum, next);
    stCurrInfo.string = eventInfo.(curr);
    stNextInfo.string = eventInfo.(next);

    stPastEvents.string = eventsFeed.(0, curr, "".catList("\n" ! 5));
    stPastEvents.select(stPastEvents.string.size, 1); // autoscroll
    stPastEvents.stringColor = fontColor;

    stFutureEvents.string = eventsFeed.(next+1, ~sequence.events.keys.maxItem+1);
    stFutureEvents.stringColor = fontColor;
};


// Switches to the next or prev event in a sequence
// and updates GUI.
switchEvent = { |nxt=1|
    var wait;
    if (~sequence.isNil.not) {
        if (~sequence.size > 0) {
            current = getKey.(current, nxt);
            next = getKey.(current, 1);
            scrollInfo.(current, next);

            // bring it on!
            blinked = 0; // blinking several times with red, then change to grey.
            if (animateSeq.not && (nxt > 0)) { animateSeq = true };
            processEvents.(current);

            // reset the clock
            if (current == 0) { count = 0 };

            // reset waiting time globally
            waitNextEvent = -1;
            wait = List.new;
            ~sequence.events[current].do { |msg|
                wait.add(msg.atFail(\wait, {-1}))
            };
            // update waiting time until the next event
            waitNextEvent = wait.maxItem;
            postMsg.(format("INFO: Waiting time for next event: %\n\n", waitNextEvent));
        }
    }
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
        postMsg.(format("ERROR: cannot switch task % on or off:\n%\n", task, err));
    };
};


// Sends synth to server, registers node in `synths`.
sendSNew = { |data|
    var node = ~initSynth.(data[\name], params: data[\params]);
    synths.put(data[\id], node);
};


// Sends \n_set message to server.
sendNSet = { |data|
    var node, params;
    if (data[\synth].keys.includes(\id)) {
        node = synths.at(data[\synth][\id])
    };
    if (data[\synth].keys.includes(\node)) {
        node = data[\synth][\node];
        params = data[\synth].atFail(\params, {[]});
        // update particles dict param
        particles.keysValuesDo { |p, dict|
            if (dict[\node] == node) {
                Dictionary.newFrom(params).keysValuesDo { |key, val|
                    dict[\params][key] = val
                };
            }
        };
    };
    ~scsynth.listSendMsg(["/n_set", node]
        ++ data[\synth].atFail(\params, {[]})
    )
};


// Sends group to server, registers node in `synths`.
groupNew = { |data, time=0.1|
    var node = ~initGroup.(data, time);
    synths.put(data[\id], node);
};


// Release all synths from group, wait until released,
// then remove group node from server.
groupRemove = { |data|
    var params=();
    try { params.putPairs(data.atFail(\params, {[]})) };
    ~groupFree.(synths[data[\id]], params.atFail(\release, { 1 }));
    synths.removeAt(data[\id]);
};


// Updates world[`parm`] with `val` (substitutes 'default' keyword if needed),
// sets a proper value to the GUI controlling given world param.
updateWorldParm = { |parm, val|
    if (val == \default) {
        val = worldParams[parm][\default];
    };
    try { world[parm] = val };
    updateGuiElement.(parm, val);
    val
};


// Process specific num from sequence.
processEvents = { |num|
    ~sequence.events.atFail(num, {[]}).do { |data, l|
        reportEvent.(num, data[\message], l);
        data[\message].switch(
            \physics, {
                data[\params].keysValuesDo { |k, v|
                    eventPool.append((
                        message: \physics,
                        params: [k, updateWorldParm.(k, v)]
                    ))
                };
            },
            \audio, {
                ~sendMessage.('/audio', data[\params])
            },
            \particle, {
                eventPool.append(data);
            },
            \lfo, {
                data[\synth][\params] = ~fillSynthParams.(data[\synth], ~lfos);
                data[\synth][\node] = ~initLFO.(
                    data[\synth][\name],
                    node: data[\synth][\node],
                    params: data[\synth][\params]
                );
                // LFOs container's id is node
                synthsLFO.put(data[\synth][\node], (
                    synth: data[\synth][\name],
                    node: data[\synth][\node],
                    params: data[\synth][\params]
                ));
            },
            \task, {
                taskPlay.(~sequence.tasks[data[\name]], data[\act].booleanValue)
            },
            \s_new, { sendSNew.(data) },
            \n_set, { sendNSet.(data) },
            \g_new, { groupNew.(data) },
            \g_free, { groupRemove.(data) },
            { ~sendMessage.(data[\message], data[\params]) }
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
        { |ez|
            eventPool.append((
                message: \physics,
                params: [name, updateWorldParm.(name, ez.value)]
            ));
        },
        layout:layout, labelWidth:80, numberWidth:40)
    .font_(fontSmall);
    ezs.numberView.canFocus = false;
    ezs.sliderView.canFocus = false;

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
panelSrvLeft = compViewFlow.(winSrv, scaleW:0.57);
panel = compViewFlow.(panelSrvLeft, scaleH:0.3);
meterView = EntroServerMeterView(~scsynth, panel, 0@0, 210);

// GUI: sequence panel
panelSrvRight = compViewFlow.(winSrv, scaleW:0.43);
viewSeqList = compViewFlow.(panelSrvRight, scaleH:0.1, scaleW:0.65);
viewSeqTime = compViewFlow.(panelSrvRight, margin:5@5, gap:5@5, scaleH:0.1, scaleW:0.35);
viewSeqEvents = compViewFlow.(panelSrvRight, gap:8@4, scaleH:0.86);
// time elapsed since the start
timeLabel = sText.(viewSeqTime, ~convertTime.(0), stringFont:fontLarge1, scaleW:1, scaleH:0.7);
timeLabel.align = \center;
stPastEvents = TextView(viewSeqEvents, viewSeqEvents.bounds.width@(viewSeqEvents.bounds.height*0.25))
    .editable_(false)
    .font_(fontMedium)
    .stringColor_(fontColor)
    .background_(transparent)
    .hasVerticalScroller_(false)
    .canFocus_(false)
    .string_("...\n...\n...");

// current event number and info
btCurrNum = button.(viewSeqEvents, ">>", bgColor:Color.gray(0.15), scaleH: 0.05)
    .action_({ |bt| switchEvent.(-1) });
stCurrInfo = sText.(viewSeqEvents, "[...]", stringFont:fontLarge, scaleW:1, scaleH:0.15);
// next (awaiting) event number and info
btNextNum = button.(viewSeqEvents, "<<", bgColor:Color.gray(0.15), scaleH: 0.05)
    .action_({ |bt| switchEvent.(1) });
stNextInfo = sText.(viewSeqEvents, "...next", stringFont:fontLarge, scaleW:1, scaleH:0.12);
stFutureEvents = TextView(viewSeqEvents, viewSeqEvents.bounds.width@(viewSeqEvents.bounds.height*0.8))
    .editable_(false)
    .font_(fontMedium)
    .stringColor_(fontColor)
    .background_(transparent)
    .hasVerticalScroller_(false)
    .canFocus_(false);
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
    initVal: if (~seqPaths.size > 0) { 1 } { 0 },
    action: { |element|
        var val, path;
        animateSeq = false;
        removeAll.();
        if (element.value == 0) {
            // open dialog to load sequence
            Dialog.openPanel({ |path|
                val = ~loadSequence.(path);
                element.items = fileNames.(~seqPaths);
                element.value = val;
            });
        } {
            // load seqence from file
            path = ~seqPaths[element.value].asString;
            postMsg.(format("INFO: Loading sequence %...\n",
                PathName.new(path).fileName
            ));
            val = ~loadSequence.(path); // open from file
            if (val > 0) { // place at the top
                ~seqPaths.insert(1, ~seqPaths.removeAt(val));
                element.items = fileNames.(~seqPaths);
                element.value = 1;
                postMsg.("OK...")
            } {
                postMsg.("ERROR!")
            };
        };
        current = -1;
        scrollInfo.(current, 0);
    },
    initAction: true
);
button.(viewSeqList,
    "stop", bgColor:Color.grey(0.2), scaleW:0.41, scaleH:0.55
).action_({ |bt|
    "INFO: removing custom groups / synths".postln;
    synths.keys.do { |k| groupRemove.((id: k)) };
    synthsLFO = ();
    ~stopSequence.();
    animateSeq = false; // stop clock
});
button.(viewSeqList,
    "reload", bgColor:Color.grey(0.2), scaleW:0.63, scaleH:0.55
).action_({ |bt|
    ddSequence.valueAction_(ddSequence.value);
});
miscParams[\rec] = (
    gui: buttonCheckbox.(panelSrvRight,
        "REC.", labelColor: Color.red, bgColor:Color.black, scaleW:0.5, scaleH:0.06
    ).action_({ |bt| postMsg.(~recordAudio.(bt.value)) })
);
miscParams[\intBuf] = (
    gui: buttonCheckbox.(panelSrvRight,
        "int buf", labelColor: Color.red, bgColor:Color.black, scaleW:0.5, scaleH:0.06
    )
    .action_({ |bt|
        var synthIn;
        if (bt.value == 1) {
            //recording synth
            synthIn = Synth(\buffloop, [
                \bufnum, ~internalBuff.bufnum,  \busnum, ~inbus,
                \volIn, 1, \loop, 1, \gate, 1, \dur, 1
            ]);
        } {
            synthIn.free;
        };
        updateWorldParm.(\internalBuf, bt.value);
    })
);

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
panel = compViewFlow.(panelSrvLeft, scaleH:0.56);
[
    \drag, \repulsion, \starMass,
    \gravX, \gravY, \gravZ,
    \springRestLen, \springStrength, \springDamp,
    \maxVel, \partInitAccel, \partFreq,
    \partDefaultMass, \partAgeThresh, \skelSimulSpeed
].do { |key, n|
    worldParams[key][\gui] = slider.(panel, key, worldParams[key]);
    if ((n+1) % 3 == 0) { compViewFlow.(panel, scaleH:0.04)} // gap after every 3rd slider
};

// slider controllers for misc params
panel = compViewFlow.(panelSrvLeft, scaleH:0.1);
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

panel = compViewFlow.(panelSrvLeft, margin:5@5, gap:5@5, scaleH:0.1);
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
miscParams[\skelsimul] = (
    gui: buttonCheckbox.(panel,
        "skel", bgColor:Color.black, scaleW:0.19, scaleH:0.7
    ).action_({ |bt|
        if (bt.value.booleanValue) {
            if (skelData.isNil) {loadSkelData.()};
            skelSimul.start
        } {
            skelSimul.stop
        }
    })
);
sText.(panel, " ", stringFont:fontSmall, scaleH:0.5, scaleW:0.05); // gap
// button based physics params
[\particleSystem, \mutualAttraction].do { |key|
    worldParams[key][\gui] = buttonCheckbox.(
        panel,
        worldParams[key][\label],
        bgColor:Color.black, scaleW:0.19, scaleH:0.7
    )
    .value_(worldParams[key][\default])
    .action_({ |bt|
        eventPool.append((
            message: \physics,
            params: [key, updateWorldParm.(key, bt.value)]
        ))
    })
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
viewConn = UserView(viewRight, viewRight.bounds.width@(viewWorld.bounds.height*0.85));
viewConn.drawFunc = { |view|
    var ind, unit, grid=6, gridMargin=60;
    // synths width depending on the synth type
    var wdtKr = if (synthsLFO.size == 0) {view.bounds.width/4} {(view.bounds.width/synthsLFO.size)-5};
    var wdtAr = (view.bounds.width/particles.size)-5 / ~defaultParams[\ar].size / 2;
    var drawSynth = { |syn, oX, oY, boxWidth, parm, ctl|
        // `parm`: params label (for example, "node [outbus]"), displayed under the synth name
        // `ctl`: [mute, solo], each value is Boolean
        var rect, coords;
        if (ctl.isNil) {ctl=[true, true]};
        oX = oX * (boxWidth + 5); // adjust to the boxWidth
        // main synth container
        coords = [oX, oY, boxWidth, 45]; // save box coords for identifying mouse click
        rect = Rect.fromArray(coords);
        Pen.strokeColor = Color.white;
        try {
            if (syn[\current]) {
                Pen.fillColor = Color.grey(0.15);
                Pen.fillRect(rect);
            };
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
            try {
                if (syn.params[\amp] <= 0) {
                    Pen.fillColor = Color.red(0.75);
                    Pen.fillRect(Rect(oX+(boxWidth-16), oY+15, 15, 15));
                    Pen.color = fontColor;
                };
            };
            Pen.strokeRect(Rect(oX+(boxWidth-16), oY+15, 15, 15));
            Pen.stringAtPoint("M", [oX+(boxWidth-12), oY+15].asPoint);
        };
        // ctrl panel: "solo"
        if (ctl[1]) {
            Pen.strokeRect(Rect(oX+(boxWidth-16), oY+30, 15, 15));
            Pen.stringAtPoint("S", [oX+(boxWidth-12), oY+30].asPoint);
        };
        coords
    };
    var drawConnection = { |synFro, synTo, parmName, wdt, num|
        //
        var parmCoords;
        // stroke param connector in .ar synth
        Pen.strokeColor = techColor;
        Pen.strokeRect(Rect(
            synFro[\coords][0]+(num*wdt*2),
            synFro[\coords][1]-5,
            wdt, 5));
        // stroke param name box
        try {
            parmCoords = synFro[\connCoords][parmName]
        } { |err|
            postMsg.(format("%: No coords for %", err, parmName));
        };
        parmName = parmName.asString;
        if (parmCoords.isNil) {
            parmCoords = [
                synTo[\coords][0] + (wdtKr*0.5) - (parmName.size*5),
                (view.bounds.height - (gridMargin*2)) / grid * (min(num+1, grid)) + 10,
                parmName.size*10, 20
            ]
        };
        Pen.width = 2;
        Pen.fillColor = Color.black;
        Pen.strokeColor = techColor;
        Pen.fillRect(Rect.fromArray(parmCoords));
        Pen.strokeRect(Rect.fromArray(parmCoords));
        Pen.fillColor = Color.green;
        Pen.stringAtPoint(parmName, [parmCoords[0]+5, parmCoords[1]+5].asPoint);
        Pen.strokeColor = Color.grey(0.5);
        // start from .ar synth param
        Pen.moveTo(Point(
            synFro[\coords][0]+(num*wdt*2)+(wdt/2),
            synFro[\coords][1]-5
        ));
        // connect with param name box
        Pen.lineTo(Point(
            parmCoords[0]+(parmCoords[2]*0.5),
            parmCoords[1]+parmCoords[3]
        ));
        // start from param name box
        Pen.moveTo(Point(
            parmCoords[0]+(parmCoords[2]*0.5),
            parmCoords[1]+parmCoords[3]-20
        ));
        // connect with .kr synth
        Pen.lineTo(Point(
            synTo[\coords][0]+(synTo[\coords][2]*0.5),
            synTo[\coords][1]+synTo[\coords][3]+5
        ));
        Pen.stroke;
        Pen.width = 1;
        parmCoords // return connection coordinates for future use
    };

    // stroke grid
    Pen.strokeColor = Color.grey(0.2);
    (view.bounds.width / wdtKr).floor.do { |i|
        tmp = wdtKr * (i + 0.5) + (i * 5);
        Pen.moveTo(Point(tmp, gridMargin));
        Pen.lineTo(Point(tmp, view.bounds.height-gridMargin));
    };
    grid.do { |i|
        tmp = ((view.bounds.height - (gridMargin * 2)) / grid) * (i + 0.5) + gridMargin;
        Pen.moveTo(Point(20, tmp));
        Pen.lineTo(Point(view.bounds.width-20, tmp));
    };
    Pen.stroke;

    // set 'nerd-ish' font to the whole view
    Pen.font_(Font("Andale Mono")).smoothing_(true);

    // .kr
    synthsKr = reshape.(synthsLFO).sortBy('out');
    synthsKr.do { |syn, i|
        syn[\coords] = drawSynth.(
            syn, oX: i, oY: 5,
            boxWidth: wdtKr,
            parm: format("% [%]",
                syn[\node],
                syn[\params].atFail(\out, {~outbus})
            ),
            ctl: [false, false]
        );
        // input for ctrl bus
        Pen.fillColor = Color.white;
        Pen.fillRect(Rect(syn[\coords][0]+(wdtKr*0.5)-2.5, 50, 5, 5));
    };

    // .ar
    synthsAr = reshape.(particles).sortBy('node');
    synthsAr.do { |sn, i|
        unit = particles[sn[\id]];
        unit[\coords] = drawSynth.(
            unit, oX: i, oY: view.bounds.height-50,
            boxWidth: (view.bounds.width/particles.size)-5,
            parm: unit[\node]
        );
        // params ctrl buses
        ~synths[unit[\synth].asSymbol][\params].do { |name, num|
            Pen.fillColor = Color.white;
            Pen.fillRect(Rect(
                unit[\coords][0]+((wdtAr*2)*num),
                unit[\coords][1]-5,
                wdtAr, 5));
            try {
                if (unit[\params][name].asString.toLower.beginsWith("c")) {
                    ind = unit[\params][name].asString.replace("c", "").asInteger;
                    if (unit.keys.asArray.includes(\connCoords).not) {
                        unit[\connCoords] = ( );
                    };
                    unit[\connCoords][name] = drawConnection.(
                        unit, synthsKr[ind], name, wdtAr, num
                    );
                }
            };
        };
    };
};
viewConn.mouseDownAction = { |view, x, y, modifiers, buttonNumber, clickCount|
    var sX, sY, sW, sH;
    particles.keysValuesDo { |part, synth|
        if (synth.keys.includes(\coords)) {
            #sX, sY, sW, sH = synth.coords;
            // main synth area
            if ((x > sX) && (x < (sX+sW-15)) && (y > sY) && (y < (sY+sH))) {
                particles[part].put(\current, true);
                labelAr.string = format("% [%]", synth[\synth], synth[\node]);
                ~synths[synth[\synth].asSymbol][\params].do { |parm, i|
                    guiAr[i].labelView.string = parm;
                    guiAr[i].controlSpec = ~specs[parm];
                    try {
                        guiAr[i].value = synth[\params][parm]
                    } {
                        guiAr[i].value = ~defaultParams.ar[i]
                    };
                };
            } {
                particles[part].put(\current, false)
            };
            // close [x] button
            if ((x > (sX+sW-15)) && (x < (sX+sW)) && (y > sY) && (y < (sY+15))) {
                unregisterParticle.(synth[\node]);
                removeParticle.(part);
            };
            // mute [M] button
            if ((x > (sX+sW-15)) && (x < (sX+sW)) && (y > (sY+15)) && (y < (sY+sH-15))) {
                mute.(synth);
            };
            // solo [S] button
            if ((x > (sX+sW-15)) && (x < (sX+sW)) && (y > (sY+sH-15)) && (y < (sY+sH))) {
                particles.keysValuesDo { |pt, sy|
                    if (pt != part) { mute.(sy) }
                };
            };
        }
    }
};
mute = { |synth|
    if (synth.keys.includes(\params).not) {
        synth[\params] = ( );
    };
    if (synth[\params].keys.includes(\amp).not) {
        synth[\params][\amp] = 1
    };
    synth.params[\amp] = synth.params[\amp].neg;
    ~scsynth.sendMsg("/n_set", synth.node, \amp, max(0, synth.params[\amp]));
};


// GUI: .ar synths selection
tmp = 1-(viewConn.bounds.height/viewRight.bounds.height).round(0.01);
panel = compViewFlow.(viewRight, scaleW: 0.2, scaleH: tmp);
listView.(panel, items: ~synths.keys.asArray.sort)
.enterKeyAction_({ |lv|
    ~sendParticle.(
        particle: (spring:1, mass:1),
        synth: (name: lv.items.at(lv.value).asSymbol)
    );
});

// synth params
ccCurrSynthParam = { |sType, ctlInd, val|
    var curr, parmName;
    if (sType == \ar) {
        particles.values.do { |sy| if (sy[\current]) { curr = sy }};
    } {
        synthsLFO.values.do { |sy| if (sy[\current]) { curr = sy }};
    };
    parmName = ~synths[curr[\synth].asSymbol][\params][ctlInd];
    if (curr.keys.includes(\params).not) {
        curr[\params] = ( );
    };
    curr[\params][parmName] = val; // update param value
    if (curr.isNil.not) {
        ~scsynth.sendMsg("/n_set", curr[\node], parmName.asString, val);
    };
};

guiSynthCtrls = { |panel, synthType|
    var stripeWidth = (panel.bounds.width/2).round;
    var pan = compViewFlow.(panel, scaleW: 0.5);
    // label
    var stSynth = sText.(pan,
        "<synthname>",
        stringFont:fontMedium, scaleW:1, scaleH: 0.1
    );
    // controls
    var ctrls = Array.fill(8, {nil});
    // knobs
    6.do({ |j|
        ctrls[j] = EZKnob(pan,
            Rect(
                (j/3).trunc*30+10,
                stSynth.bounds.height+(j%3*90)+30,
                stripeWidth*0.45,
                stripeWidth*0.6
            ),
            ~defaultParams[synthType][j],
            ~specs.at(~defaultParams[synthType][j]),
            { |ez| ccCurrSynthParam.(synthType, j, ez.value)},
            layout: \vert2
        )
        .enabled_(~defaultParams[synthType][j] != \dummy)
        .font_(fontSmall)
        .setColors(
            stringBackground:transparent,
            stringColor:fontColor,
            numBackground:Color.grey(alpha:0.5),
            numNormalColor:fontColor,
            background:transparent,
        );
        ctrls[j].knobView.canFocus = false;
        ctrls[j].numberView.canFocus = false;

    });
    // sliders
    2.do { |j|
        sText.(pan, "", scaleW:0.15, scaleH: 0.35);
        ctrls[j+6] = EZSlider(pan,
            Rect(
                j%2*60+10,
                (pan.bounds.height*0.55).trunc,
                stripeWidth*0.3,
                pan.bounds.height*0.4
            ),
            ~defaultParams[synthType][j+6],
            ~specs.at(~defaultParams[synthType][j+6]),
            { |ez| ccCurrSynthParam.(synthType, j+6, ez.value)},
            unitWidth:30, numberWidth:60, layout:\vert
        )
        .enabled_(~defaultParams[synthType][j+6] != \dummy)
        .font_(fontSmall)
        .setColors(
            stringColor:fontColor,
            sliderBackground:Color.black,
            numBackground:Color.grey(alpha:0.5),
            numNormalColor:fontColor,
            background:transparent
        );
        ctrls[j+6].sliderView.canFocus = false;
        ctrls[j+6].numberView.canFocus = false;
    };
    // return gui elements themselves
    [stSynth, ctrls]
};
panel = compViewFlow.(viewRight, scaleW: 0.635, scaleH: tmp);
#labelAr, guiAr = guiSynthCtrls.(panel, \ar);
#labelKr, guiKr = guiSynthCtrls.(panel, \kr);

// .kr synths selection
panel = compViewFlow.(viewRight, scaleW: 0.2, scaleH: tmp);
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


// Animation func for the basic calibration layout (top view).
drawCalibration = { |view, kwargs|
    view.background = transparent;
    Pen.font_(Font("Andale Mono")).smoothing_(true);
    Pen.scale(1, 1);
    Pen.translate(0, 0);
    center = [world.width/2, world.height/2].asPoint;
    scale = star.position.z.linlin(0, world.depth, 0.2, 1);
    translate = scale.linlin(0.2, 1, world.height/2, 0);
    focal = star.position.x.linlin(0, world.width, 0, 100);

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
    Pen.color = techColor;
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
    };
    // WARNING - end

    // Visualize particles.
    physics.particles.do { |particle|
        if (kwargs[\partHidden].includes(particle).not) {
            case
            {particle == star} {
                partColor = colorStar;
                partColor.alpha = star.position.z.linlin(0, world.depth, 0.7, 0.3);
                partSize = 40
            }
            { kwargs[\partSkel].includes(particle) } {
                partColor = colorJoint;
                partColor.alpha = particle.position.z.linlin(0, world.depth, 0.7, 0.3);
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

            // radiation effect
            if (
                kwargs[\partSkel].includes(particle).not &&
                kwargs[\partHidden].includes(particle).not
            ) {
                10.do {
                    Pen.color = Color.red(rrand(0.0, 1), rrand(0.0, 0.5));
                    Pen.addArc(
                        particle.position.x@particle.position.y,
                        rrand(z*1.1, z*1.8),
                        2pi.rand,
                        pi
                    );
                    Pen.perform([\stroke, \fill].choose);
                }
            }
        };
    };

    // draw stat (on top of everything else, all values updated in a current cycle)
    Pen.color = techColor;
    Pen.stringAtPoint("particles", [world.width*0.5-260, world.height-20].asPoint);
    Pen.color = Color.green;
    Pen.stringAtPoint(physics.particles.size.asString, [world.width*0.5-185, world.height-20].asPoint);

    Pen.color = techColor;
    Pen.stringAtPoint("skeletons", [world.width*0.5-155, world.height-20].asPoint);
    Pen.color = Color.green;
    Pen.stringAtPoint(format("% %", skeleton.size, skeleton.keys.asArray), [world.width*0.5-75, world.height-20].asPoint);

    Pen.color = techColor;
    Pen.stringAtPoint("springs", [world.width*0.5+30, world.height-20].asPoint);
    Pen.color = Color.green;
    Pen.stringAtPoint(physics.springs.size.asString, [world.width*0.5+90, world.height-20].asPoint);

    Pen.color = techColor;
    Pen.stringAtPoint("attractions", [world.width*0.5+120, world.height-20].asPoint);
    Pen.color = Color.green;
    Pen.stringAtPoint(physics.attractions.size.asString, [world.width*0.5+210, world.height-20].asPoint);
};


drawGraph = { |view, kwargs|
    var drawParticle = { |particle, box, label, color, origin, wedgeNum=10|
        var radius;
        Pen.font_(Font("Andale Mono")).smoothing_(true);
        radius = particle.position.z.linlin(
            0, view.bounds.width,
            20.rand, box*rrand(0.45, 0.5)
        );
        #azimuth, distance, elevation = xyz2ade.(particle.position);
        wedgeNum.do {
            color.alpha = particle.position.z.linlin(0, world.depth, 0.7, 0.3);
            Pen.color = color;
            Pen.addAnnularWedge(
                (origin[0]+(box*rrand(0.4, 0.6)))@(origin[1]+(box*rrand(0.4, 0.6))), // fuzzy center
                radius.rand,
                rrand(radius, radius*1.5),
                azimuth+pi + 0.1.rand2,
                mag3D.(particle.velocity).linlin(0, 1, pi, rrand(1.8pi, 2pi));
            );
            Pen.perform([\stroke, \fill].wchoose([0.8, 0.2]));
        };
        // draw stat (on top of everything else, all values updated in a current cycle)
        tmp = origin[1] + box - 20;
        Pen.color = techColor;
        Pen.stringAtPoint(label, [origin[0], origin[1]].asPoint);
        Pen.color = techColor;
        Pen.stringAtPoint("#a", [origin[0], tmp].asPoint);
        Pen.color = Color.green;
        Pen.stringAtPoint((azimuth/pi).round(0.001).asString ++ "pi", [origin[0]+20, tmp].asPoint);
        if (box > (origin[0]+80)) {
            Pen.color = techColor;
            Pen.stringAtPoint("#d", [origin[0]+80, tmp].asPoint);
            Pen.color = Color.green;
            Pen.stringAtPoint(distance.round(0.001).asString, [origin[0]+100, tmp].asPoint);
            Pen.color = techColor;
            Pen.stringAtPoint("#^", [origin[0]+150, tmp].asPoint);
            Pen.color = Color.green;
            Pen.stringAtPoint((elevation/pi).round(0.001).asString ++ "pi", [origin[0]+170, tmp].asPoint);
        }
    };
    view.background = transparent;

    // star
    drawParticle.(star,
        box: view.bounds.width*0.5,
        label: format("% (star)", star.hash),
        color: colorStar,
        origin: [0, 0],
        wedgeNum: 30
    );
    // joints
    skeleton.values.do { |sk|
        jointVisible.do { |j, i|
            drawParticle.(sk[j],
                box: view.bounds.width*0.163, //*0.5*0.33,
                label: j,
                color: colorJoint,
                origin: [
                    (i % 3 * view.bounds.width * 0.163),
                    view.bounds.height * ((i/3).trunc * 0.163 + 0.5)
                ]
            );
        };
    };
    // // hidden particles
    // kwargs[\partHidden].do { |particle, i|
    //     partColor = Color.grey;
    //     drawParticle.(particle,
    //         box: view.bounds.height/kwargs[\partHidden].size,
    //         label: particle.hash.asString,
    //         color: partColor,
    //         origin: [
    //             view.bounds.width*0.5,
    //             (view.bounds.height/kwargs[\partHidden].size) * i
    //         ]
    //     );
    // };
    // ordinary particles
    tmp = all {: p, p <- physics.particles,
        kwargs[\partSkel].includes(p).not,
        kwargs[\partHidden].includes(p).not,
        p != star
    };
    tmp.do { |particle, i|
        partColor = Color(
            particle.mass.linlin(0, 1, 0.2, 1), // the heavier the object, the redder it appears
            particle.mass.linlin(0, 1, 0.7, 1),
            particle.mass.linlin(0, 1, 1, 0.1)
        );
        drawParticle.(particle,
            box: view.bounds.width*0.3,
            label: particle.hash.asString,
            color: partColor,
            origin: [
                view.bounds.width*0.65,
                (view.bounds.height*0.3) * i
            ]
        );
    };
};


// Simple stroboscope.
drawStrob = { |view|
    view.background = transparent;
    tmp = patt.next;
    Pen.translate(world.width*0.5, world.height*0.5); //offset drawing to the centre
    Pen.fillColor = Color.white; //always fill with white color
    tmp = 1 - tmp; // invert the mapping
    Pen.fillRect(
        Rect.aboutPoint(
            Point(0, 0),
            tmp*world.width.rand,
            tmp*(world.height*0.5).rand
        )
    );
};


// Animation for the skeleton based calibration layout (front view).
drawSkel = { |view|
    // variable space depth for "jumping picture" effect
    visCount = visCount + 1;
    if (visCount % 100.rand == 0) {
        focalPoint = focalStream.next;
        scaleDepth = scaleStream.next;
        gridUnit = focalPoint.linlin(0, 3, 10, 2);
    };
    // variable background
    if (visCount % renew == 0) {
        view.background = [
            Color.black,
            Color.grey(1.0.rand),
            Color.red(1.0.rand),
            Color.white,
        ].choose;
        isGrid = 0.5.coin;
        renew = rrand(10, 100);

        currPath = paths.choose;
        hold = [0, 18.rand].choose;

        if (visCount >= 1e+3) {visCount = 0};
    };

    if (hold > 0) {
        hold = hold - 1;
        Pen.translate(
            scaleDepth*(hold.linlin(0, 9, 500, 50)),
            focalPoint*(hold.linlin(0, 9, 200, 10))
        );
        Pen.scale(scaleDepth, scaleDepth);
        Pen.skew(scaleDepth.rand2, scaleDepth.rand2);
    };

    // draw skeletons
    skeleton.values.do { |skel|
        // WARNING! Technically this is a wrong approach,
        // since it will draw particles two times.
        // but it doesn't matter, because only one skel is used.
        if (skel[\head].position.y > star.position.y) {
            drawSkelParticle.();
            drawSkelJoints.(skel, currPath);
        } {
            drawSkelJoints.(skel, currPath);
            drawSkelParticle.();
        };
    };
    // draw grid
    Pen.strokeColor = Color.grey(0.3);
    Pen.width = 0.5;
    Pen.use {
        if (isGrid) {
            deviation = [world.width, world.height] / 9;
            rrand(600, 1000).do {
                Pen.beginPath;
                Pen.moveTo(Point(10.rand * deviation[0], 10.rand * deviation[1]));
                Pen.lineTo(Point(10.rand * deviation[0], 10.rand * deviation[1]));
                Pen.stroke;
            };
        } {
            numUnitsX = (world.width / gridUnit).ceil;
            numUnitsY = (world.height / gridUnit).ceil;
            rrand(600, 1000).do {
                Pen.beginPath;
                pointFrom = Point(numUnitsX.rand*gridUnit, numUnitsY.rand*gridUnit);
                pointTo = Point(numUnitsX.rand*gridUnit, numUnitsY.rand*gridUnit);
                Pen.moveTo(pointFrom);
                Pen.lineTo(pointTo);
                Pen.stroke;
            };
        }
    };
};


// A frame of movement of a skeleton in the drawSkel mode.
drawSkelJoints = { |skel, currPath|
    currPath.do { |path|
        path.do { |jo, j|
            if (j < (path.size-1)) {
                lineColor = Color.grey(
                    skel[jo].position.y.linlin(0, world.depth, 1, 0)
                );
                deviation = skel[jo].position.y.lincurve(0, world.depth, 1, 20, -4);
                xyA = getPointPlane.(skel[jo]);
                xyB = getPointPlane.(skel[path[j+1]]);
                drawLine.(
                    pointA:(x:xyA[0], y:xyA[1]),
                    pointB:(x:xyB[0], y:xyB[1]),
                    lineColor:lineColor
                );
                // intenionally messy lines around each "bone"
                10.do {
                    xyDevA = (
                        x: randomize.(xyA[0], deviation),
                        y: randomize.(xyA[1], deviation)
                    );
                    xyDevB = (
                        x: randomize.(xyB[0], deviation),
                        y: randomize.(xyB[1], deviation),
                    );
                    drawLine.(xyDevA, xyDevB, lineColor);
                    // additional lines for the head
                    if (jo == \head) {
                        xyDevA = (
                            x: randomize.(xyA[0]-gridUnit, deviation),
                            y: randomize.(xyA[1]+gridUnit, deviation)
                        );
                        xyDevB = (
                            x: randomize.(xyA[0]+gridUnit, deviation),
                            y: randomize.(xyA[1]+gridUnit, deviation),
                        );
                        drawLine.(xyDevA, xyDevB, lineColor);
                    };
                };
            };
        };
    };
};


// A frame of movement of particles (excluding skeletal joints)
// in the drawSkel mode.
drawSkelParticle = {
    physics.particles.do { |particle|
        if (particle.isFree) {
            xyA = getPointPlane.(particle);
            lineColor = Color.grey(
                particle.position.y.linlin(0, world.depth, 1, 0.3)
            );
            deviation = particle.position.y.lincurve(
                0, world.depth,
                1, if (particle == star) {15} {10},
                -4
            );
            if (particle == star, {80}, {20}).do {
                xyDevA = (
                    x: randomize.(xyA[0]-gridUnit, deviation),
                    y: randomize.(xyA[1]+gridUnit, deviation)
                );
                xyDevB = (
                    x: randomize.(xyA[0]+gridUnit, deviation),
                    y: randomize.(xyA[1]+gridUnit, deviation),
                );
                drawLine.(xyDevA, xyDevB, lineColor);
            }
        }
    }
};


// Animation func for the basic calibration layout (top view).
drawCube = { |view|

};

// Physics ticks here!
viewWorld.drawFunc = { |view|
    // Process an event from eventPool before going on with the rest.
    paramsChanged = false;
    if (eventPool.items.size > 0) {
        // any change (even a new particle) is a World change
        paramsChanged = true;
        // process only one event in the current cycle
        event = eventPool.popItem;
        event[\message].switch(
            \physics, {
                // some should be updated directly
                event[\params][0].switch(
                    \starMass,  {star.mass = world.starMass.asFloat},
                    \drag, {physics.setDrag(world.drag)},
                    { if (#[\gravX, \gravY, \gravZ].includes(event[\params][0])) {
                        physics.setGravity(
                            world.gravX, world.gravY, world.gravZ
                        )
                    }}
                );
            },
            \particle, {
                particle = initParticle.(event[\particle]);
                event[\synth][\node] = ~initSynth.(
                    event[\synth][\name],
                    node: event[\synth].atFail(\node, {nil}),
                    params: event[\synth][\params]
                );
                registerParticle.(particle, event[\synth]);
                if (event[\particle][\spring].booleanValue) {
                    // If "spring" specified but failed, attractions will be applied.
                    registerSpring.(
                        applySpring.(particle, event[\particle][\source])
                    );
                };
            };
        );
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
    if (world[\particleSystem].booleanValue) {
        if (view.frame % (view.frameRate * world.partFreq).round == 0) {
            guide = defineGuide.();
            particleSystem.(guide);
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

    // Manage particles.
    particlesSkelVis = getParticlesSkelVis.();
    particlesHidden = getParticlesHidden.();
    particlesOnSprings = getParticlesOnSprings.();
    physics.particles.do { |particle|
        // Re-apply world forces, if there was any change in its parameters
        if (paramsChanged) {
            if (particlesOnSprings.includes(particle)) {
                // if particle is on spring, change spring's properties
                setSpringProp.(particle: particle);
            } {
                // if particle isn't on spring, re-apply attractions
                if (particlesHidden.includes(particle).not) { // exclude hidden particles
                    applyAttractions.(particle, world.mutualAttraction);
                }
            };
        };
        handleBoundaryCollisions.value(particle);
        // Age control: particles age "backwards",
        // i.e. age = 0 is a death and positive age is afterlife.
        if (particle.age >= 0) { particle.dead = true };
        if (particle.dead) {
            try {
                unregisterParticle.(particles[particle][\node]);
            };
            removeParticle.(particle);
        };
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
    };

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

    // XXX - apply Canvas3D hto all drawings!
    //
    // select drawing mode
    kwargs = (partSkel: particlesSkelVis, partHidden: particlesHidden);
    world[\draw].switch(
        \calibration, { drawCalibration.(view, kwargs: kwargs)},
        \skel, { drawSkel.(view) },
        \skelfull, { drawStrob.(view) },
        \graph, { drawGraph.(view, kwargs: kwargs) },
        \cube, { drawCube.(view) }, // TODO
        { drawCalibration.(view, kwargs: kwargs) }
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


// Defines guide (where obj appears) depending on objects velocity.
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


// Returns particle's guide, if any, otherwise nil.
getGuide = { |particle|
    var spring, guide;
    spring = getSpringForParticle.(particle);
    if (spring.isNil.not) {
        guide = spring.a
    };
    guide
};


// Init new particle.
// `params` is an Event with mass, x, y, z, age, and vel.
initParticle = { |params|
    var particle, guide, x, y, z;
    #x, y, z = [
        params[\x] ? world.width.rand,
        params[\y] ? world.height.rand,
        params[\z] ? world.depth.rand
    ];
    // Negative coordinates ask for guide.
    if ([x, y, z].any({ |i| i < 0 })) {
        guide = defineGuide.();
        #x, y, z = [guide.position.x, guide.position.y, guide.position.z]
    };
    particle = physics.makeParticle(
        params[\mass] ? world.partDefaultMass,
        x, y, z
    );
    // Velocity is TraerVector3D.
    if (params.keys.includes(\vel)) {
        particle.velocity.set(params[\vel].x, params[\vel].y, params[\vel].z)
    };
    // Particles age "backwards": age == 0 is death, age >= 0 is afterlife.
    try {
        particle.age = (params[\age] * 60).abs.neg;
    } {
        particle.age = inf.neg;
    };
    particle
};


// Particle system.
particleSystem = { |guide|
    // probability of the birth of particle depends on the guide's velocity
    var vel = if (guide.velocity != 0) {
        guide.velocity
    } {
        TraerVector3D(
            x: world[\maxVel].rand,
            y: world[\maxVel].rand,
            z: world[\maxVel].rand
        )
    };
    var prob = sigmoid.(
        ratio: world.partSigmoidRatio,
        value: mag3D.(vel).linlin(
            0, world[\maxVel],
            world[\maxVel].neg, world[\maxVel])
    );
    if (prob.coin) {
        vel = ([vel.x, vel.y, vel.z].neg * world[\partInitAccel]).max(0.1);
        eventPool.append((
            message: \particle,
            particle: (
                mass: 0.2,
                age: world[\partAgeThresh].logistic,
                vel: TraerVector3D(x: vel[0], y: vel[1], z: vel[2]),
                x: guide.position.x,
                y: guide.position.y,
                z: guide.position.z
            ),
            synth: (
                name: world[\partSynth],
                params: [\attack, 0.5.rand]
            )
        ));
    };
};

removeSpring = { |spring|
    springs.removeAt(spring.identityHash);
    physics.removeSpring(spring);
};

removeAttraction = { |attraction|
    physics.removeAttraction(attraction);
};

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

removeAll = {
    // Remove all particles from the world and stop all synths.
    particles.keys.do { |p, i|
        unregisterParticle.(particles[p][\node]);
        removeParticle.(p);
    }
};


// Register particle in the dictionary along with Server nodeId.
// Fill params fpr synth attached to the particle.
//
// Register and unregister particle are separate functions
// from init and remove to support the case when an existing
// particle is being re-attached to a different node on the server.
registerParticle = { |particle, synth|
    particles.put(particle, (
        node: synth[\node],
        synth: synth[\name],
        params: ~fillSynthParams.(synth, ~synths)
    ));

    // // XXX 3d
    // registerCube.(particle)
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
                part = initParticle.((mass: world.starMass, x: x, y: y, z: z));
                part.makeFixed;
                skeleton[id][joint] = part;

                // // XXX 3d
                // registerCube.(part)
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

sigmoid = { |ratio, value|
    //
    1 / (1 + exp((ratio * value).neg))
};


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


// Standard plane poiint in the ~world.
getPointPlane = { |obj|
    xyz2plane.(
        (
            x: obj.position.x.round(gridUnit),
            y: obj.position.z.round(gridUnit),
            z: obj.position.y
        ),
        world,
        scale:scaleDepth,
        focal:focalPoint
    )
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


// Updates post colors when postView size shrinks.
updatePostColors = { |colors, start|
    colors.size.do { |i|
        colors[i][\start] = colors[i][\start] - start
    };
    all {: k, k <-colors, k[\start] > 0 };
};


//
getMsgColor = { |msg|
    case
    { msg.beginsWith("INFO") || msg.beginsWith("->") } { Color.new255(11, 96, 224) }
    { msg.beginsWith("DEBUG") || msg.beginsWith("$>") } { Color.new255(55, 157, 0) }
    { msg.beginsWith("WARNING") } { Color.white }
    { msg.beginsWith("ERROR") } { Color.new255(158, 33, 33) }
    { fontColor };
};


// Posts message to local listener.
postMsg = { |msg|
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


//
reportOSC = { |msg, time, addr, recvPort|
    postMsg.(format(
        "-> OSC msg \"%\" at % from %:%\n",
        msg[0], Date.getDate.format("%d/%m/%Y %T"),
        addr.ip, addr.port
    ));
};


//
reportEvent = { |num, msg, j|
    postMsg.(format("-> event %, message % (%)\n", num, msg, j))
};


// OSC
//
// Catches messages related to particles,
// converts a message to format suitable for an event,
// and saves in the eventPool.
oscParticle = OSCFunc({ |msg, time, addr, recvPort|
    var data;
    data = (
        message: \particle,
        particle: (
            mass: msg[1],
            x: msg[2],
            y: msg[3],
            z: msg[4],
            age: msg[5],
            spring: msg[6],
            source: msg[7]
        ),
        synth: (
            node: msg[8],
            name: msg[9],
            params: Dictionary.newFrom(msg[10..])
        )
    );
    if (data[\synth][\node] == -1) {
        data[\synth].removeAt(\node)
    };
    if (data[\particle][\source] == 0) {
        data[\particle].removeAt(\source)
    };

    // report
    reportOSC.(msg, time, addr, recvPort);
    eventPool.append(data);
}, '/particle');


// Catch messages related to physics.
oscPhysics = OSCFunc({ |msg, time, addr, recvPort|
    reportOSC.(msg, time, addr, recvPort);
    msg[1..].pairsDo { |key, val|
        eventPool.append((
            message: \physics,
            params: [key, updateWorldParm.(key, val)]
        ))
    };
}, '/physics');


// Catch action messages.
oscAction = OSCFunc({ |msg, time, addr, recvPort|
    var data, synthId;
    postMsg.(reportOSC.(msg, time, addr, recvPort));
    postMsg.(format("\t%: %\n", msg[1], msg[2..]));
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
        \draw, {
            world[\draw] = msg[2].asSymbol;
            // canvas.visible = (msg[2].asSymbol == \cube) // XXX 3d
        },
        \fullscreen, {
            // bookmark
            if (msg[2].booleanValue) {
                {
                    viewLeft.bounds = win.bounds;
                    viewWorld.bounds = viewLeft.bounds;
                    // viewBottom.bounds = Rect(0, win.bounds.height, win.bounds.width, 0);
                    // viewRight.bounds = Rect(win.bounds.width, 0, 0, win.bounds.height);
                    win.fullScreen
                }.defer
            } {
                {
                    win.endFullScreen;
                }.defer
                // viewLeft = compViewFlow.(win, scaleW: (world.width+8)/win.bounds.width);
                // viewLeft.bounds = Rect(0, 0, win.bounds.width, 0); (win, scaleW: (world.width+8)/win.bounds.width);
                // viewTop = compViewFlow.(viewLeft, scaleH:0.001); // placeholder
                // viewWorld = UserView(viewLeft, world.width@world.height);
                // viewBottom = compViewFlow.(viewLeft,
                //     scaleH:(win.bounds.height-(viewWorld.bounds.height+viewTop.bounds.height))/win.bounds.height
                // );
                // viewRight = compViewFlow.(win,
                //     scaleW:(win.bounds.width-viewLeft.bounds.width)/win.bounds.width,
                // );
            }
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

    // // XXX front view
    // #x, y, z = [
    //     msg[3].linlin(0.0, 1.0, 0, world.width),
    //     msg[4].linlin(0.0, 1.0, 0, world.height),
    //     msg[5].linlin(0.65, 2.8, 0, world.depth)
    // ];

    // XXX top view
    #x, y, z = [
        msg[3].linlin(0.0, 1.0, 0, world.width),
        msg[5].linlin(0.65, 2.8, 0, world.height),
        msg[4].linlin(0.0, 1.0, 0, world.depth)
    ];
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
        postf(
            "-> /g_queryTree.reply (%:%)\n%\n",
            addr.ip, addr.port, ~formatSrvTree.(msg)
        );
    };
}, '/g_queryTree.reply');


// PHYSICS
//
physics = TraerParticleSystem.new;
particles = IdentityDictionary.new;
springs = IdentityDictionary.new;

// Star is in the center.
star = initParticle.((
    mass: world.starMass, x: world.width/2, y: world.height/2, z: world.depth/2
));
applyAttractions.(star, world.mutualAttraction);
// // XXX 3d
// registerCube.(star);

// XXX 3d
// // 3-D CANVAS
// //
// canvas = Canvas3D(viewWorld, Rect(0, 0, world[\width], world[\height]))
// .background_(Color.black)
// .scale_(200)
// .perspective_(0.2)
// .distance_(1);
// canvas.add(frame = Canvas3DItem.cube
//     .color_(Color.white)
//     .width_(0.5)
// );

// Animate!
viewWorld.animate = true;

// // XXX 3d
// if (world[\draw] == \cube) {
//     canvas.animate = true;
//     canvas.animate(40) { |t|
//         canvas.transforms = [ // spin the canvas
//             Canvas3D.mRotateY(t*transRate*1.0 % 2pi),
//             Canvas3D.mRotateX(t*transRate*1.5 % 2pi)
//         ];
//         frame.transforms = canvas.transforms;
//         cubes.keysValuesDo { |particle, item|
//             transX = particle.position.x.linlin(0, world[\width], -1, 1);
//             transY = particle.position.y.linlin(0, world[\height], -1, 1);
//             transZ = particle.position.z.linlin(0, world[\depth], -1, 1);
//             if (particle == b) {transZ.postln};
//             item.transforms = frame.transforms ++ [
//                 Canvas3D.mRotateZ(t*transRate*5 % 2pi),
//                 Canvas3D.mRotateX(t*transRate*2 % 2pi),
//                 Canvas3D.mTranslate(transX, transY, transZ),
//                 Canvas3D.mScale(transZ)
//             ];
//         }
//     }
// } {
//     canvas.animate = true
// };


{ // GLOBAL APP CLOCK. Resolution: 100 milliseconds (0.1 of a second)
    while {win.isClosed.not} {
        // report nodes every now and then
        tick = tick + 1;
        if (tick >= 500) {
            ~scsynth.sendMsg("/g_queryTree", 0);
            tick = 0;
        };

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
    oscPhysics.free;
    oscAction.free;
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