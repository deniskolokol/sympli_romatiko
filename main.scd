(
// CONSTANTS
// f_ile management, p_arameters, a_udio, o_SC, c_ontrol, w_orld.
//
var f_SETTINGS_FILENAME = "settings.conf";
var p_FACTORY_SETTINGS = (
    // Audio parameters.
    audioIn:           false,
    inbus:             20, // bus for external input
    outbus:            0, // main output starts from
    confSurround:      "Ambisonic4",
    fieldDepth:        5, // how "far" sound travels beyond the circle of speakers
    master:            1, // master volume
    // Physics parameters.
    worldGrav:         0.98,
    worldMaxVel:       30,
    worldDamp:         0.8,
    worldDim:          800, // World dimensions in pixels
    starMass:          120, // the heaviest object's mass
    starSize:          10,
    heavy:             5, // heavy objects hang on springs, no gravity
    initMass:          5, // initial mass with which object is created
    objAttract:        true, // do objects attract each other
    repulsiveForce:    1, // behavior on collision (no repulsion if 1),
    springStiff:       0.1, // springs stiffness
    springDamp:        0.9, // springs damping
    springLen:         1, // springs length
    // Particles.
    particles:         0, // run particles
    partSigmoidRatio:  0.7, // steepness of sigmoid function determiming probability of particle appearing
    partFreq:          0.5, // generate a new particle \partFreq times per second
    partAgeThresh:     50, // maximum particle age in cycles (fps)
    partInitAccel:     5, // particle initial acceleration
    partGuide:         "object", // which object guides Particle System
    partSynth:         \sr__e__analog,
    // Visualisation.
    fps:               60, // frames per second
    visualize:         true,
    showCoords:        false,
    // System
    synthdefFile:      "/Users/deniskolokol/Documents/dev_music/sympli_romatiko/repo/sympli_romatiko/synthdef.scd",
    tempDir:           "~/tmp/SuperCollider/sounds/",
    // Aux
    synthForm:         1,
    synthSaw:          1);
// List of svailable synths.
var a_SYNTHS = #[\sr__g__reg, \sr__g__drone, \sr__g__gust, \sr__g__slic, \sr__g__loop, \sr__g__chunk,
    \sr__e__lowe, \sr__e__probe, \sr__e__cmb, \sr__e__melo, \sr__e__ringz, \sr__e__pulse, \sr__e__analog,
    \sr__e__entro, \sr__e__noisy, \sr__e__humm, \sr__e__radio, \sr__p__kick, \sr__p__hat, \sr__p__snare];
var a_SURROUND_CONFIG = #[\VBAP4, \Ambisonic2, \Ambisonic4, \Ambisonic8];
// Spec for mass control.
var p_MASSSPEC = ControlSpec(1, 11, \lin, 1);
// Interface descriptor.
// Based on panels, each of which consist of a collection of elements.
// Each element either sets a param or triggers something special,
// in which case a function should be defined.
var p_INTRFACE = [
    (
        title: "World parameters",
        visible: true,
        params: [
            (param: \objAttract, title: "Mutual attraction", element: \boolean),
            (param: \worldGrav, title: "World gravity", spec: ControlSpec(0, 2)),
            (param: \worldDamp, title: "World damping", spec: ControlSpec(0.01, 2.00)),
            (param: \worldMaxVel, title: "Max objects velocity", spec: ControlSpec(1, 100)),
            (param: \repulsiveForce, title: "Repulsive force", spec: ControlSpec(1, 1000)),
            (param: \starMass, title: "Star mass", spec: ControlSpec(5, 2147483647)),
            (param: \starSize, title: "Star size", spec: ControlSpec(10, 500, step:10)),
            (param: \heavy, title: "Heavy objects", spec: p_MASSSPEC),
            (param: \worldDim, title: "World dimensions", spec: ControlSpec(1, 2000)),
            (param: \springStiff, title: "Spring stiffness", spec: ControlSpec(0.1, 2)),
            (param: \springDamp, title: "Spring damping", spec: ControlSpec(0.1, 2)),
            (param: \springLen, title: "Spring length", spec: ControlSpec(0.1, 10.0)),
        ]
    ),
    (
        title: "Particle system",
        visible: true,
        params: [
            (param: \particles, title: "Run particles", element: \boolean),
            (param: \partFreq, title: "Particles per sec", spec: ControlSpec(0.01, 5.00, \lin, 0.01)),
            (param: \partAgeThresh, title: "Age top threshold", spec: ControlSpec(10, 200, \lin, 5)),
            (param: \partInitAccel, title: "Initial acceleration", spec: ControlSpec(0, 50, \lin, 0.1)),
            (param: \partSigmoidRatio, title: "Steep sigmoid func", spec: ControlSpec(0.1, 1, \lin, 0.01)),
            (param: \partGuide, title: "Guide", element: \dropdown,
                items: #[\wind, \feet, \object]),
            (param: \partSynth, title: "Synth", element: \dropdown, items: a_SYNTHS),
        ]
    ),
    (
        title: "Audio settings",
        visible: true,
        params: [
            (param: \audioIn, title: "Audio through", element: \boolean),
            (param: \inbus, title: "Input bus", element: \dropdown, items: (0..29)),
            (param: \outbus, title: "Main out", element: \dropdown, items: (0..29)),
            (param: \confSurround, title: "Surround sound", element: \dropdown, items: a_SURROUND_CONFIG),
            (param: \fieldDepth, title: "Aural field depth", spec: ControlSpec(0.5, 10, \lin, 0.5, 4)),
            (param: \master, title: "Master volume", spec: \amp.asSpec, element: \slider),
        ]
    ),
    (
        title: "Visualization",
        visible: true,
        params: [
            (param: \fps, title: "FPS", spec: ControlSpec(20, 60, \lin, 1)),
            (param: \visualize, title: "Display Visualization", element: \boolean),
            (param: \showCoords, title: "Display coordinates", element: \boolean)
        ]
    )
];
var a_BUS_POOL = [30, 53]; // lowest and highest-1 number of bus used for objects' synths
var c_KEY_OBJ = #[29, 18, 19, 20, 21, 23, 22, 26, 28, 25]; // keycodes for tracing objects 0-9. ORDER MATTERS!!!
var c_KEY_OBJ_SYNTH = ( // keycodes for creating objects and synths of different kinds
    12: ["a RedObject", \sr__g__reg],	// q
    13: ["a RedObject", \sr__g__drone],	// w
    14: ["a RedObject", \sr__g__gust],	// e
    15: ["a RedBoid",   \sr__g__slic],	// r
    17: ["a RedBoid",   \sr__g__loop],	// t
    16: ["a RedObject", \sr__e__noisy],	// y
    32: ["a RedObject", \sr__e__probe],	// u
    34: ["a RedObject", \sr__e__cmb],	// i
    31: ["a RedObject", \sr__e__entro], // o // 31: ["a RedObject", \sr__e__lowe],
    35: ["a RedObject", \sr__e__melo],	// p
    33: ["a RedBoid",   \sr__e__ringz],	// [
    30: ["a RedBoid",   \sr__e__pulse],	// ]
    42: ["a RedObject", \sr__e__analog], // \ (the answer to the ultimate question ))
);
var c_CTRL_SYNTH_ARGS = #[ //[\synthName, kr_bus]
    [\kr_ml0, 0],
    [\kr_mg2, 1],
    [\kr_mg0, 2],
    [\kr_ml1, 3],
    [\kr_mg1, 4],
    [\kr_mh0, 5]];
var o_SCHEDULER_ADDR = NetAddr.new("127.0.0.1", 57120);
var o_SKELETON_ADDR = NetAddr("192.168.1.103", nil); // NetAddr("192.168.0.11", nil);
var w_VEC_2D_0 = #[0, 0], w_VEC_3D_0 = #[0, 0, 0], w_REDVEC_3D_0 = RedVector3D[0, 0, 0];


// VARIABLES
//
var skelLimit=1;
var w, world, width, height, depth;
var worldCapacity=18;
var synths, objects, objectsProp, currObj=0, currSynth=0, objGuide, posGuide, objAudioIn=nil, posAudioIn;
var mass, pos, wind, springs, hand, applyForces=1;

var synForm=nil, synSaw=nil, posFeet=[nil, nil], synthCtrl, currFormCtl=nil, currSawCtl=nil, startFeetSynths;
var fillStream, streamList= [nil], runTask1, runTask2, isActiveTask1= 0, isActiveTask2= 0;
var objColors= Array.fill(worldCapacity, {Color.rand});
var skeletonObjectText;
var rectimeRep;
var keyObjType;

// Global parameters.
var params, paramsFilename, paramsFile;

// OSC communication.
var oscObjScheduler, oscParmScheduler, oscActScheduler;
var oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost;
var oscRemoveFunc;

// Routing Audio.
var currBusRoute, rootNodeID, audioThroughID;

// Groups and synths management.
var startSynth, initGroup, removeGroup, mixerNode;

// Buffers.
var cyclicBuf, cyclicSynthID, loadBufRout, recBufStart, recBufStop, recSynth;
var isRecording, recProgress;
var currFilename, currBufnum;
var scaleBuf;

// Objects management.
var initObject, removeObject;

// Particles.
var sys, guides, newPart, posPart, partSynths, partGuideItems, partProb;

// A center of the World.
var worldStar;

// Skeleton.
var skeletonCoords, skeletonObject;

// Interface elements.
var layoutHColor=Color.new255(100, 100, 100), layoutHFontColor=Color.new255(200, 200, 200), panelColor=Color.grey(0.8);
var labelFont=Font("Helvetica", 9), layoutHFont=Font("Helvetica", 11);
var winWorld, winCtl, drawPanels; // main control interface
var stringBackground = Color.grey(alpha:0.1),
stringColor = layoutHColor,
menuBackground = Color.white,
menuStringColor = Color.black,
listBackground = Color.white,
listStringColor = Color.black,
selectedStringColor = nil,
hiliteColor = nil,
sliderBackground = Color.grey(alpha:0.5),
numBackground = Color.white,
numStringColor = Color.grey(alpha:0.1),
numNormalColor = Color.black,
numTypingColor = Color.black,
knobColor = Color.black,
background = nil;
var cvObjCtrl, cvAux;
var ezkObjCtrl=Array.fill(worldCapacity, {nil});

// System related.
var shutDown;

// Utils and helper functions.
var planeCoords, currentChannels, planeDot, clipInc, sigmoid;


// INITIAL
//
// Useful environment variables.
~currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;

// Global Params.
"\nTrying to open settings file...".postln;
paramsFilename = ~currentDir +/+ f_SETTINGS_FILENAME;
try { // to load from settings file
    params = File(paramsFilename, "r").readAllString.interpret;
    postf("OK\n\n")
} { |err| // unsuccessful
    params = p_FACTORY_SETTINGS; // load factory settings
    format(
        "Failed to open file %!\nUsing factory settings, will be written to the file on exit.\n",
        paramsFilename
    ).warn
};
// complete params: if key not present, fill from factory settings
params = merge(params, p_FACTORY_SETTINGS, { |a, b| a });

// Load synthDefs.
"Loading synth definitions...".postln;
if (PathName(params[\synthdefFile]).pathOnly == "") {
    params[\synthdefFile] = ~currentDir +/+ params[\synthdefFile];
};
if (this.executeFile((params[\synthdefFile])).isNil.not) {
    postf("OK\n\n")
};

// Find or create tmp dir.
~tempDir = params[\tempDir].asAbsolutePath;
if (File.type(~tempDir) != \directory) {File.mkdir(~tempDir)};
if (File.type(~tempDir) == \not_found) { // error!
    format(
        "Failed to find or create temp directory %!\nBuffer recording will not work!",
        ~tempDir
    ).error;
    ~tempDir = nil;
};

depth = width = height = params[\worldDim];
objects = Array.fill(worldCapacity, {nil}); // container for physical objects
objectsProp = Dictionary.new; // properties of objects
synths = Dictionary.new; // container for synths connected to objects
springs = Dictionary.new; // container for springs
skeletonCoords = Dictionary.new; // container for skeleton coordinates
skeletonObject = Dictionary.new; // container for skeleton objects

rootNodeID = s.nextNodeID; // root group Id for objects' synths
s.sendMsg("/g_new", rootNodeID, 0, 1); // root group at the head of group 1
synthCtrl = Array.fill(c_CTRL_SYNTH_ARGS.size, { nil });
keyObjType = c_KEY_OBJ_SYNTH.keys().asArray; // for easy access to keycodes
cyclicBuf = Buffer.alloc(s, s.sampleRate, 1); // 1s single channel Buffer
isRecording = false;
recProgress = 0;
scaleBuf = Buffer.loadCollection(s, FloatArray[0, 3, 7, 10]); // default Scale buffer

// PARTICLES
//
partSynths = Dictionary.new;
sys = RedParticleSystem.new;
// When particle is dead, release its synth.
sys.removeAction = { |o|
    removeGroup.(partSynths[o.identityHash], 1.0.rand);
    partSynths.removeAt(o.identityHash)
};
partGuideItems = [\wind, \feet, \object];

// CONTINOUS BUFFER RECORDING
//
loadBufRout = Routine({
    inf.do({ |j|
        if(cyclicBuf.numChannels != nil, {
            cyclicSynthID = s.nextNodeID;
            s.sendMsg("/s_new", \sr__r__buffloop, cyclicSynthID, 0, rootNodeID,
                \bufnum, cyclicBuf.bufnum, \busnum, params[\inbus], \volIn, 1, \gate, 1, \dur, 1);
            loadBufRout.stop;
        });
        0.01.wait;
    });
}).play(AppClock);


// OSC COMMUNICATION
//
oscSkeletonLost = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from % received %\n", addr, msg);
    skeletonCoords.removeAt(msg[1].asInteger);
}, '/lost_skel', o_SKELETON_ADDR);

oscSkeletonNew = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from % received %\n", addr, msg);
    if (skeletonCoords.size < skelLimit) {
        skeletonCoords.put(msg[1].asInteger, (
            \update: Date.getDate.secStamp,
            \r_hand: w_VEC_3D_0, \l_hand: w_VEC_3D_0,
            \r_elbow: w_VEC_3D_0, \l_elbow: w_VEC_3D_0,
            \r_foot: w_VEC_3D_0, \l_foot: w_VEC_3D_0,
            \neck: w_VEC_3D_0
            )
        )
    }
}, '/new_skel', o_SKELETON_ADDR);

oscSkeletonJoint = OSCFunc({ arg msg, time, addr, recvPort;
    var skel=nil, joint, x, y, z;
    //postf("from % received %\n", addr, msg);
    joint = msg[1];
    #x, y, z = [
        // WARNING! Ranges shifted!
        msg[3].linlin(-0.1, 1.1, 0, width).round,
        msg[5].linlin(0.3, 3.4, 0, height).round,
        msg[4].linlin(-0.15, 0.99, depth, 0).round
    ];
    skel = skeletonCoords[msg[2].asInteger];
    if (skel.isNil) {
        if (skeletonCoords.size < skelLimit) { // Don't add a skeleton if the limit is reached.
            skel = (\update: Date.getDate.secStamp); // Putting only update timestamp,
            skeletonCoords.put(msg[2].asInteger, skel); // the rest will be filled out on the next iteration.

            // WARNING!
            // Not an elegant solution - to mix world objects with a skeleton.
            // Invent a smart way of checking if the skeleton has changed,
            // and put it into the world "animation".
            springs = Dictionary.new; // Clear all springs, that were potentially connected to a "ghost" skeleton.
        }
    } {
        skel[joint] = [x, y, z];
        skel[\update] = Date.getDate.secStamp;
    }
}, '/joint', o_SKELETON_ADDR);

// OSC function that catches scheduling and sequencing messages.
// Message format:
// [/worldobj, synthType, objectType, lifetime, initPos_X, initPos_Y, initPos_Z]
oscObjScheduler = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from % received %\n", addr, msg);
    initObject.value(
        msg[7] ? params[\initMass],
        objectType: msg[2],
        objectAge: msg[3],
        objectPos: if (msg[4..6] == [0, 0, 0]) {[width, height, depth].rand} {msg[4..6]}
    );
    startSynth.value(synthName:msg[1], parm:msg[8..]); // [8..] are synth parameters
}, '/worldobj', o_SCHEDULER_ADDR);

oscParmScheduler = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from % received %\n", addr, msg);
    try {
        params.put(msg[1], msg[2])
    } { |err|
        postf("Error updating parameter %:\n%\n", msg[1], err)
    }
}, '/worldpar', o_SCHEDULER_ADDR);

oscActScheduler = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from % received %\n", addr, msg);
    msg[1].switch(
        \remove, {
            if (msg[2] == \all) {
                objects.do({|o| removeObject.value(o)})
            }
        },
        \add, {
            // What other acts can be sent to the World?
        }
    );
}, '/worldact', o_SCHEDULER_ADDR);

// Remove all OSC functions.
oscRemoveFunc = {
    oscObjScheduler.free;
    oscParmScheduler.free;
    oscActScheduler.free;
    oscSkeletonNew.free;
    oscSkeletonLost.free;
    oscSkeletonJoint.free;
};

// INTERFACE
//
winCtl = Window.new("controls", Rect(1200, 200, 500, Window.screenBounds.height));
winCtl.view.decorator = FlowLayout(winCtl.view.bounds);
winCtl.layout = GridLayout();

// Draw panels.
drawPanels = { |win, elements|
    var panel, panelHeight, view, element, label, paramVal, j=1;
    elements.do { |val, i|
        if (val[\visible]) {
            panelHeight = 0;
            panel = VLayout();
            view = CompositeView().background_(panelColor);
            view.decorator = FlowLayout(view.bounds);
            StaticText(view, 230@20)
            .string_(format(" % ", val[\title]))
            .background_(layoutHColor).stringColor_(layoutHFontColor).font_(layoutHFont);
            val[\params].do { |pm|
                paramVal = params[pm[\param]];
                label = pm[\title] ? pm[\param];
                element = pm[\element].switch(
                    \dropdown, {
                        EZPopUpMenu(view, 200@20, label, pm[\items]).font_(layoutHFont)
                        .setColors(stringBackground, stringColor, menuBackground, menuStringColor, background)
                    },
                    \list, {
                        EZListView(view, label:label, items:pm[\items], layout: \vert)
                        .font_(layoutHFont)
                        // Warning! Method setColors of EZListView has bugs!
                        // .setColors(stringBackground, stringColor, listBackground, listStringColor,
                        // selectedStringColor, hiliteColor, background)
                    },
                    \slider, {
                        EZSlider(view, 200@20, label:label, controlSpec:pm[\spec],
                            labelWidth:50, unitWidth:0, numberWidth:30).font_(layoutHFont)
                        .setColors(stringBackground, stringColor, sliderBackground, numBackground,
                            numStringColor, numNormalColor, numTypingColor, knobColor, background)
                    },
                    \boolean, {
                        QCheckBox(view, 200@20).font_(layoutHFont).string_(label);
                    },
                    nil, { // default element is EZNumber
                        EZNumber(view, label:label, controlSpec:pm[\spec], labelWidth:100)
                        .font_(layoutHFont)
                        .setColors(stringBackground, stringColor, numBackground, numStringColor,
                            numNormalColor, numTypingColor, background)
                    }
                );
                panelHeight = panelHeight + element.bounds.height;

                try { // set initial value and define action
                    element.value_(pm[\items].indexOf(paramVal));
                    element.globalAction_({ |e| params[pm[\param]] = pm[\items][e.value]});
                } { |err|
                    element.value_(paramVal).action_({ |e| params[pm[\param]] = e.value});
                };
            };
            panel.add(view);
            win.layout.addSpanning(panel, j, 1,
                (panelHeight / win.layout.minRowHeight(1)));
            j = j + (panelHeight / win.layout.minRowHeight(1));
        };
    };
};

// Draw first column
winCtl.layout.setMinRowHeight(1, 60);
drawPanels.(winCtl, p_INTRFACE);

// objects control
cvObjCtrl = CompositeView().background_(panelColor);
cvObjCtrl.decorator = FlowLayout(cvObjCtrl.bounds);
StaticText(cvObjCtrl, 230@20).background_(layoutHColor).font_(layoutHFont)
.string_(" Objects mass control ").stringColor_(layoutHFontColor);
// initital mass of newly created object
EZSlider(cvObjCtrl, 200@25, " new ", p_MASSSPEC, labelWidth:50, numberWidth:50).font_(layoutHFont)
.setColors(stringBackground, stringColor, sliderBackground, numBackground,
    numStringColor, numNormalColor, numTypingColor, knobColor, background)
.value_(params[\initMass])
.action_({ |e| params[\initMass] = e.value});
// mass control of individual objects
worldCapacity.do{ |i|
    ezkObjCtrl[i] = EZSlider(cvObjCtrl, 200@25," "++i.asString, p_MASSSPEC, labelWidth:50, numberWidth:50)
    .enabled_(false)
    .setColors(Color.grey(alpha:0.1), layoutHColor, objColors[i],
        Color.grey(alpha:0.1), Color.black, nil, nil, objColors[i]).font_(labelFont)
    .action_({ |ez| objects[i].mass = ez.value});
};
winCtl.layout.addSpanning(VLayout(cvObjCtrl), 1, 2, 6);

// aux panel
// Auxiliary controls.
cvAux = CompositeView().background_(panelColor);
cvAux.decorator = FlowLayout(cvAux.bounds);
StaticText(cvAux, 230@20).background_(layoutHColor).font_(layoutHFont)
.string_(" Auxiliary ").stringColor_(layoutHFontColor);
// Record button
Button(cvAux, 200@35)
.states_([
    ["RECORD", Color.black, Color.new(0.8,0.8,0.8)],
    ["Stop", Color.red, Color.new(0.8,0.8,0.8)]
])
.action_({ |bt|
    if (bt.value == 1) {
        // this records buses n..m, where m is last used output (remove after rec, if n > 0)
        Dialog.savePanel({ |path|
            var recordPath;
            s.recChannels = sum(currentChannels.());
            s.recHeaderFormat = "AIFF";
            s.recSampleFormat = "int16";
            recordPath= path ++ ".aif";
            AppClock.sched(0, {fork{s.prepareForRecord(recordPath); s.sync; s.record}})
            }, {
                "Cancelled".postln
            }
        )
    } {
        s.stopRecording
    }
});
// Send sum to sub (next to the last channel used for main output)
Button(cvAux, 200@35)
.states_([
    ["MIX NODE ON", Color.black, Color.new(0.8,0.8,0.8)],
    ["RELEASE MIX NODE", Color.red, Color.new(0.8,0.8,0.8)],
])
.action_({ |bt|
    var ch0, channels, synthName;
    # ch0, channels = currentChannels.();
    synthName = "sr__u__mixNode" ++ channels.asString;
    if (bt.value == 1) {
        s.sendMsg("/s_new", synthName, mixerNode = s.nextNodeID, 1, rootNodeID,
            \inbus, ch0, \outbus, ch0 + channels)
    } {
        s.sendMsg("/n_set", mixerNode, \gate, 0)
    }
});
// Skeleton monitor.
StaticText(cvAux, 150@20).font_(layoutHFont).string_(" Skel monitor ");
skeletonObjectText = StaticText(cvAux, 50@20).string_("").font_(layoutHFont);
// Formant & saw synths ctrls (hard wired to legs).
EZSlider(cvAux, 200@25, " form ", \amp, labelWidth:30, unitWidth:0, numberWidth:30, margin:1@1)
.font_(labelFont)
.value_(params[\synthForm])
.action_({ |e| params[\synthForm] = e.value})
.setColors(stringBackground, stringColor, sliderBackground, numBackground,
    numStringColor, numNormalColor, numTypingColor, knobColor, background);
EZSlider(cvAux, 200@25, " lsaw ", \amp, labelWidth:30, unitWidth:0, numberWidth:30, margin:1@1)
.font_(labelFont)
.value_(params[\synthSaw])
.action_({ |e| params[\synthSaw] = e.value})
.setColors(stringBackground, stringColor, sliderBackground, numBackground,
    numStringColor, numNormalColor, numTypingColor, knobColor, background);
winCtl.layout.addSpanning(VLayout(cvAux), 7, 2, 2);
winCtl.front;

// WORLD
//
world = RedWorld3(RedVector3D[width, height, depth], w_REDVEC_3D_0, 30, 0.8);

// Constant objects.
objGuide = RedBoid(world,
    RedVector3D[width, height, depth].rand, w_REDVEC_3D_0, w_REDVEC_3D_0,
    mass:10, size:10)
.maxForce_(1).wdistance_(3.rrand(13)).wchange_(0.75).wradius_(10.rrand(50));

// Center of the World.
worldStar = RedObject(world,
    RedVector3D[height/2, width/3, depth/2], w_REDVEC_3D_0, w_REDVEC_3D_0,
    mass:params[\starMass], size:10);

// World engine.
winWorld = RedQWindow("tracking", Rect(800, 300, width, height)).background_(Color.black).front;
winWorld.draw{
    if (params[\visualize].booleanValue) {
        // Draw the floor.
        Pen.strokeColor= Color.grey(0.5);
        Pen.strokeRect(Rect.aboutRedVector3D(RedVector[width*0.5, height*0.5, depth], width*0.5, width, height, depth));

        // Report if no forces.
        if (applyForces.booleanValue.not) {
            Pen.fillColor= Color.white;
            Pen.stringAtPoint("NO FORCES!", [width-80, height-20].asPoint);
        };

        // Show coordinates (all objects).
        if (params[\showCoords].booleanValue) {
            world.objects.do { |o, i|
                planeDot = [5, height - ((i+1) * 22)].asPoint;
                Pen.fillColor= Color.white;
                try { // Skeletons can be lost.
                    Pen.stringAtPoint([o.loc[0], o.loc[1], o.loc[2]].round(10).asString, planeDot);
                    Pen.strokeColor = Color.white;
                    Pen.line(
                        planeCoords.value(o.loc, width, height, depth).asPoint,
                        planeDot + [110, 8]
                    );
                    Pen.stroke;
                }
            }
        }
    };

    // Measure the length of rec.
    if(isRecording, {recProgress = recProgress + 1});

    // Force: wind blowing (trig it every 30s).
    wind = sin(2pi * ((winWorld.frame % (30 * params[\fps])) / width));

    // World parameters.
    world.maxVel = params[\worldMaxVel];
    world.damping = params[\worldDamp];
    // World's gravity depends on the presence of skeletons.
    try {
        world.gravity = RedVector3D.newFrom( // Head's position defines vector of gravity
            skeletonObject.at(skeletonObject.keys.minItem)[2].loc/([width, height, depth])-0.5)
    } {
        world.gravity = RedVector3D[1, 1, 1] * (params[\worldGrav]);
    };

    // Render skeletons.
    if (skeletonCoords.size > 0) {
        // Skeleton "trash cleaner" (if a skel stuck for more than 5sec, clear it out).
        skeletonCoords.keys.do{ |k|
            if ((Date.getDate.secStamp.asInteger - skeletonCoords[k][\update].asInteger) >= 5) {
                skeletonObject[k].do{|so|
                    world.remove(so); so.free; so= nil;
                };
                skeletonObject.removeAt(k);
                skeletonCoords.removeAt(k);
            };
        };
        skeletonCoords.keysValuesDo { |k, v|
            // Check if the objects for current skeleton id are out there.
            if (skeletonObject.keys.includes(k).not) {
                skeletonObject.put(k, Dictionary.new);
                5.do{ |i| // 5 are hands, elbows and neck.
                    // The choice of RedAgent is because of its .state Dict, which
                    // carries additional info and objects.
                    skeletonObject[k].put(i,
                        RedAgent(world, w_REDVEC_3D_0, w_REDVEC_3D_0, w_REDVEC_3D_0,
                            params[\starMass], 10).state_(Dictionary.new)
                    );
                    skeletonObject[k][i].state[\guide] = RedObject(world,
                        w_REDVEC_3D_0, w_REDVEC_3D_0, w_REDVEC_3D_0, mass:10, size:10);
                };
                skeletonCoords[k].put(\color, Color.rand);
            };
            // Update all skeletons' locations.
            skeletonObject[k].keysValuesDo {|i, sk|
                try {
                    sk.loc = switch(i,
                        0, {RedVector3D.newFrom(v[\l_hand])},
                        1, {RedVector3D.newFrom(v[\l_elbow])},
                        2, {RedVector3D.newFrom(v[\neck])},
                        3, {RedVector3D.newFrom(v[\r_elbow])},
                        4, {RedVector3D.newFrom(v[\r_hand])}
                    );
                    // update skeleton joint
                    sk.mass = params[\starMass];
                    sk.update;
                    world.contain(sk);
                    // add object on spring
                    sk.state[\guide]
                    .spring(skeletonObject[k][i], 1, 0.1, 0.1)
                    .addForce(world.gravity)
                    .update;
                    world.contain(sk.state[\guide]);
                    if (params[\visualize].booleanValue) {
                        // Render objects.
                        Pen.fillColor = skeletonCoords[k][\color];
                        Pen.strokeColor = skeletonCoords[k][\color];
                        Pen.fillOval(Rect.aboutRedObject3D(sk));
                        // Draw feet (no objects).
                        Pen.fillOval(Rect.aboutRedVector3D(v[\r_foot], v[\r_foot][2].linlin(0,depth, 5,30), width, height, depth));
                        Pen.fillOval(Rect.aboutRedVector3D(v[\l_foot], v[\l_foot][2].linlin(0,depth, 5,30), width, height, depth));
                        try { // connect joints
                            Pen.line(planeCoords.value(sk.loc, width, height, depth).asPoint,
                                planeCoords.value(skeletonObject[k][i-1].loc, width, height, depth).asPoint)
                            .stroke;
                        }
                    }
                }
            };

            // Synths attached to FEET are controlled
            // not by objects, but skeleton coordinates.
            try {
                posFeet[0]= Complex(
                    v[\l_foot][1].linlin(0, width, 1, -1), // y
                    v[\l_foot][0].linlin(0, height, -1, 1) // x
                );
                posFeet[1]= Complex(
                    v[\r_foot][1].linlin(0, width, 1, -1), // y
                    v[\r_foot][0].linlin(0, height, -1, 1) // x
                )
            };

            if (synForm.isNil.not) {
                synForm.set( // right controls \formant
                    \azimuth, posFeet[1].theta,
                    \distance, posFeet[1].rho,
                    \elevation, v[\r_foot][2].linlin(0, depth, -0.5pi, 0.5pi),
                    \amp, v[\r_foot][2].clip(0.4, 0.7),
                    \master, params[\synthForm],
                    \mod, "c"++(currFormCtl ? "").asString,
                    \depth, params[\fieldDepth]);
                synSaw.set(	// left controls \saw
                    \azimuth, posFeet[0].theta,
                    \distance, posFeet[0].rho,
                    \elevation, v[\lFoot][2].linlin(0, depth, -0.5pi, 0.5pi),
                    \amp, v[\lFoot][2].clip(0.4, 0.7),
                    \master, params[\synthSaw],
                    \mod, "c"++(currFormCtl ? "").asString,
                    \depth, params[\fieldDepth]);
            };
        };
        // Report skeletons.
        try {
            skeletonObjectText.string= skeletonObject.keys.asArray.asString
            .replace("[ ","").replace(" ]","");
        }
    } {
        // World Star.
        worldStar.mass = params[\starMass];
        worldStar.size = params[\starSize];
        if (winWorld.mouse != RedVector2D[0, 0]) {
            try {
                worldStar.loc = [winWorld.mouse[0]] ++ [winWorld.mouse[1]] ++ [winWorld.mouse.mean]
            } {
                worldStar.loc = RedVector3D[width/2, height/3, depth/3]
            }
        } {
            worldStar.loc = RedVector3D[width/2, height/3, depth/3]
        };
        worldStar.update;
        world.contain(worldStar);

        if (params[\visualize].booleanValue) {
            Pen.fillColor = Color.new(*[0.71, 0.99, 0.99] * worldStar.loc[2].linlin(0, height, 1, 0.3));
            Pen.fillOval(Rect.aboutRedObject3D(worldStar));
        }
    };

    // Render objects.
    world.objects.do { |o, i|

        // Everybody attracts each other, regardless of the object type or function
        // and even when the World's forces switched off. This helps keeping objects
        // in swarm, while at the same time slowly affects position of the Star.
        if (params[\objAttract].booleanValue && (skeletonObject.size == 0)) {
            world.objects.do { |oo, j|
                if (i != j) {
                    o.addForce(o.gravityForce(oo));
                    if (o.loc.distance(oo.loc) < (o.size*2)) {
                        o.addForce(o.gravityForce(oo).neg * params[\repulsiveForce]);
                    }
                }
            }
        };

        // Process only synth objects (skeleton objects must always be the heaviest ones).
        if ([objGuide, objAudioIn].includes(o).not && (o.mass < params[\starMass])) {
            if (objects.indexOf(o) == nil) {
                // Hot trash cleaner.
                world.remove(o); o.free; o= nil;
            } {
                if (objectsProp.keys.includes(o.hash)) {
                    // control object's age!
                    objectsProp[o.hash].put(\age, objectsProp[o.hash].at(\age) - (1/params[\fps]));
                    if (objectsProp[o.hash].at(\age) <= 0) {
                        // Time to die.
                        removeObject.value(o)
                    } {
                        // The havier the object the fatter it is, linearly.
                        o.size = o.mass * 5;

                        if (applyForces.booleanValue) {

                            if (skeletonCoords.size == 0) {
                                // In the absence of skeletons place a Star in the World.
                                springs = Dictionary.new; // Clear all springs, that were potentially connected to a "ghost" skeleton.
                                o.addForce(o.gravityForce(worldStar));
                                if (o.asString == "a RedBoid") {o.addForceArrive(worldStar.loc)};
                            } {
                                // Sceleton gravity or springs.
                                // Pick up the first recognized sceleton.
                                m = skeletonObject[skeletonObject.keys.asArray.minItem];
                                o.asString.switch(
                                    "a RedBoid", {
                                        o.addForceArrive(m[0].loc);
                                        o.addForceArrive(m[4].loc);
                                    },
                                    "a RedObject", {
                                        if (o.mass >= params[\heavy]) {
                                            // Springs are for heavy objects.
                                            // Springs _tend_ to stick to the "freer" hand, i.e. the one that have objects
                                            // on springs, whose total mass is lighter than the other (thus the .reverse).
                                            // .pow(2) increases chances of the "lighter" hand to be picked up.
                                            hand = [m[0], m[4]].wchoose([
                                                m[0].state.atFail(\totalmass, {0}),
                                                m[4].state.atFail(\totalmass, {0})
                                            ].pow(2).reverse.normalizeSum);
                                            if (springs.keys.includes(o.identityHash).not) {
                                                springs.put(o.identityHash, hand);
                                                hand.state[\totalmass] = hand.state.atFail(\totalmass, {0}) + o.mass;
                                            } {
                                                //Spring params: target, stiffness, damping, length.
                                                try {
                                                    o.spring(springs[o.identityHash],
                                                        params[\springStiff], params[\springDamp], params[\springLen])
                                                } { |err|
                                                    ("Error attaching spring to object: " ++ err).postln;
                                                }
                                            };

                                            // Render springs.
                                            // Works only here, since in any other place it's difficult to find the proper object.
                                            if (params[\visualize].booleanValue) {
                                                Pen.strokeColor= Color.cyan;
                                                springs.keysValuesDo { |sp, h|
                                                    try {
                                                        Pen.line(
                                                            planeCoords.value(o.loc, width, height, depth).asPoint,
                                                            planeCoords.value(springs[o.identityHash].loc, width, height, depth).asPoint
                                                        );
                                                        Pen.stroke;
                                                    }
                                                }
                                            }
                                        } { // Remove springs, if any, and take the mass off from hand.
                                            o.addForce(o.gravityForce(m[0]));
                                            o.addForce(o.gravityForce(m[4]));
                                            hand= if(springs[o.identityHash] == m[0].identityHash, {m[0]}, {m[4]});
                                            hand.state[\totalmass]= (hand.state.atFail(\totalmass, {0}) - o.mass).max(0);
                                            springs.removeAt(o.identityHash);
                                        }
                                    }
                                )
                            };
                            // The World's forces.
                            o.addForce(world.gravity);
                            o.addForce(wind);
                        };
                        o.update;
                        world.contain(o);
                    }
                };
                // Render objects.
                if (params[\visualize].booleanValue) {
                    try {
                        Pen.fillColor = objColors[objects.indexOf(o)].alpha_(o.loc[2].linlin(0, height, 1.0, 0.3));
                    } {
                        Pen.fillColor = Color.rand;
                    };
                    Pen.fillOval(Rect.aboutRedObject3D(o));
                    Pen.fillColor = Color.white;
                    Pen.stringAtPoint(
                        objects.indexOf(o).asString,
                        (planeCoords.value(o.loc, width, height, depth, scale:1, focal:0.5) - [5, 5]).asPoint
                    );
                };
                // Control object's synth.
                if (synths.at(o.hash).isNil.not) {
                    pos = Complex(
                        o.loc[1].linlin(0, width, 1, -1), // y
                        o.loc[0].linlin(0, height, -1, 1) // x
                    );
                    try {
                        s.sendMsg("/n_set", synths.at(o.identityHash).asInteger,
                            \azimuth, pos.theta,
                            \distance, pos.rho, // distance from the center
                            \elevation, o.loc[2].linlin(0, depth, 0.5pi, -0.5pi), // How high the object is (inverse).
                            \amp, o.mass.linlin(1,11, 0.01,0.8) + (o.vel.mag * 0.01), // The faster the louder.
                            \ax, o.loc[0] / width, \ay, o.loc[1] / height, \az, o.loc[2] / depth,
                            \velocity, o.vel.mag / world.maxVel,
                            \master, params[\master],
                            \depth, params[\fieldDepth]
                        )
                    };
                    p_MASSSPEC.map(o.mass);
                }
            }
        }
    };

    // Guide obj.
    if (objGuide.isNil.not) {
        // Guidance source (free float affected by wind only, feet, hands).
        if (applyForces.booleanValue) {
            params[\partGuide].switch(
                \wind, { }, // wind affects it anyway (see below)
                \feet, {
                    try {
                        objGuide.addForceArrive(skeletonCoords.at(skeletonCoords.keys.minItem)[[\r_foot, \l_foot].choose]);
                    };
                },
                \object, {
                    try {
                        skeletonObject.keysValuesDo { |id, obj|
                            objGuide.addForceArrive(obj[0].loc).addForceArrive(obj[4].loc);
                        };
                    };
                }
            );
            // Apply only world's forces.
            objGuide.addForce(world.gravity);
            objGuide.addForce(wind);
            try {
                objGuide.addForce(objGuide.gravityForce(worldStar))
            };
        };
        objGuide.update;
        world.contain(objGuide);
        if (params[\visualize].booleanValue) {
            try {
                Pen.fillColor = Color.white.alpha_(objGuide.loc[2].linlin(0, height, 1.0, 0.3));
                Pen.fillOval(Rect.aboutRedObject3D(objGuide));
            }
        };
        posGuide= Complex(
            objGuide.loc[1].linlin(0, width, 1, -1), // x
            objGuide.loc[0].linlin(0, height, -1, 1) // y
        );
    };

    // Audio through object and synth.
    if (params[\audioIn].booleanValue) {
        if (objAudioIn.isNil) {
            objAudioIn = RedBoid(world, RedVector3D[width, height, depth].rand,
                w_REDVEC_3D_0, w_REDVEC_3D_0, 10, 10)
            .maxForce_(1).wdistance_(3.rrand(13))
            .wchange_(0.75).wradius_(10.rrand(50));

            audioThroughID = initGroup.(\sr__r__authro,
                busnum: a_BUS_POOL[1], // last bus number from pool dedicated to audio through.
                parm: [\inbus, params[\inbus]])
        };

        // Set actual inbus.
        s.sendMsg("/n_set", audioThroughID, \inbus, params[\inbus])
    } {
        if (audioThroughID.isNil.not) {
            removeGroup.(audioThroughID);
            audioThroughID = nil
        };
        objAudioIn.free; objAudioIn = nil;
    };

    if (objAudioIn.isNil.not) {
        if (applyForces.booleanValue) {
            objAudioIn.addForce(wind);
            objAudioIn.addForce(world.gravity);
            skeletonObject.do { |obj|
                try {
                    objAudioIn.addForceArrive(obj[0].loc).addForceArrive(obj[4].loc);
                }
            };
            try {
                objAudioIn.addForce(objAudioIn.gravityForce(worldStar))
            };
        };
        objAudioIn.update;
        world.contain(objAudioIn);

        // Render Object Audio in.
        if (params[\visualize].booleanValue) {
            try {
                Pen.fillColor= Color.blue(0.7, 0.8).alpha_(objAudioIn.loc[2].linlin(0, height, 1.0, 0.3));
                Pen.fillOval(Rect.aboutRedObject3D(objAudioIn));
            }
        };

        // Parameters for synths.
        posAudioIn = Complex(
            objAudioIn.loc[1].linlin(0, width, 1, -1), // y
            objAudioIn.loc[0].linlin(0, height, -1, 1) // x
        );
        s.sendMsg("/n_set", audioThroughID,
            \azimuth, posAudioIn.theta,
            \distance, posAudioIn.rho,
            \elevation, objAudioIn.loc[2].linlin(0, depth, -0.5pi, 0.5pi),
            \master, params[\master],
            \depth, params[\fieldDepth]
        )
    };

    // Particles.
    if (params[\particles].booleanValue) {
        if (winWorld.frame % (params[\fps] * (params[\partFreq])).round == 0) {
            if (skeletonObject.size.booleanValue) { // hands guide particles
                guides = all{: l[k].state[\guide], l <- skeletonObject, k <- l.keys, [0, 4].includes(k)}
            } { // guide object in the absence of skeleton
                guides = [objGuide]
            };
            guides.do { |g, i|
                // probability of particle being generated depends on the objects velocity
                partProb = sigmoid.(
                    ratio:params[\partSigmoidRatio],
                    value:g.vel.mag.linlin(0, world.maxVel, world.maxVel.neg, world.maxVel));
                if (partProb.coin.booleanValue) {
                    // particle has inertia (follows trajectory of its guide)
                    newPart = RedParticle(world, g.loc, 0, objGuide.vel.tanh * params[\partInitAccel].max(0.01), 10, 10)
                    .age_(params[\partAgeThresh].logistic);
                    sys.add(newPart);
                    partSynths[newPart.identityHash] = initGroup.(params[\partSynth],
                        parm: [\inbus, params[\inbus], \cr, 4, \att, 0.1]);
                };
            };
        };
    };

    // Control Particles synths.
    sys.update;
    sys.do{ |p|
        if(p.alive) {
            posPart = Complex(
                p.loc[1].linlin(0, width, 1, -1), // y
                p.loc[0].linlin(0, height, -1, 1) // x
            );
            s.sendBundle(0.01,
                ["/error", 1], // turn errors off (locally)
                ["/n_set", partSynths[p.identityHash].asInteger,
                    \azimuth, posPart.theta,
                    \distance, posPart.rho,
                    \elevation, p.loc[2].linlin(0, depth, 0.5pi, -0.5pi),
                    \velocity, p.vel.mag / world.maxVel,
                    \ax, p.loc[0] / width, \ay, p.loc[1] / height, \az, p.loc[2] / depth,
                    // velocity boost amp, but it drops with age,
                    // adjusted for maximum age and particles density
                    \amp, sigmoid.(
                        ratio:params[\partFreq] / (params[\partAgeThresh] * world.maxVel),
                        value:(p.age * p.vel.mag.linlin(0, world.maxVel, world.maxVel.neg, world.maxVel))),
                    \master, params[\master],
                    \depth, params[\fieldDepth]]
            );
        };

        // Render particles.
        if (params[\visualize].booleanValue) {
            try {
                Pen.fillColor= Color.red(p.age / params[\partAgeThresh], 1)
                .alpha_(p.loc[2].linlin(0, height, 1.0, 0.3));
                Pen.fillOval(Rect.aboutRedObject3D(p));
            } { |err|
                err.postln;
            }
        }
    };
};
winWorld.animate = true;


// HELPER FUNCTIONS
//
// Increments integers with a limit: resets to `lo` every time in + step reaches `hi`.
clipInc = { |in=0, step=1, lo=0, hi=inf| ((in + step).clip(lo, hi) % hi).clip(lo, hi)};


// Simple sigmoid function.
sigmoid = { |ratio, value| 1 / (1 + exp((ratio * value).neg))};


// Project 3D coordinates on the plane.
planeCoords = { arg vector, width, height, depth, scale=1, focal=0.5;
    var x, y, z, ox, oy;
    z = (depth - vector[2] / (depth * scale)).linlin(0, 1, focal, 1);
    x = vector[0] * z;
    y = vector[1] * z;
    ox = 1 - z * (width * 0.5) + x;
    oy = 1 - z * (height * 0.5) + y;
    [ox, oy]
};


// Figure out first output channel and total number of output channels.
currentChannels = {
    var chOut, chNum, str;
    chOut = params[\outbus];
    str = params[\confSurround].asString;
    chNum = str[f.size-1..].asInteger;
    if (chNum == 0) {chNum = str[f.size-2..].asInteger};
    [chOut, chNum]
};


// Allocate a buffer and start recording into file.
recBufStart = { arg bufnum, inbus, numchannels, path, headformat= 'aiff', bitdepth= 'int16';
    bufnum = bufnum ?? s.bufferAllocator.alloc(1);
    s.sendMsg("/b_alloc", bufnum, 32768 * numchannels, numchannels, [
        "/b_write", bufnum, path, headformat, bitdepth, 0, 0, 1]);
    recSynth = Synth.tail(RootNode(Server.default), "sr__r__rec" ++ numchannels,
        [\inbus, inbus, \bufnum, bufnum]);
    isRecording = true;
    recProgress = 0;
    bufnum // returns bufnum
};

// Release recording synth.
recBufStop = { |bnum|
    try{recSynth.free};
    s.sendMsg("/b_close", bnum, ["/b_free", bnum]);
    isRecording = false;
};

// Remove object from the world, release the corresponding synth.
removeObject= { |o|
    var objInd, objId;
    if(objects.includes(o), {
        objInd = objects.indexOf(o);
        objId = o.identityHash;
        { ezkObjCtrl[objInd].enabled_(false) }.defer; // Disable mass ctrl.
        if(springs.keys.includes(objId), {springs.removeAt(objId)}); // free springs
        if(synths.at(objId).isNil.not, {
            removeGroup.(synths[objId], 2.0.rand); // release corresponding group
            synths.removeAt(objId);
            objectsProp.removeAt(objId); // wipe out object properties
        });
        objects[objInd] = nil;
        world.remove(o); o.free; o = nil;
    });
};

// Init new object, record its properties, control stack index.
initObject = { |objectMass=5, objectType="a RedObject", objectAge=inf, objectPos= nil|
    var newObject, initPos;
    if(currObj == objects.size, {currObj= 0}); // Objects are in FIFO stack.
    if(objects.at(currObj).isNil.not, { // Is currObj index already occupied?
        if(objects.indexOf(nil) != nil, {currObj = objects.indexOf(nil)});
    });

    // Try to determine the initial position of the object.
    if (objectPos.isNil) {
        initPos = RedVector3D[width, height, depth].rand;
    } { arg error; // Random if unsuccessful.
        initPos = RedVector3D.newFrom(objectPos);
    };
    // Create new object.
    newObject = switch(objectType.asString,
        "a RedBoid", {
            RedBoid(world, initPos, w_REDVEC_3D_0, w_REDVEC_3D_0, objectMass, objectMass * 5)
            .maxForce_(1).wdistance_(3.rrand(13)).wchange_(0.75).wradius_(10.rrand(50))
        },
        "a RedObject", {
            RedObject(world, initPos, w_REDVEC_3D_0, w_REDVEC_3D_0, objectMass, objectMass * 5)
        }
    );
    objects.put(currObj, newObject); // Place new object to the stack.
    objectsProp[newObject.identityHash] = (age: objectAge);
    currSynth = currObj;
    currObj = currObj + 1; // Increase stack index.
    newObject // Return newly created object.
};

// Create new object's group, insert synth and spatializer into it.
initGroup = { |synth, bufnum, busnum, parm|
    var spatial, groupID, l, h;
    spatial = "sr__s__" ++ params[\confSurround].toLower; // spatializer's name
    groupID = s.nextNodeID;
    if (busnum.isNil) { // internal bus for routing
        #l, h = a_BUS_POOL;
        busnum = clipInc.(currBusRoute ?? l, lo:l, hi:h);
        currBusRoute = busnum;
    };
    s.sendBundle(0.001,
        ["/error", 1], // turn errors off (locally)
        ["/g_new", groupID, 1, rootNodeID], // add new group to root's tail
        ["/s_new", spatial, s.nextNodeID, 1, groupID, // add spatializer to new group's tail
            \inbus, busnum, // getting signal from synth
            \outbus, params[\outbus]], // to main output
        ["/s_new", synth, s.nextNodeID, 0, groupID, // add synth to new group's head
            \inbus, params[\inbus], // getting signal from external input
            \outbus, busnum, // feeding into spatilizer
            \bufnum, bufnum] ++ (parm ? [])
    );
    groupID // return ID of the Group created
};

// Release all synths from group, wait until released, then remove group node from server.
removeGroup = { |groupID, release=2|
    Routine({
        [
            ["/n_set", groupID, \rel, release, \gate, 0],
            ["/n_free", groupID]
        ].do { |l|
            s.listSendMsg(l);
            release.wait;
        }
    }).play;
};

// Prepare the buffer and start the synth.
startSynth = { |synthName='sr__e__silencio', updateBuf=false, parm=nil|
    var buff, group, taskLoadBuf;
    recBufStop.value(currBufnum); // stop recording
    if(updateBuf) { // load buffer
        buff = Buffer.read(s, currFilename);
        taskLoadBuf = Task({
            inf.do { |j|
                if(buff.numChannels != nil) {
                    recProgress = 0;
                    group = initGroup.(synthName, buff.bufnum, parm:parm);
                    synths.put(objects[currSynth].identityHash, group); // register synth
                    taskLoadBuf.stop;
                };
                0.01.wait;
            };
        }).start;
    } {
        buff = if (synthName.asString.find("__g__").isNil.not) {
            cyclicBuf.bufnum // granular synths require buffer with sound
        } {
            scaleBuf.bufnum // electronic synths require buffer with Scale
        };
        group = initGroup.(synthName, buff, parm:parm);
        synths.put(objects[currSynth].identityHash, group); // register synth
    }
};

startFeetSynths= { |gate, tFormAttRel, tSawAttRel|
    // synths controlled by feet enter slowly and remain quiet
    // Warning! master volume is separate from the rest synths master
    if(gate != 0, {
        if(synForm == nil, {
            synForm= Synth.head(rootNodeID, \sr__e__form,
                [\att, tFormAttRel, \amp, 0.4, \master, params[\synthForm],
                    \azimuth, pi.bilinrand, \spread, 10.rrand(50), \mod, "c"]);
            synSaw= Synth.head(rootNodeID, \sr__e__lsaw,
                [\att, tSawAttRel, \amp, 0.4, \master, params[\synthSaw],
                    \azimuth, pi.bilinrand, \spread, 10.rrand(50), \mod, "c"]);
            c_CTRL_SYNTH_ARGS.size.do({ |i|
                synthCtrl[i]= s.nextNodeID;
                s.sendBundle(0.1, ["/s_new", c_CTRL_SYNTH_ARGS[i][0].asString, synthCtrl[i]],
                    ["/n_set", synthCtrl[i], "outbus", c_CTRL_SYNTH_ARGS[i][1]]);
            });
        });
        }, {
            if(synForm != nil, {
                synForm.set(\gate, 0, \done, 2, \rel, tFormAttRel);
                synSaw.set(\gate, gate, \done, 2, \rel, tSawAttRel);
                synForm= nil; synSaw= nil;
                synthCtrl.size.do({ |i|
                    s.sendMsg("/n_free", synthCtrl[i]); // clear if the synth is "stuck"
                    synthCtrl[i]= nil;
                });
            });
    });
};

// Tasks.
fillStream = { |curr|
    var arrBase= #[0, 2, 3, 6], arrDer0= #[ 2, 3, 6, 7 ];
    streamList[curr]= Prout({
        loop {
            rrand(2,10).do({
                0.yield;
                arrBase.choose.yield;
                2.yield;
                arrDer0.choose.yield;
            });
            rrand(3,6).do({
                (arrDer0.choose + #[12, 24].choose).yield;
            });
        }
    }).asStream
};

runTask1 = { |on|
    if(on.booleanValue) {
        fillStream.value(0); // create the stream
        {
            streamList[0].do{ |val|
                var dur;
                synForm.set(\mnote, val.midicps);
                synSaw.set(\mnote, (val * 0.2).midicps, \mod, val.linlin(0,32, 0, -1));
                dur= if(val < 18, {0.25}, {2.0.rand});
                dur.wait;
            }
        }.fork(TempoClock());
    } {
        streamList[0].stop; streamList[0]= nil;
    }
};

runTask2= { |on|
    if(on.booleanValue) {
        fillStream.value(0); // create the stream
        {
            streamList[0].do{ |val|
                var dur;
                synForm.set(\mnote, val.midicps, \mod, 0);
                synSaw.set(\mnote, (val * 0.2).midicps);
                synForm.set(\gate, 1, \att, 0.5);
                synSaw.set(\gate, 0, \done, 0, \rel, 0.5);
                if(val < 18, {
                    synSaw.set(\gate, 1, \att, 0.5);
                    2.0.rand.wait;
                    synSaw.set(\gate, 0, \done, 0, \rel, 0.1);
                    if(0.3.coin, {
                        synForm.set(\mnote, val.midicps-12, \mod, val.linexp(0,18, 0.1, 0.6));
                        [0.15, 0.5].choose.wait;
                    });
                    }, {
                        synSaw.set(\gate, 0, \done, 0, \rel, 0.75);
                        [0.25, 0.75].choose.wait;
                        synSaw.set(\gate, 1, \att, 0.5);
                });
                dur= if(val < 18, {0.25}, {rrand(0.5, 1.5)});
                dur.wait;
            }
        }.fork(TempoClock());
    } {
        streamList[0].stop; streamList[0]= nil;
    }
};

//--keyboard control
winWorld.view.keyUpAction= { arg view, char, modifiers, unicode, keycode;
    case
    {keyObjType.includes(keycode)} { // stop rec, create obj, etc.
        if ([0, 256].includes(modifiers)) {
            initObject.(params[\initMass], c_KEY_OBJ_SYNTH.matchAt(keycode)[0]);
            startSynth.(c_KEY_OBJ_SYNTH.matchAt(keycode)[1], recProgress > 30);
            // Enable interface for mass control and set the label.
            ezkObjCtrl[currSynth].enabled_(true).value = params[\initMass];
            ezkObjCtrl[currSynth].set(
                currSynth.asString ++ " " ++
                c_KEY_OBJ_SYNTH.matchAt(keycode)[1].asString.split($_).last
            );
        }
    }
};

winWorld.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    var checkRout;
    // [char, modifiers, unicode, keycode].postln;
    case
    {keycode == 45} { // N - new object (???)
        checkRout= Routine({
            inf.do({
                if(rectimeRep != nil, {
                    (rectimeRep+0.1).wait;
                    checkRout.stop
                });
                0.01.wait;
            });
        }).play(AppClock);
    }
    {keycode == 7} { // X - clean all objects and synths
        if([0, 256].includes(modifiers), {objects.do({|o| removeObject.value(o)})});
    }
    {keycode == 45} { a.setn(\freq, [700, 705, 890]); }
    {keycode == 8} {  // C -
        synths.keys.do{ |k|
            s.sendMsg("/n_setn", synths[k].asInteger, \scale, 7, 0,1,3,5,7,8,10);
        }
    }
    {keycode == 9} { // V - remove all forces
        if( [0, 256].includes(modifiers), {applyForces= (1 - applyForces).abs});
    }
    {keycode == 6} { // Z - info
        if( [0, 256].includes(modifiers), {
            postf("skeleton objects: %\nworld.objects (%): %\nobjects: %\nobjects Properties: %\nsynths: %\nparticle system: %\nparticle synths: %\nsprings: %\n\ntracking window: left %, top %, width %, height %\ncontrol window: left %, top %, width %, height %\n",
                skeletonObject, world.objects.size,
                world.objects, objects, objectsProp, synths,
                sys.objects, partSynths, springs,
                winWorld.bounds.left, winWorld.bounds.top, winWorld.bounds.width, winWorld.bounds.height,
                winCtl.bounds.left, winCtl.bounds.top, winCtl.bounds.width, winCtl.bounds.height);
            "\nparams:\n------".postln;
            params.order.do{ |k| postf("%: %\n", k, params[k])};
        });
    }
    {keycode == 37} { // L - start/stop "feet" synths
        case
        {[0, 256].includes(modifiers)} { // synths controlled by feet enter slowly and remain quiet
            if(synForm == nil,
                {startFeetSynths.value(1, 120, 240)},
                {startFeetSynths.value(0, 30, 30)}
            );
        }
        {[524576, 524608].includes(modifiers)} {
            if(synForm == nil,
                {startFeetSynths.value(1, 0.1, 0.1)},
                {startFeetSynths.value(0, 0.1, 0.1)}
            );
        }
    }
    {keycode == 4} { // H - run/stop Task 1
        if( [0, 256].includes(modifiers), {
            if(synForm != nil, {
                if(isActiveTask2.booleanValue, { // clear opposite task
                    isActiveTask2= 0;
                    runTask2.value( isActiveTask2 );
                });
                isActiveTask1= 1-isActiveTask1;
                runTask1.value( isActiveTask1 );
            });
        });
    }
    {keycode == 38} { // J - run/stop Task 2
        if( [0, 256].includes(modifiers), {
            if(synForm != nil, {
                if(isActiveTask1.booleanValue, { // clear opposite task
                    isActiveTask1= 0;
                    runTask1.value( isActiveTask1 );
                });
                isActiveTask2= 1-isActiveTask2;
                runTask2.value( isActiveTask2 );
            });
        });
    }
    {keycode == 40} { // K - reset synForm & synSaw after Tasks
        if( [0, 256].includes(modifiers), {
            if(synForm != nil, {
                synForm.set(\mnote, 0);
                synSaw.set(\mnote, 0);
            });
        });
    }
    {keycode == 123} { //[<-] prev ctrl for synSaw
        if(currSawCtl == nil, {
            currSawCtl= c_CTRL_SYNTH_ARGS.size-1
            },
            {
                currSawCtl= currSawCtl-1;
                if(currSawCtl < 0, {currSawCtl= nil});
        });
    }
    {keycode == 124} { //[->] next ctrl for synSaw
        if(currSawCtl == nil, {
            currSawCtl= 0
            },
            {
                currSawCtl= currSawCtl+1;
                if(currSawCtl == c_CTRL_SYNTH_ARGS.size, {currSawCtl= nil});
        });
    }
    {keycode == 125} { // [down] next ctrl for synForm
        if(currFormCtl == nil, {
            currFormCtl= 0
            },
            {
                currFormCtl= currFormCtl+1;
                if(currFormCtl == c_CTRL_SYNTH_ARGS.size, {currFormCtl= nil});
        });
    }
    {keycode == 126} { // [up] prev ctrl for synForm
        if(currFormCtl == nil, {
            currFormCtl= c_CTRL_SYNTH_ARGS.size-1
            },
            {
                currFormCtl= currFormCtl-1;
                if(currFormCtl < 0, {currFormCtl= nil});
        });
    }
    {keycode == 51} { // [return] - delete last created object
        if( [0, 256].includes(modifiers), {
            removeObject.value(objects.at(if(currObj > 0, {currObj-1}, {9})));
        })
    }
    {keyObjType.includes(keycode)} { // start rec
        if ([0, 256].includes(modifiers)) {
            if (isRecording.not && // only if there's no current rec
                c_KEY_OBJ_SYNTH[keycode][1].asString.find("__g__").isNil.not // and granular synths is being created
            ) {
                if (~tempDir.isNil.not) {
                    currFilename = ~tempDir +/+ (format("sr_%.aif", Date.getDate.stamp.asString));
                    currBufnum = recBufStart.(inbus: params[\inbus], numchannels: 1, path: currFilename);
                }
            }
        };
    }
    {c_KEY_OBJ.includes(keycode)} { // delete object with given index
        if ([0, 256].includes(modifiers)) {
            if(objects.at(c_KEY_OBJ.indexOf(keycode)) != nil, {
                removeObject.value(objects[c_KEY_OBJ.indexOf(keycode)]);
            })
        }
    }
};

// Shutting down.
shutDown = {
    // Clean OSP responders.
    oscRemoveFunc.value();
    // Free buffers.
    cyclicBuf.free;
    s.sendMsg("/n_free", cyclicSynthID);
    s.sendMsg("/n_free", audioThroughID);
    // Release objects and particles synths.
    synths.keys.do { |k| s.sendMsg("/n_free", synths[k])};
    partSynths.keys.do { |k| s.sendMsg("/n_free", partSynths[k])};
    // Release specific synths.
    synForm.free; synSaw.free;
    // Close windows.
    if (winWorld.isClosed.not) {winWorld.close};
    if (winCtl.isClosed.not) {winCtl.close};
    // Write params into file.
    "Saving settings!".postln;
    try {
        paramsFile= File.new(paramsFilename, "w");
        paramsFile.write(params.asCompileString);
        paramsFile.close;
    } {
        "WARNING! Cannot write params file!".postln;
    };
    "Good bye...".postln;
};
winCtl.onClose = shutDown;
CmdPeriod.doOnce({shutDown.value()});
\
)