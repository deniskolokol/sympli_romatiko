// Sympli Ro̱matiko
// redUniverse objects (3D) controlled by Kinect (via OSCeleton) in surround sound (Josh Parmenter's ambisonics)
//
// calibration
// $ cd /Users/deniskolokol/dev/kinect/libfreenect/build/bin
// $ ./glview
//
// OSCeleton (with multiplier for depth!):
// $ cd /Users/deniskolokol/dev/kinect/OpenNI-Bin-MacOSX-v1.1.0.41/OSCeleton/
// $ ./osceleton -p 57120 -mz 0.7
//
// keyboard:
//         N - new object (???)
//         X - clean all objects and synths
//         C - clean all buffer players
//         V - (press and hold) remove all forces
//         Z - info on objects and synths
//         L - start/stop "feet" synths - fade in/out
//         Alt+L - start/stop "feet" synths - hot
//         1, 2, .., 0 - delete obj by its index
//         --init objects (press & hold for, rec into buffer or press for cyclic buffer):
//         Q - regular (fountain), light (mass <= 2)
//         W - drone, light (mass <= 2)
//         E - "gusts of wind" (stutter), heavy (2 < mass <= 5)
//         R - slicing, variable (0.5 < mass <= 5)
//         T - loop, variable (0.5 < mass <= 5)
//         Y - loop with random trigger time, variable (0.5 < mass <= 5)
//         U - electronic "probe"
//         I - electronic "CMB"
//         O - electronic "star field"
//         A - trigger \ev_start
//
// TO-DO:
// * A subsystem for composition. Should include options:
// - sections of fixed sequences (which kind of object appears after
//   which, or at what presize time)
// - sections of automatic time management (based on Perlin noise
//   or Lorenz attractor or the like, together with Markov chain)
// - desicion tree for "scene analysis" (sounds of a particulary
//   category can "live" together)
// * "Project" springs on the surface, not just connect coordinates
// * Gather coordinates display in the lower left corner of window, connect with objects by thin lines
// * BUG! After many openings of the system:
//   ERROR: No more buffer numbers -- free some buffers before allocating more.
//   - this is caused by speakerBuff of VBAP synths, see:
//     speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
//     It should be one buffer, only bufnum should be sent to synths, and it should be cleared on shundown
// IDEA:
// Check what happens if the World's global parameters (max velocity & damping)
// depend on the number of objects and their total mass (the more objects, the "hotter"
// the world or vise versa).

(
var skelLimit=1, theHeaviest=120, worldCapacity=10, applyForses=1, fps=60;
var massSpec=ControlSpec(1, 11, \lin, 1);
var speakerArr, speakerBuff;
var w, world, width, height, depth, margin=0;
var skeletonCoords=Dictionary.new, skeletonObject=Dictionary.new; // Dictionaries for skeletons' coordinates and objects
var synths, springs, objects, objectsProp, nodes;
var currObj=0, currObjType, currSynType, objInd, mass, pos,
    objGuide=nil, synGuide=nil, posGuide, objAudioIn=nil, synAudioIn=nil, posAudioIn,
    wind, hand;
var rectimeRep, midinote, channels;
var groupWorldId, groupAux= Group.new(s);
var inbus=30, recBufStart, recBufStop, recSynth, isRecording=false, recProgress=0, currFilename, currBufnum, currBuffer;
var startSynth, releaseSynth, cyclicBuf, cyclicSynth, initObject, removeObject, registerNode, unRegisterNode;
var synForm=nil, synSaw=nil, posFeet=[nil, nil], synthCtrlArgs, synthCtrl, currFormCtl=nil, currSawCtl=nil, startFeetSynths;
var loadBufRout, guideNodeID=0;
var fillStream, streamList= [nil], runTask1, runTask2,
    isActiveTask1=0, isActiveTask2= 0,
    arrBase= #[0, 2, 3, 6], arrDer0= #[ 2, 3, 6, 7 ];
var keyObj= #[29, 18, 19, 20, 21, 23, 22, 26, 28, 25], // keycodes for tracing objects 0-9. ORDER MATTERS!!!
keyObjSynth= ( // keycodes for creating objects and synths of different kinds
    12: ["a RedObject", \sr_regu],	// q
    13: ["a RedObject", \sr_dron],	// w
    14: ["a RedObject", \sr_gust],	// e
    15: ["a RedBoid", \sr_slid],	// r
    17: ["a RedBoid", \sr_loop],	// t
    16: ["a RedObject", \sr_tube],	// y
    32: ["a RedObject", \sr_prob],	// u
    34: ["a RedObject", \sr_cmb],	// i
    31: ["a RedObject", \sr_star],	// o
    35: ["a RedObject", \sr_melo],	// p
    33: ["a RedObject", \sr_ringz],	// [
    30: ["a RedObject", \sr_pulse],	// ]
    42: ["a RedObject", \sr_analog] //\ (the answer to the ultimate question ))
);
var keyObjType= keyObjSynth.keys().asArray; // for easy access to keycodes
var cvObjCtrl, cvAux, cvAudio, cvParticles, cvVisual,
    ezkObjCtrl= Array.fill(worldCapacity, {nil});
var cvSkeletonObject, skeletonObjectText;
var objColors= Array.fill(worldCapacity, {Color.rand});

// OSC communication.
var schedulerAddr, skeletonAddr;
var oscObjScheduler, oscParmScheduler, oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost;
var oscRemoveFunc;

// Particles.
var sys, newPart, posPart, partSynths=Dictionary.new, partGuideItems= [\wind, \feet, \object];

// Surround sound system - possible configurations.
var confSurround= #[\VBAP4, \Ambisonic2, \Ambisonic4, \Ambisonic8];

// Global params.
var params=Dictionary.new;

// Where to save/read from into global params.
var paramFile, soundsDir= "/Users/deniskolokol/Music/bibeast/sounds/";

// A center of the World.
var worldStar, cvWorld;

// Interface elements.
var panelColor=Color.new255(238, 223, 204, alpha:60),
layoutHColor=Color.new255(100, 100, 100), layoutHFontColor=Color.new255(200, 200, 200);
var labelFont=Font("Helvetica", 9), layoutHFont=Font("Helvetica", 11);
var ezElements=List.new;

// System related.
var shutDown;

// Utils.
var planeCoords, planeDot;
var zero3DVector=#[0, 0, 0];

// Initial.
schedulerAddr = NetAddr.new("127.0.0.1", 57120);
skeletonAddr = NetAddr("192.168.1.101", nil); //NetAddr("127.0.0.1", nil);
depth = width = height= Window.screenBounds.height/2+160;
objects = Array.fill(worldCapacity, { nil }); // container for physical objects
objectsProp = Dictionary.new; // Properties of objects.
synths = Dictionary.new; // Container for synths connected to objects.
springs = Dictionary.new; // Container for springs.
nodes = Dictionary.new; // Descriptor of Server node ID vs. controlling obj, its age, etc.
groupWorldId = s.nextNodeID; // Group Id for objects' synths
s.sendMsg("/g_new", groupWorldId);
synthCtrlArgs = #[[\kr_ml0, 0], [\kr_mg2, 1], [\kr_mg0, 2], [\kr_ml1, 3], [\kr_mg1, 4], [\kr_mh0, 5]]; //[\synthName, ctl bus]
synthCtrl = Array.fill(synthCtrlArgs.size, { nil });
cyclicBuf = Buffer.alloc(s, s.sampleRate, 1); // 1s single channel Buffer
channels = (0..30);
// Particles system.
sys = RedParticleSystem.new;
// When particle is dead, release its synth.
sys.removeAction = {|o|
    partSynths.at(o.hash).set(\rel, 1.0.rand, \gate, 0);
    partSynths.removeAt(o.hash)
};

loadBufRout= Routine({
    inf.do({ |j|
        if(cyclicBuf.numChannels != nil, {
            cyclicSynth= Synth.head(groupAux, \syninbuff, [ //recording synth
                \bufnum, cyclicBuf.bufnum, \busnum, inbus, \volIn, 1, \gate, 1, \dur, 1]);
            loadBufRout.stop;
        });
        0.01.wait;
    });
}).play(AppClock);

// Preferences - in params file
"Trying to open params file...".postln;
try{
    paramFile= File("preferences/knparams.dk", "r");
    params= paramFile.readAllString.interpret;
    "OK!".postln;
}
{
    ("Sorry, cannot open params file"++String.scDir++"/preferences/knparams.dk" ++"!").postln;
    "Will be replaced on window close, so please take care of the current file (if any)!".postln;
};

// Speakers setup.
//speakerArr= #[-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 2pi]; // 8 channel ring
speakerArr= #[-0.5pi, 0.5pi, 1.5pi, -1.5pi];
speakerBuff= Buffer.loadCollection(s, speakerArr);

// OSC communication.
oscSkeletonLost = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from %:% received %\n", addr, recvPort, msg);
    skeletonCoords.removeAt(msg[1].asInteger);
}, '/lost_skel', skeletonAddr);

oscSkeletonNew = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from %:% received %\n", addr, recvPort, msg);
    if (skeletonCoords.size < skelLimit) {
        skeletonCoords.put(msg[1].asInteger, (
            \update: Date.getDate.secStamp,
            \rHand: zero3DVector, \lHand: zero3DVector,
            \rElbow: zero3DVector, \lElbow: zero3DVector,
            \rFoot: zero3DVector, \lFoot: zero3DVector,
            \neck: zero3DVector
            )
        )
    }
}, '/new_skel', skeletonAddr);

oscSkeletonJoint = OSCFunc({ arg msg, time, addr, recvPort;
    var skel=nil, joint, x, y, z;
    // postf("from %:% received %\n", addr, recvPort, msg);
    #joint, x, y, z = [
        msg[1],
        msg[3].linlin(0, 1, margin, width - margin).round,
        msg[5].linlin(0.3, 3.4, margin, height - margin).round,
        msg[4].linlin(0, 1, margin, depth - margin).round
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
        joint.switch(
            'neck', {skel[\neck] = [x, y, z]},
            'r_hand', {skel[\rHand] = [x, y, z]},
            'l_hand', {skel[\lHand] = [x, y, z]},
            'r_elbow', {skel[\rElbow] = [x, y, z]},
            'l_elbow', {skel[\lElbow] = [x, y, z]},
            'r_foot', {skel[\rFoot] = [x, y, z]},
            'l_foot', {skel[\lFoot] = [x, y, z]}
        );
        skel[\update] = Date.getDate.secStamp;
    }
}, '/joint', skeletonAddr);

oscObjScheduler = OSCFunc({ arg msg, time, addr, recvPort;
    // OSC function that catches scheduling and sequencing messages.
    // Message format:
    // [/worldobj, synthType, objectType, lifetime, initPos_X, initPos_Y, initPos_Z]
    postf("from %:% received %\n", addr, recvPort, msg);
    registerNode.value(
        objectMass:msg[7] ? params[\initMass],
        objectType: msg[2] ? "a RedObject",
        objectAge: msg[3],
        objectPos: if (msg[4..6] == [0,0,0]) {[width, height, depth].rand} {msg[4..6]},
        synType:msg[1]
    );
}, '/worldobj', schedulerAddr);

oscParmScheduler = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from %:% received %\n", addr, recvPort, msg);
    //msg.postln;
    try {params.put(msg[1], msg[2])} { |err| err.postln;}
}, '/worldpar', schedulerAddr);

oscRemoveFunc = {
    /* Remove all OSC functions. */
    oscObjScheduler.free;
    oscParmScheduler.free;
    oscSkeletonNew.free;
    oscSkeletonLost.free;
    oscSkeletonJoint.free;
};

// World.
world = RedWorld3(RedVector3D[width, height, depth], RedVector3D[0, 0, 0], 30, 0.8);

// Windows.
w = RedQWindow("tracking", Rect(800, 300, width, height)).background_(Color.black).front;
u = Window("controls", Rect(1520, 50, 160, 1050)).front;
u.view.decorator = FlowLayout(u.view.bounds);

// Visualization.
cvVisual = VLayoutView(u, 150@50).background_(panelColor);
StaticText(cvVisual, 150@20).background_(layoutHColor).font_(layoutHFont)
.string_(" Visualization ").stringColor_(layoutHFontColor);
// Visualization takes ~7% of CPU, so, it's vital to keep it off when not necessary.
// Warning! It's only about Pen drawing, RedQWindow should be animated!
CheckBox(cvVisual).font_(labelFont).string_("Display Visualization")
.value_(params.atFail(\visualize, {1}))
.action_({ |cb| params.put(\visualize, cb.value)});
CheckBox(cvVisual).font_(labelFont).string_("Display coordinates")
.value_(params.atFail(\showCoords, {0}))
.action_({ |bt| params.put(\showCoords, bt.value)});

// World params (including the Star).
cvWorld = VLayoutView(u, 150@180).background_(panelColor);
StaticText(cvWorld, 150@20).background_(layoutHColor).font_(layoutHFont)
.string_(" World parameters ").stringColor_(layoutHFontColor);
// Do objects attract each other?
CheckBox(cvWorld).font_(labelFont).string_("Objects attract each other")
.value_(params.atFail(\objAttract, {0}))
.action_({ |cb| params.put(\objAttract, cb.value)});
ezElements = ezElements ++ [
    // World gravity.
    EZNumber(cvWorld, 150@20, "World gravity", [0, 2].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.at(\world_gravity) ? 0.98)
    .action_({|ez| params.put(\world_gravity, ez.value)}),

    // World dimensions.
    EZNumber(cvWorld, 150@20, "World dimensions", [1, 10000].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .enabled_(false) // TO-DO: make it working, enable!
    .value_(params.at(\world_dim) ? 685)
    .action_({|ez| params.put(\world_dim, ez.value)}),

    // World damping.
    EZNumber(cvWorld, 150@20, "World damping", [0.01, 2.00].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.at(\world_damping) ? 0.8)
    .action_.action_({|ez| params[\world_damping] = ez.value}),

    // World max velocity.
    EZNumber(cvWorld, 150@20, "Max objects velocity", [1, 100].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.at(\world_maxVel) ? 30)
    .action_({|ez| params[\world_maxVel] = ez.value}),


    // Dark energy (repulsive force).
    EZNumber(cvWorld, 150@20, "Dark energy", [1, 1000].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.atFail(\darkEnergy, {1}))
    .action_({|ez| params.put(\darkEnergy, ez.value)}),

    // Star mass.
    EZNumber(cvWorld, 150@20, "Star mass", [5, 2147483647].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.at(\starMass) ? 5)
    .action_({|ez| params.put(\starMass, ez.value)}),

    // How much is "heavy".
    EZNumber(cvWorld, 150@20, "Heavy objects", massSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.atFail(\heavy, {5}))
    .action_({|ez| params.put(\heavy, ez.value)})
];

// Audio settings.
cvAudio = VLayoutView(u, 150@220).background_(panelColor);
StaticText(cvAudio, 150@20).background_(layoutHColor).font_(layoutHFont)
.string_(" Audio settings ").stringColor_(layoutHFontColor);
CheckBox(cvAudio).font_(labelFont).string_("Audio in")
.value_(params.atFail(\audioIn, {0}))
.action_({ |bt| params.put(\audioIn, bt.value)});
PopUpMenu(cvAudio).font_(layoutHFont).background_(Color.white)
.items_(channels).value_(params.atFail(\inbus, 30))
.action_({ |pm|
    try {synAudioIn.set(\inbus, pm.value)};
    params.put(\inbus, pm.value)
});
// Surround sound configuration.
EZListView(cvAudio, 150@90, " Spatialization engine ", items: confSurround,
    globalAction: { |l| params.put(\confSurround, confSurround.at(l.value ? 0))},
    initVal: confSurround.indexOf(params.atFail(\confSurround, 0)),
    layout: \vert, gap: 1@1)
.font_(layoutHFont);
// How deep is the aural field.
ezElements = ezElements ++ [
    EZNumber(cvAudio, 150@20, "Aural field depth", [0.5, 10, \lin, 0.5].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.atFail(\fieldDepth, {5}))
    .action_({|ez| params.put(\fieldDepth, ez.value)})
];
// Record button
Button(cvAudio).font_(labelFont)
.states_([
    ["RECORD", Color.black, Color.new(0.8,0.8,0.8)],
    ["Stop", Color.red, Color.new(0.8,0.8,0.8)]
])
.action_({ |bt|
    if (bt.value == 1) {
        Dialog.savePanel({ |path|
            var recordPath;
            s.recChannels = 8;
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
// Master control.
ezElements = ezElements ++ [
    EZSlider(cvAudio, 150@25, " master ", \amp, labelWidth:30, unitWidth:0, numberWidth:30, margin:1@1)
    .value_(params.atFail(\master, {1}))
    .action_({ |ezk| params.put(\master, ezk.value)})
];

// Particles.
cvParticles = VLayoutView(u, 150@150).background_(panelColor);
StaticText(cvParticles, 150@20).background_(layoutHColor).font_(layoutHFont)
.string_(" Particles system ").stringColor_(layoutHFontColor);
CheckBox(cvParticles).font_(labelFont).string_("Run particles")
.value_(params.atFail(\particles, {0}))
.action_({ |cb| params.put(\particles, cb.value.asInteger)});
ezElements = ezElements ++ [
    // Emit particles with frequency.
    EZNumber(cvParticles, 150@20, "Freq", [0.01, 5.00, \lin, 0.01].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.atFail(\partFreq, {0.5}))
    .action_({|ez| params.put(\partFreq, ez.value)}),

    // Particles age threshold.
    EZNumber(cvParticles, 150@20, "Age threshold", [10, 100, \lin, 5].asSpec, unitWidth:0, numberWidth:50, margin:1@1)
    .value_(params.atFail(\partAgeThresh, {50}))
    .action_({|ez| params.put(\partAgeThresh, ez.value)})
];
// Particles are being lead by
EZListView(cvParticles, 150@70, " Lead by ", items: partGuideItems,
    globalAction: { |l| params.put(\partGuide, partGuideItems.at(l.value ? 0))},
    initVal: partGuideItems.indexOf(params.atFail(\partGuide, 0)),
    layout: \vert, gap: 1@1)
.font_(layoutHFont);

// Objects' controls.
cvObjCtrl = VLayoutView(u, 150@(worldCapacity * 25 + 50)).background_(panelColor);
StaticText(cvObjCtrl, 150@20).background_(layoutHColor).font_(layoutHFont)
.string_(" Objects mass control ").stringColor_(layoutHFontColor);
ezElements = ezElements ++ [
    EZSlider(cvObjCtrl, 150@25, " new ", massSpec, labelWidth:30, unitWidth:0, numberWidth:30, margin:1@1)
    .value_(params.atFail(\initMass, {3}))
    .action_({ |ez| params.put(\initMass, ez.value)});
];
// Mass control of individual objects.
// Not included to ezElements for its colorful appearance.
worldCapacity.do{ |i|
    ezkObjCtrl[i]= EZSlider(cvObjCtrl, 150@25," "++i.asString, massSpec, labelWidth:30, unitWidth:0, numberWidth:30, margin:1@1)
    .enabled_(false)
    .setColors(Color.grey(alpha:0.1), layoutHColor, objColors[i],
        Color.grey(alpha:0.1), Color.black, nil, nil, objColors[i]).font_(labelFont)
    .action_({ |ez| objects[i].mass = ez.value });
};

// SkeletonObject status.
cvSkeletonObject = VLayoutView(u, 150@40).background_(panelColor);
StaticText(cvSkeletonObject, 150@20).background_(layoutHColor).font_(layoutHFont)
.string_(" Skel monitor ").stringColor_(layoutHFontColor);
skeletonObjectText= StaticText(cvSkeletonObject, 37@15)
.string_("").font_(layoutHFont);

// Auxiliary controls.
cvAux= VLayoutView(u, 150@80).background_(panelColor);
StaticText(cvAux, 150@20).background_(layoutHColor).font_(layoutHFont)
.string_(" Auxiliary ").stringColor_(layoutHFontColor);
// Formant & saw synths ctrls (hard connected to legs).
ezElements = ezElements ++ [
    EZSlider(cvAux, 150@25, " form ", \amp, labelWidth:30, unitWidth:0, numberWidth:30, margin:1@1)
    .value_(params.at(\synthForm) ? 1)
    .action_({ |ezk| params.put(\synthForm, ezk.value) }),

    EZSlider(cvAux, 150@25, " lsaw ", \amp, labelWidth:30, unitWidth:0, numberWidth:30, margin:1@1)
    .value_(params.at(\synthSaw) ? 1)
    .action_({ |ezk| params.put(\synthSaw, ezk.value) });
];

// All EZElements must look the same.
ezElements.do{ arg elem;
    elem.setColors(Color.grey(alpha:0.1), layoutHColor, Color.white, Color.grey(alpha:0.1),
        Color.black, nil, nil, Color.black)
    .font_(labelFont)
};

// Constant objects.
// rec guide
objGuide = RedBoid(world,
    RedVector3D[width, height, depth].rand,
    RedVector3D[1,1,1],
    RedVector3D[0,0,0],
    mass:10, size:10)
.maxForce_(1).wdistance_(3.rrand(13)).wchange_(0.75).wradius_(10.rrand(50));
// Center of the World.
worldStar = RedObject(world,
    RedVector3D[height/2, width/3, depth/2],
    RedVector3D[0,0,0],
    RedVector3D[0,0,0],
    mass:params.atFail(\starMass, theHeaviest), size:10);

// World engine.
w.draw{
    if (params.atFail(\visualize, {1})) {
        // Draw the floor.
        Pen.strokeColor= Color.grey(0.5);
        Pen.strokeRect(Rect.aboutRedVector3D(RedVector[width*0.5, height*0.5, depth], width*0.5, width, height, depth));

        // Report if no forces.
        if (applyForses.booleanValue.not) {
            Pen.fillColor= Color.white;
            Pen.stringAtPoint("NO FORCES!", [width-60, height-20].asPoint);
        };

        // Show coordinates (all objects).
        if (params.at(\showCoords).booleanValue) {
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
    wind = sin(2pi * ((w.frame % (30*fps))/width));

    // World parameters.
    world.maxVel = params[\world_maxVel];
    world.damping = params[\world_damping];
    // world.dim = RedVector3D[1, 1, 1] * (params[\world_dim] ? 685);
    // World's gravity depends on the presence of skeletons.
    try {
        world.gravity = RedVector3D.newFrom( // Head's position defines vector of gravity
            skeletonObject.at(skeletonObject.keys.minItem)[2].loc/([width, height, depth])-0.5)
    } {
        world.gravity = RedVector3D[1, 1, 1] * (params.atFail(\world_gravity, {0.98}));
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
                5.do{|i| // 5 are hands, elbows and neck.
                    skeletonObject[k].put(i,
                        RedAgent(world, RedVector3D[height, width, depth].rand,
                            RedVector3D[0,0,0], RedVector3D[0,0,0],
                            params.atFail(\starMass, theHeaviest), 10
                        ).state_(Dictionary.new)
                    );
                };
                skeletonCoords[k].put(\color, Color.rand);
            };
            // Update all skeletons' locations.
            skeletonObject[k].keysValuesDo {|i, sk|
                try {
                    sk.loc = switch(i,
                        0, {RedVector3D.newFrom(v[\lHand])},
                        1, {RedVector3D.newFrom(v[\lElbow])},
                        2, {RedVector3D.newFrom(v[\neck])},
                        3, {RedVector3D.newFrom(v[\rElbow])},
                        4, {RedVector3D.newFrom(v[\rHand])}
                    );

                    // Hands must attract objects, so their mass never drop below some point.
                    sk.mass = [sk.mass, params.atFail(\starMass, {theHeaviest})].maxItem;

                    // Hands size depend on mass, but they are dencer than usual objects.
                    sk.size = sk.mass * 0.0625;
                    sk.update;
                    world.contain(sk);
                    if (params.atFail(\visualize, {1})) {
                        // Render objects.
                        Pen.fillColor = skeletonCoords[k].at(\color);
                        Pen.strokeColor = Color.blue;
                        Pen.fillOval(Rect.aboutRedObject3D(sk));
                        // Draw feet (no objects).
                        Pen.fillOval(Rect.aboutRedVector3D(v[\rFoot], v[\rFoot][2].linlin(0,height, 30,5), width, height, depth));
                        Pen.fillOval(Rect.aboutRedVector3D(v[\lFoot], v[\lFoot][2].linlin(0,height, 30,5), width, height, depth));
                    }
                }
            };

            // Synths attached to FEET are controlled
            // not by objects, but skeleton coordinates.
            try {
                posFeet[0]= Complex(
                    v[\lFoot][1].linlin(0, width, 1, -1), // y
                    v[\lFoot][0].linlin(0, height, -1, 1) // x
                );
                posFeet[1]= Complex(
                    v[\rFoot][1].linlin(0, width, 1, -1), // y
                    v[\rFoot][0].linlin(0, height, -1, 1) // x
                );
                if (synForm.isNil.not) {
                    synForm.set( // right controls \formant
                        \azimuth, posFeet[1].theta, \distance, posFeet[1].magnitude,
                        \elevation, v[\rFoot][2].linlin(0, depth, -0.5pi, 0.5pi),
                        \amp, v[\rFoot][2].clip(0.4, 0.7), \master, params[\synthForm],
                        \mod, "c"++(currFormCtl ? "").asString,
                        \depth, params.atFail(\fieldDepth, {5}));
                    synSaw.set(	// left controls \saw
                        \azimuth, posFeet[0].theta, \distance, posFeet[0].magnitude,
                        \elevation, v[\lFoot][2].linlin(0, depth, -0.5pi, 0.5pi),
                        \amp, v[\lFoot][2].clip(0.4, 0.7), \master, params[\synthSaw],
                        \mod, "c"++(currFormCtl ? "").asString,
                        \depth, params.atFail(\fieldDepth, {5}));
                };
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
        // worldStar.loc = RedVector3D[width/2, height/3, depth/3];
        if (w.mouse != RedVector2D[0, 0]) {
            try {
                worldStar.loc = [w.mouse[0]] ++ [w.mouse[1]] ++ [w.mouse.mean.round]
            } {
                worldStar.loc = RedVector3D[width/2, height/3, depth/3]
            }
        } {
            worldStar.loc = RedVector3D[width/2, height/3, depth/3]
        };
        worldStar.update;
        world.contain(worldStar);
        if (params.atFail(\visualize, {1})) {
            Pen.fillColor = Color.new(*[0.71, 0.99, 0.99] * worldStar.loc[2].linlin(0, height, 1, 0.3));
            Pen.fillOval(Rect.aboutRedObject3D(worldStar));
        }
    };

    // Do once a second to allow objects to be removed, synths relocated, etc.
    if (w.frame % fps == 0) {
        nodes.keysValuesDo { |k, v, i|

            // If there're sceletons around they control forces.
            if (skeletonObject.size > 0) {

                // Pick up the first recognized sceleton.
                m = skeletonObject[skeletonObject.keys.asArray.minItem];

                // Mass relocation:
                // If the object is heavy enough, it is a subject for the mass relocation.
                // RedObjects only, RedBoids freely float.
                if ((v[\obj].mass >= params.atFail(\heavy, {5})) &&
                    (v[\obj].asString != "a RedBoid") &&
                    (m.includes(v[\obj]).not)
                ) {
                    // Pick up a hand of the first recognized sceleton
                    // (the hand with the smallest mass is most propbable to be choosen).
                    //.pow(2) increases chances of the "lighter" hand to be picked up.
                    hand = [m[0], m[4]].wchoose([m[0].mass, m[4].mass].pow(2).reverse.normalizeSum);

                    // Add objects mass to the hand.
                    hand.mass = hand.mass + v[\obj].mass;
                    hand.state[\totalmass] = hand.mass;

                    // Remove object from the world.
                    removeObject.value(v[\obj]);

                    // Update nodes list: re-link node to a chosen hand's hash.
                    v[\obj] = hand;
                }
            }

            // WARNING!
            // Control object's age here!!!
            //
        }
    };

    nodes.keysValuesDo { |k, v, i|
        // Control synth with object position.
        pos= Complex(
            v[\obj].loc[1].linlin(0, width, 1, -1), // y
            v[\obj].loc[0].linlin(0, height, -1, 1) // x
        );
        s.sendMsg("/n_set", k,
            \azimuth, pos.theta, \distance, pos.magnitude, // Distance from the center.
            \elevation, v[\obj].loc[2].linlin(0, depth, 0.5pi, -0.5pi), // How high the object is (inverse).
            \amp, v[\obj].mass.linlin(0,11, 0.01,0.8) + (v[\obj].vel.abs.maxItem * 0.01), // The faster the louder.
            \ax, v[\obj].loc[0]/width, // WARNING: OBSOLETE! Remove this ctrl val from synths and get rid of it here!
            \velocity, v[\obj].vel.abs.maxItem,
            \master, params.atFail(\master, {1}),
            \depth, params.atFail(\fieldDepth, {5})
        )
    };

    // below, for each world object:
    // - do commom stuff (common forces, render...)

    // Render objects.
    world.objects.do { |o, i|
        if (params.atFail(\objAttract, {0}).booleanValue && (skeletonCoords.size == 0)) {
            // Everybody attracts each other, regardless of the object type or function
            // and even when the World's forces switched off. This helps keeping objects
            // in swarm, whoile at the same time slowly affects position of the Star.
            //
            // WARNING! Does this make sense when there are skeletons?
            //
            world.objects.do { |oo, j|
                if (i != j) {
                    o.addForce(o.gravityForce(oo));
                    if (o.loc.distance(oo.loc) < (o.size*2)) {
                        o.addForce(o.gravityForce(oo).neg * params.atFail(\darkEnergy, {1}));
                    }
                }
            }
        };

        // Process only synth objects (skeleton objects must always be the haviest ones).
        if ([objGuide, objAudioIn].includes(o).not && (o.mass < theHeaviest)) {
            if (objects.indexOf(o).isNil) { // Hot trash cleaner.
                world.remove(o); o.free; o = nil;
            } {
                // Control object's age!
                objectsProp[o.hash].put(\age, objectsProp[o.hash].at(\age) - (1/fps));
                if (objectsProp[o.hash].at(\age) <= 0) {
                    // Time to die.
                    removeObject.value(o)
                } {
                    // The havier the object the fatter it is, linearly.
                    o.size= o.mass * 5;

                    if (applyForses.booleanValue) {
                        // Skeleton object's contribution.
                        skeletonObject.keysValuesDo { |id, obj|
                            // Hands gravity / springs.
                            o.asString.switch(
                                "a RedBoid", {
                                    o.addForceArrive(obj[0].loc);
                                    o.addForceArrive(obj[4].loc);
                                },
                                "a RedObject", {
                                    o.addForce(o.gravityForce(obj[0]));
                                    o.addForce(o.gravityForce(obj[4]));

                                    // WARNING: OBSOLETE!
                                    // if (o.mass >= params.atFail(\heavy, {5})) {
                                    //     // Springs are being created for heavy objects.
                                    //     // Springs _tend_ to stick to the "freer" hand, i.e. the one that have objects
                                    //     // on springs, whose total mass is lighter than the other (thus the .reverse).
                                    //     // .pow(2) increases chances of the "lighter" hand to be picked up.
                                    //     hand = [obj[0], obj[4]].wchoose([
                                    //         obj[0].state.atFail(\totalmass, {0}),
                                    //         obj[4].state.atFail(\totalmass, {0})
                                    //     ].pow(2).reverse.normalizeSum);
                                    //
                                    //     if (springs.keys.includes(o.identityHash).not) {
                                    //         springs.put(o.identityHash, hand);
                                    //         hand.state[\totalmass] = hand.state.atFail(\totalmass, {0}) + o.mass;
                                    //     } {
                                    //         //Spring params: target, stiffness, damping, length.
                                    //         try {
                                    //             o.spring(springs[o.identityHash], 0.1, 0.9, 10)
                                    //         } { |err|
                                    //             ("Trying to attach a spring to the object: " ++ err).postln;
                                    //         };
                                    //     };
                                    // } { // Remove springs, if any, and take the mass off from hand.
                                    //     o.addForce(o.gravityForce(obj[0]));
                                    //     o.addForce(o.gravityForce(obj[4]));
                                    //     hand= if(springs[o.identityHash] == obj[0].identityHash, {obj[0]}, {obj[4]});
                                    //     hand.state[\totalmass]= (hand.state.atFail(\totalmass, {0}) - o.mass).max(0);
                                    //     springs.removeAt(o.identityHash);
                                    // }
                                }
                            );
                        };

                        // On the absence of skeletons place a Star in the World.
                        if(skeletonObject.size == 0, {
                            o.addForce(o.gravityForce(worldStar));
                        });

                        // The World's forces.
                        o.addForce(world.gravity);
                        o.addForce(wind);

                    };
                    o.update;
                    world.contain(o);
                };
                // Render objects.
                if (params.atFail(\visualize, {1})) {
                    // bookmark - finish idea about "shady" colors as close to the back wall of the World.
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
                    // Render springs.
                    Pen.strokeColor= Color.white;
                    springs.keysValuesDo { |obj, h|
                        //Pen.line(obj.loc.asPoint, h.loc.asPoint);
                        Pen.line(
                            planeCoords.value(o.loc, width, height, depth).asPoint,
                            planeCoords.value(h.loc, width, height, depth).asPoint
                        );
                        Pen.stroke;
                    }
                };
                // WARNING: OBSOLETE!
                // // Control object's synth.
                // if (synths.at(o.hash).isNil.not) {
                //     pos= Complex(
                //         o.loc[1].linlin(0, width, 1, -1), // y
                //         o.loc[0].linlin(0, height, -1, 1) // x
                //     );
                //     s.sendMsg("/n_set", synths.at(o.hash).asInteger,
                //         \azimuth, pos.theta, \distance, pos.magnitude, // Distance from the center.
                //         \elevation, o.loc[2].linlin(0, depth, 0.5pi, -0.5pi), // How high the object is (inverse).
                //         \amp, o.mass.linlin(0,5, 0.01,0.8) + (o.vel.abs.maxItem * 0.01), // The faster the louder.
                //         \ax, o.loc[0]/width,
                //         \velocity, o.vel.abs.maxItem,
                //         \master, params.atFail(\master, {1}),
                //         \depth, params.atFail(\fieldDepth, {5})
                //     )
                // }
            }
        }
    };

    // Guide obj and synth.
    if (objGuide.isNil.not) {
        // Guidance source (free float affected by wind only, feet, hands).
        if (applyForses.booleanValue) {
            params.at(\partGuide).switch(
                \wind, {objGuide.addForce(wind)},
                \feet, {
                    try {
                        objGuide.addForceArrive(skeletonCoords.at(skeletonCoords.keys.minItem)[[\rFoot, \lFoot].choose]);
                    };
                    objGuide.addForce(world.gravity);
                },
                \object, {
                    try {
                        skeletonObject.keysValuesDo { |id, obj|
                            objGuide.addForceArrive(obj.at(0).loc).addForceArrive(obj.at(4).loc);
                        };
                    };
                    objGuide.addForce(world.gravity);
                    objGuide.addForce(wind);
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
        if (params.atFail(\visualize, {1})) {
            try {
                Pen.fillColor = Color.white.alpha_(objGuide.loc[2].linlin(0, height, 1.0, 0.3));
                Pen.fillOval(Rect.aboutRedObject3D(objGuide));
            }
        };
        posGuide= Complex(
            objGuide.loc[1].linlin(0, width, 1, -1), // x
            objGuide.loc[0].linlin(0, height, -1, 1) // y
        );
        if (guideNodeID != 0) {
            s.sendMsg("/n_set", guideNodeID, "azimuth", posGuide.theta, "distance", posGuide.magnitude,
                "elevation", objGuide.loc[2].linlin(0, height, -0.5pi, 0.5pi), "master", params.at(\master))
        }
    };

    // Audio through object and synth.
    if (params.at(\audioIn).booleanValue) {
        if (objAudioIn.isNil) {
            objAudioIn = RedBoid(world,
                RedVector3D[width, height, depth].rand,
                RedVector3D[1,1,1],
                RedVector2D[0,0,0],
                20, 10)
            .maxForce_(1).wdistance_(3.rrand(13))
            .wchange_(0.75).wradius_(10.rrand(50));

            synAudioIn = Synth.head(groupAux,
                "audioin_1"++"_"++params.at(\confSurround).toLower,
                [\speakerAzim, speakerArr, \inbus, params.atFail(\inbus, 30)]);
        }
    } {
        objAudioIn.free; objAudioIn= nil;
        synAudioIn.free; synAudioIn= nil;
    };

    if (objAudioIn.isNil.not) {
        if (applyForses.booleanValue) {
            objAudioIn.addForce(wind);
            objAudioIn.addForce(world.gravity);
            try {
                objGuide.addForceArrive(skeletonCoords.at(skeletonCoords.keys.minItem)[[\rFoot, \lFoot].choose]);
            };
            skeletonObject.do { |obj|
                try {
                    objAudioIn.addForceArrive(obj[0].loc).addForceArrive(obj[4].loc);
                }
            }
        };
        objAudioIn.update;
        world.contain(objAudioIn);

        // Render Object Audio in.
        if (params.atFail(\visualize, {1})) {
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
        if (synAudioIn.isNil.not) {
            synAudioIn.set(
                \azimuth, posAudioIn.theta, \distance, posAudioIn.magnitude,
                \elevation, objAudioIn.loc[2].linlin(0, depth, -0.5pi, 0.5pi),
                \master, params.atFail(\master, {1}),
                \depth, params.atFail(\fieldDepth, {5})
            )
        }
    };

    // Particles.
    if (params.atFail(\particles, {0}).booleanValue) {
        // A new particle every second.
        if ((w.frame % (fps * (params.atFail(\partFreq, 0.25))).round) == 0) {
            newPart = RedParticle(world, objGuide.loc, 0, RedVector3D[2.rand2, 10.rand, 10.rand], 5, 5)
            .age_(params.atFail(\partAgeThresh, {50}) + 10.0.rand2);
            sys.add(newPart);
            partSynths.put(newPart.hash,
                Synth(\sr_dron++"_"++params.at(\confSurround).toLower,
                    [\speakerAzim, speakerArr, \busnum, 0, \bufnum, cyclicBuf.bufnum])
            )
        }
    };
    // Control Particles synths and render.
    sys.addForce(world.gravity);
    sys.update;
    sys.do{ |p|
        if(p.alive) {
            // Particles should "sprinkle" around, thus they are
            // driven not by attraction, but by repulsive force.
            skeletonObject.do { |obj|
                try {
                    newPart.addForce(newPart.gravityForce(obj[0]).neg);
                    newPart.addForce(newPart.gravityForce(obj[4]).neg);
                }
            };
            try {
                newPart.addForce(newPart.gravityForce(worldStar).neg)
            };
            posPart= Complex(
                p.loc[1].linlin(0, width, 1, -1), // y
                p.loc[0].linlin(0, height, -1, 1) // x
            );
            partSynths.at(p.hash).set( // Find corresponding synth and set params.
                \azimuth, posPart.theta,
                \distance, posPart.magnitude,
                \elevation, p.loc[2].linlin(0, depth, 0pi, 0.5pi),
                // Volume being decreased by age, increased by accel.
                \amp, (1 / 10) * (p.age / params.at(\partAgeThresh)) * (p.vel.mag / 10),
                \ax, p.loc[0]/width,
                \master, params.atFail(\master, {1}),
                \depth, params.atFail(\fieldDepth, {5})
            );
        };
        if (params.atFail(\visualize, {1})) {
            try {
                Pen.fillColor= Color.grey((p.age/(params.at(\partAgeThresh) ? 50)), 1)
                .alpha_(p.loc[2].linlin(0, height, 1.0, 0.3));
                Pen.fillOval(Rect.aboutRedObject3D(p));
            } { |err|
                err.postln;
            }
        }
    }
};
w.animate = true;

//--functions
planeCoords = { arg vector, width, height, depth, scale=1, focal=0.5;
    var x, y, z, ox, oy;
    z = (depth - vector[2] / (depth * scale)).linlin(0, 1, focal, 1);
    x = vector[0] * z;
    y = vector[1] * z;
    ox = 1 - z * (width * 0.5) + x;
    oy = 1 - z * (height * 0.5) + y;
    [ox, oy]
};

recBufStart = { arg bnum, inbus, numchannels, path, headformat= 'aiff', bitdepth= 'int16';
    var bufnum;
    bufnum= bnum ? s.bufferAllocator.alloc(1);
    s.sendMsg("/b_alloc", bufnum, 32768 * numchannels, numchannels,
        ["/b_write", bufnum, path, headformat, bitdepth, 0, 0, 1]
    );
    recSynth= Synth.tail(RootNode(Server.default), "recsyn_" ++ numchannels, [ \inbus, inbus, \bufnum, bufnum ]);
    isRecording= true; recProgress= 0;
    bufnum // returns bufnum
};

recBufStop= { arg bnum;
    try{ recSynth.free };
    s.sendMsg("/b_close", bnum, ["/b_free", bnum]);
    isRecording= false;
};

// Initializes a new object, registers its properties, controls stack index.
initObject = { arg objectMass=5, objectType="a RedObject", objectAge=inf, objectPos= nil;
    var newObject, zeroVector= RedVector3D[0,0,0];
    if(currObj == objects.size, {currObj= 0}); // Objects are in FIFO stack.
    if(objects.at(currObj).isNil.not, { // Is currObj index already occupied?
        if(objects.indexOf(nil) != nil, {currObj = objects.indexOf(nil)});
    });

    // Try to determine the initial position of the object.
    if (objectPos.isNil) {
        objectPos = RedVector3D[width, height, depth].rand;
    } {
        objectPos = RedVector3D.newFrom(objectPos);
    };
    // Create new object.
    newObject = switch(objectType.asString,
        "a RedBoid", {
            RedBoid(world, objectPos, zeroVector, zeroVector, objectMass, objectMass*5)
            .maxForce_(1).wdistance_(3.rrand(13)).wchange_(0.75).wradius_(10.rrand(50))
        },
        "a RedObject", {
            RedObject(world, objectPos, zeroVector, zeroVector, objectMass, objectMass*5)
        }
    );
    // Place new object to the stack.
    objects.put(currObj, newObject);
    objectsProp[newObject.hash]= (age: objectAge);
    // Return newly created object.
    newObject
};

// Removes object from the world.
removeObject = { arg o;
    var objInd;
    if(objects.includes(o), {
        objInd= objects.indexOf(o);
        ezkObjCtrl[objInd].enabled_(false); // Disable mass ctrl.
        if(springs.keys.includes(o.hash), {springs.removeAt(o.hash)}); // Free the springs, if any.
        if(synths.at(o.hash).isNil.not, {
            // Release corresponding synth.
            // WARNING: OBSOLETE!
            // s.sendMsg("/n_set", synths.at(o.hash), \rel, 2.0.rand, \gate, 0);
            synths.removeAt(o.hash);
            // Wipe out object properties.
            objectsProp.removeAt(o.hash);
        });
        objects[objInd]= nil;
        world.remove(o); o.free; o= nil;
    });
};

// Prepares the buffer and starts the synth.
startSynth = { arg synType='sr_silencio', updateBuf=false, bus=0, amp=1, gate=1;
    var loadSynth, buff, nodeID;

    // Creates a new object's synth.
    loadSynth = { |bufnum|
        synths.put(objects[currObj].hash, nodeID);
        s.sendMsg("/s_new", synType ++ '_' ++ params.at(\confSurround).toLower,
            synths.at(objects[currObj].hash), 0, groupWorldId,
            \busnum, bus, \bufnum, bufnum, \gate, gate
        )
    };

    nodeID = s.nextNodeID;
    recBufStop.value(currBufnum); // stop recording
    if(updateBuf, { // load buffer
        buff = Buffer.read(s, currFilename);
        loadBufRout = Task({
            inf.do({ |j|
                if(buff.numChannels != nil, {
                    recProgress = 0;
                    loadSynth.value(buff.bufnum);
                    loadBufRout.stop;
                });
                0.01.wait;
            });
        }).start;
        }, {
            loadSynth.value(cyclicBuf.bufnum);
    });
    synGuide = nil; // to prevent msg FAILURE /n_set Node not found
    nodeID // Return node ID of newly created synth
};

// Releases the synth under the given Node ID.
releaseSynth = { arg nodeID, releaseTime=2.0;
    s.sendMsg("/n_set", nodeID,
        \rel, releaseTime + releaseTime.asFloat.rand2, \gate, 0
    );
};

// Registers in `nodes` a synth's node ID and all corresponding info:
// controlling object along with its age and number.
registerNode = { arg objectMass=5, objectType="a RedObject", objectAge=inf, objectPos= nil,
                     synType='sr_silencio', updateBuf=false, bus=0, amp=1, gate=1;
    var obj, nodeID;
    // Create new object.
    obj = initObject.value(objectMass, objectType, objectAge, objectPos);
    // Create a Node on server with synth.
    nodeID = startSynth.value(synType, updateBuf, bus, amp, gate);
    // Register the node in the dict.
    nodes[nodeID] = (obj: obj, age: objectAge, num: currObj);
    // Increase stack index.
    currObj = currObj + 1;
    // Return the dict.
    nodes[nodeID]
};

// Unregisters node.
unRegisterNode = { arg nodeID;
    if (nodes[nodeID].isNil.not) {
        // Remove the object from the Word or make it lighter.
        nodes[nodeID][\obj].asString.switch(
            "a RedBoid", { // Boid floating.
                removeObject.value(nodes[nodeID][\obj])
            },
            "a RedObject", { // Boid floating.
                removeObject.value(nodes[nodeID][\obj])
            },
            "a RedAgent", { // One of sceleton's hands.
                nodes[nodeID][\obj].mass = nodes[nodeID][\obj].mass - params.atFail(\heavy, {5})
            }
        );
        // Release corresponding synth.
        releaseSynth.value(nodeID);
        // Un-register node.
        nodes.removeAt(nodeID)
    }
};

startFeetSynths= { |gate, tFormAttRel, tSawAttRel|
    // synths controlled by feet enter slowly and remain quiet
    // Warning! master volume is separate from the rest synths master
    if(gate != 0, {
        if(synForm == nil, {
            synForm= Synth.head(groupWorldId, "sr_form" ++ '_' ++ params.at(\confSurround).toLower,
                [ \att, tFormAttRel, \amp, 0.4, \master, params[\synthForm],
                    \azimuth, pi.bilinrand, \spread, 10.rrand(50), \mod, "c" ]);
            synSaw= Synth.head(groupWorldId, "sr_lsaw" ++ '_' ++ params.at(\confSurround).toLower,
                [ \att, tSawAttRel, \amp, 0.4, \master, params[\synthSaw],
                    \azimuth, pi.bilinrand, \spread, 10.rrand(50), \mod, "c" ]);
            synthCtrlArgs.size.do({ |i|
                synthCtrl[i]= s.nextNodeID;
                s.sendBundle(0.1, ["/s_new", synthCtrlArgs[i][0].asString, synthCtrl[i]],
                    ["/n_set", synthCtrl[i], "outbus", synthCtrlArgs[i][1]]);
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
fillStream= { |curr|
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

runTask1= { |on|
    if(on.booleanValue, {
        fillStream.value(0); // create the stream
        {
            streamList[0].do{ |val|
                var dur;
                //val.postln;
                synForm.set(\mnote, val.midicps);
                synSaw.set(\mnote, (val * 0.2).midicps, \mod, val.linlin(0,32, 0, -1));
                dur= if(val < 18, {0.25}, {2.0.rand});
                dur.wait;
            }
        }.fork(TempoClock());
        },
        {
            streamList[0].stop; streamList[0]= nil;
    });
};

runTask2= { |on|
    if(on.booleanValue, {
        fillStream.value(0); // create the stream
        {
            streamList[0].do{ |val|
                var dur;
                //val.postln;
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
        },
        {
            streamList[0].stop; streamList[0]= nil;
    });
};

//--keyboard control
w.view.keyUpAction= { arg view, char, modifiers, unicode, keycode;
    var objDict, currIndex;
    case
    {keyObjType.includes(keycode)} { // stop rec, create obj, etc.
        if([0, 256].includes(modifiers), {
            if(isRecording, { // only if recording is on
                objDict = registerNode.value(
                    objectMass:params[\initMass],
                    objectType:keyObjSynth.matchAt(keycode)[0],
                    synType:keyObjSynth.matchAt(keycode)[1],
                    updateBuf:(recProgress > 30);
                );
                // Enable interface for mass control and set the label.
                currIndex = if (currObj > 0) {currObj-1} {9};
                ezkObjCtrl[currIndex].enabled_(true).value = params[\initMass];
                ezkObjCtrl[currIndex].set(
                    currIndex.asString++" "++keyObjSynth.matchAt(keycode)[1].asString.split($_).at(1)
                );
            })
        });
    }
    {keycode == 1} { // S - release \noisy
        if([0, 256].includes(modifiers),{ // no modifiers
            if(guideNodeID != 0, {s.sendMsg("/n_set", guideNodeID, "gate", 0, "rel", 2.0.rand); guideNodeID= 0;});
        });
    };
};

w.view.keyDownAction= {arg view, char, modifiers, unicode, keycode;
    var checkRout;
    //[char, modifiers, unicode, keycode].postln;
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
        if([0, 256].includes(modifiers), {
            nodes.keys.do { |id| unRegisterNode.value(id)};
        });
    }
    {keycode == 45} { a.setn(\freq, [700, 705, 890]); }

    // bookmark
    {keycode == 8} {  // C -
        synths.keys.do{ |k|
            s.sendMsg("/n_setn", synths[k].asInteger, \scale, 7, 0,1,3,5,7,8,10);
        }
    }
    {keycode == 9} { // V - remove all forces
        if( [0, 256].includes(modifiers), {applyForses= (1 - applyForses).abs});
    }
    {keycode == 6} { // Z - info
        if( [0, 256].includes(modifiers), {
            "\nparams:\n------".postln;
            params.order.do{ |k| postf("%: %\n", k, params[k])};
            "\ndata containers:\n------".postln;
            postf("skeleton objects: %\n\nworld.objects (%): %\n\nobjects: %\n\nobjects Properties: %\n\nnodes: %\n\nsynths: %\n\nparticle system: %\n\nparticle synths: %\n\nsprings: %\n\ntracking window: left %, top %, width %, height %\ncontrol window: left %, top %, width %, height %\n",
                skeletonObject, world.objects.size,
                world.objects, objects, objectsProp, nodes, synths,
                sys.objects, partSynths, springs,
                w.bounds.left, w.bounds.top, w.bounds.width, w.bounds.height,
                u.bounds.left, u.bounds.top, u.bounds.width, u.bounds.height);
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
    {keycode == 0} { // A - trigger \ev_start
        if( [0, 256].includes(modifiers), {
            Synth.head(groupAux, \ev_start, [ // single blip
                \speakerAzim, speakerArr, \note, 10.rrand(80), \azimuth, 180.bilinrand, \spread, 10.rrand(50)
            ]);
        });
    }
    {keycode == 123} { //[<-] prev ctrl for synSaw
        if(currSawCtl == nil, {
            currSawCtl= synthCtrlArgs.size-1
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
                if(currSawCtl == synthCtrlArgs.size, {currSawCtl= nil});
        });
    }
    {keycode == 125} { // [down] next ctrl for synForm
        if(currFormCtl == nil, {
            currFormCtl= 0
            },
            {
                currFormCtl= currFormCtl+1;
                if(currFormCtl == synthCtrlArgs.size, {currFormCtl= nil});
        });
    }
    {keycode == 126} { // [up] prev ctrl for synForm
        if(currFormCtl == nil, {
            currFormCtl= synthCtrlArgs.size-1
            },
            {
                currFormCtl= currFormCtl-1;
                if(currFormCtl < 0, {currFormCtl= nil});
        });
    }
    {keycode == 51} { // [return] - delete last created object
        if ([0, 256].includes(modifiers)) {
            var currIndex = if (currObj > 0) {currObj-1} {9};
            nodes.keysValuesDo { |k, v|
                if (nodes[k][\num] == currIndex) {unRegisterNode.value(k)}
            }
        }
    }
    {keyObjType.includes(keycode)} { // start rec
        if( [0, 256].includes(modifiers), {
            if(isRecording.not, { // only if there's no current rec
                currFilename= soundsDir++"kin_"++Date.getDate.stamp.asString++".aif";
                currBufnum= recBufStart.value(inbus: inbus, numchannels: 1, path: currFilename);
            })
        });
    }
    {keyObj.includes(keycode)} { // delete object with given index
        if ([0, 256].includes(modifiers)) {
            nodes.keysValuesDo { |k, v|
                if (nodes[k][\num] == keyObj.indexOf(keycode)) {unRegisterNode.value(k)}
            }
        }
    }
};

// Shutting down.
shutDown = {
    // Clean OSP responders.
    oscRemoveFunc.value();
    // Free buffers.
    cyclicBuf.free;
    cyclicSynth.free;
    speakerBuff.free;
    // Release objects and particles synths.
    synths.keys.do { |k| s.sendMsg("/n_free", synths[k])};
    partSynths.keys.do { |k| partSynths[k].free};
    // Release specific synths.
    synAudioIn.free; synForm.free; synSaw.free;
    // Close windows.
    if (w.isClosed.not) {w.close};
    if (u.isClosed.not) {u.close};
    // Write params into file.
    try {
        paramFile= File.new("preferences/knparams.dk", "w");
        paramFile.write(params.asCompileString);
        paramFile.close;
    } {
        "WARNING! Cannot write params file!".postln;
    };
    "Good bye...".postln;
};
u.onClose = shutDown;
CmdPeriod.doOnce({shutDown.value()});

// ````````````````````````````````````````````````
// 						SYNTHS
//
//
// ================================================
//
// 					   Universal
//
// ================================================
// mono recording synth
SynthDef(\recsyn_1, { arg inbus, bufnum= 0, amp= 1;
    DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).send(s);

// universal synth for recording into buffer
SynthDef( \syninbuff, {
    arg bufnum, busnum = 0, volIn = 0.8, loop= 1, dur= 1, gate= 0;
    RecordBuf.ar(
        InFeedback.ar(busnum)
        * EnvGen.kr(
            Env.linen(0.1, dur-0.2, 0.1, volIn, \welch),
            gate: Impulse.kr(gate.reciprocal)
        ),
        bufnum, 0, volIn, 0, 1, loop, 1
    ); // envelope trigger doesn't work!!!
}).send(s);

// background pulse (can only be sent to audio in).
SynthDef(\sr_bg_pulse, {
    arg bufnum=0, busnum=0, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
    freq=4;
    var in, out;
    in = Decay2.ar(
        Impulse.ar(
            TIRand.kr(freq*0.5, freq*2, Dust2.kr(0.2)).round(4),
            0, LFSaw.kr(0.3, 0, -0.3, 0.3)),
        0.001, 0.3, Mix.ar(Pulse.ar([80,81], 0.3))) * amp * master;
    out = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    Out.ar(busnum, out)
}).send(s);

// ================================================
//
// 					   Ambisonic 2
//
// ================================================

// audio in (Ambisonic 2)
SynthDef(\audioin_1_ambisonic2, {
    arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, dl, env, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    env= EnvGen.kr(Env.asr(att, master, rel, [crva, crvr]), gate: gate, doneAction: 2);
    dl= DelayL.ar(InFeedback.ar(inbus, 1), 110/344, distance/3.44);
    in= RLPF.ar(
        FreeVerb.ar(
            InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(outbus, out)
    }
).send(s);

// buffer player (Ambisonic 2)
SynthDef(\sr_play_ambisonic2, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=0.5, rel= 1, gate=1, done= 2,
    azimuth=0, elevation=0, distance=1, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var env, signal, in, out, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
    in= PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2) * env;
    signal= RLPF.ar(
        FreeVerb.ar(
            in,
            distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
        ),
        distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).send(s);

// == GRANULAR SYNTHS
// "regular" granulating (Ambisonic 2)
SynthDef( \sr_regu_ambisonic2, { // regular
    arg bufnum= 0, busnum= 0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rate=1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
    dur= 4 / trate;
    clk= Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(azimuth));
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos,
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).send(s);

// "drone" (Ambisonic 2)
SynthDef( \sr_dron_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rate=1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
    trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur= 12 / trate;
    clk= Impulse.kr(trate);
    pos= ax*BufDur.kr(bufnum);
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos + TRand.kr(0, 0.01, clk),
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000,500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).send(s);

// "gusts of wind" (Ambisonic 2)
SynthDef( \sr_gust_ambisonic2, {
    arg bufnum= 0, busnum= 0, ax=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, d, zz, signal, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    pos= round((distance*0.19)+0.1, 0.01);
    trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
    clk= Impulse.ar(trate);
    d= {Dwhite(0.1, 0.2, 1)};
    zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).send(s);

// "slicing" (Ambisonic 2)
SynthDef( \sr_slid_ambisonic2, {
    arg bufnum= 0, busnum= 0, ax=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
    trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
    dur= 8 / trate;
    clk= Dust.kr(trate);
    pos= ax * BufDur.kr(bufnum);
    rateratio= (2 ** WhiteNoise.kr(2)) * rate;
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rateratio,
        centerPos: pos,
        dur: dur,
        amp: amp * rateratio.linlin(0,4, 1,0.5)
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
        distance.linlin(0,1.41, 10000,500), 0.5)
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).send(s);

// looper (Ambisonic 2)
SynthDef(\sr_loop_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, signal, startPos=0.0, rate=1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi,0.5pi, 0.1,1.9);
    in = PlayBuf.ar(
        1,
        bufnum,
        rate*BufRateScale.kr(bufnum),
        Impulse.ar(BufDur.kr(bufnum).reciprocal),
        BufFrames.ir(bufnum)*startPos
    )
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, amp);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out)
}).send(s);

// == ELECTRONIC SYNTHS
// doors (Ambisonic 2)
SynthDef(\sr_doors_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var freq, in, out, signal, grav, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    freq= 1/(2..5);
    grav= 7-(1/freq);
    in= GVerb.ar(
        Ball.ar(
            LPF.ar(Impulse.ar(freq), 500),
            grav, 1e-5,
            LFNoise2.kr(freq/5,2e-4,12e-4))/2,
        5, 0.5, 0.9, mul:5.3);
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= PitchShift.ar(in, 0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out)
}).send(s);

// probe (Ambisonic 2)
SynthDef(\sr_prob_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance= 1, velocity=10, depth=5;
    var	dtl=0.01, dtr=0.05;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, fbase, scale, signal, startPos=0.0, rate=1, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= velocity.linlin(1,30, 0.5, 3) * exprand(3,8);
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 10, 12, 19]);
    fbase= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi,0.5pi, 15,0), 24, 1, 17).midicps;
    in = LPZ2.ar(
        LFPulse.ar(
            fbase, 2pi.rand, 0.1,
            (
                Mix.ar(SinOsc.ar(rate * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand])).abs
                * (amp*0.2))
        )
    );
    2.do({ in= AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2); });
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
}).send(s);

// cmb (Ambisonic 2)
SynthDef(\sr_cmb_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
    delayL= elevation.linlin(-0.5pi, 0.5pi, 0.01, 0.05);
    delayR= ax.linlin(0,1, 0.01, 0.05);
    mix= Klank.ar(
        `[Array.fill(n, {exprand(1.0,20.0)}),
            nil,
            Array.fill(n, {0.2.rand})
        ],
        Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
    ).fold2(0.2).cubed * 12;
    mix= Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
    in= mix.distort * 0.5;
    6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
    in= Mix.ar(LeakDC.ar(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.4
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out)
}).send(s);

// starfield (Ambisonic 2)
SynthDef(\sr_star_ambisonic2, {
    arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, frate=1, modf=1,
    gate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
    dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
    q= dir[1].atan2(dir[0])+pi;
    a= frate.linlin(0,2, 2pi, 0);
    b= dir[1].hypot(dir[0])*400+200;
    c= modf.linlin(-440,440, 0, 50);
    in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
    in= Limiter.ar(Mix(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(FreeVerb.ar(in), distance.linlin(0,1.41, 500, 10000), 0.5);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out)
}).send(s);

// "melodic" (Ambisonic 2)
SynthDef( \sr_melo_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v, // !!
    speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1,
    freq, scale, dist,
    in, out, signal;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 10, 12, 19]);
    freq= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 17).midicps;
    // Synthesis.
    in = RLPF.ar(LFSaw.ar(freq)
        + Impulse.ar(XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand)
        + WhiteNoise.ar(0.8.rand, mul:0.2),
        LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp*0.15
    );
    in = [in, DelayN.ar(in, 0.04, 0.04)];
    4.do({in = AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4)});
    in = Mix.ar(LeakDC.ar(in));
    in = RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2),
        distance.linlin(0,1.41, 10000, 500), 0.5
    );
    //Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out)
}).send(s);

// ringz (Ambisonic 2)
SynthDef(\sr_ringz_ambisonic2, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance= 1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v, // !!
    speakerAzim=[-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev=0, speakerDist=[3, 3, 3, 3], maxDist=3, scaleFlag=1,
    fbase, phase, cutoff, dist,
    in, out, signal;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    fbase = distance.linexp(0,1.41, 10,40);
    phase = velocity**3;
    cutoff = distance.linexp(0,1.41, 200,2000);
    // Synthesis.
    in = Ringz.ar(SinOsc.ar(fbase, phase.lag(0.01), amp*0.02), cutoff, 0.01).softclip;
    5.do({in});
    //Envelope.
    signal = Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out = FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
}).send(s);

// pulse (Ambisonic 2)
SynthDef(\sr_pulse_ambisonic2, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1,
    att=0.1, rel=1, crva= -3, crvr=3, azimuth=0,
    elevation=0, distance= 1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1,
    scale, fbase, cutoff, rq, dist,
    in, out, signal;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10, 12]);
    cutoff = distance.linexp(0.0,1.41, 200,10000);
    rq = distance.linlin(0.0,1.41, 0.5,1);
    fbase = SelectX.kr(BinaryOpUGen('<', elevation.abs, 0.2pi) * 2,
        [
            DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.abs.linlin(0.2pi,0.5pi, 15,0), 12, 1, 24).midicps,
            velocity.linlin(1,30, 1,150)
        ]
    );
    // Synthesis (number of harmonics depends on the distance).
    in = Blip.ar(SinOsc.kr(0.5, 0, LFDNoise1.kr(1.5), fbase), fbase.round(10).clip(100, 200), 0.2);
    in = RLPF.ar(RLPF.ar(Mix.fill(10, in), cutoff, rq, amp).softclip, cutoff, rq, amp).softclip;
    //Envelope.
    signal= in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
}).send(s);

// analog (Ambisonic 2)
SynthDef(\sr_analog_ambisonic2, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1,
    att=0.1, rel=1, crva= -3, crvr=3, azimuth=0,
    elevation=0, distance= 1, velocity=10,
    offset=36, depth=5;
    var w, x, y, z, r, s, t, u, v,
    speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1,
    scale, note, cutoff, rq, dist, elevThresh=0.4pi,
    in, out, signal;
    // Conversion.
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    cutoff = LFNoise1.ar(TRand.kr(0.1, 1, Delay2.kr(Dust.kr(1))), 34, 90).midicps; // (200..10000)
    rq = distance.linlin(0.0,1.41, 0.2,1.0);
    scale = NamedControl.kr(\scale, FloatArray[0, 3, 7, 10]);
    note = SelectX.kr(BinaryOpUGen('<', elevation, 0.4pi) * 2,
        [
            // melodic above threshold 0.2pi
            DegreeToKey.kr(
                LocalBuf.newFrom(scale),
                (elevation-elevThresh).linlin(0, 0.1pi, 0, 12),
                12, 1, offset
            ),
            // bottom to middle changing continuously
            elevation.linlin(-0.5pi, elevThresh, (offset-3), offset)
        ]
    );
    // Synthesis.
    in = Mix.fill(8, {LFSaw.ar((note + 0.1.rand2).midicps, mul:0.05)});
    in = RLPF.ar(RLPF.ar(in, cutoff, rq).softclip, cutoff, rq, amp).softclip;
    // Envelope.
    signal = in * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    // Spatializing.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
}).send(s);

// tube (Ambisonic 2)
SynthDef(\sr_tube_ambisonic2, {
    arg bufnum=0, busnum=0, ax=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var scale, freq, in, out, signal, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    scale = FloatArray[0, 2, 3.2, 5, 7, 9, 10];
    freq= (DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 60) + LFNoise1.kr([3,3], 0.04)).midicps;
    in = NTube.ar(LFPulse.ar(freq) + GrayNoise.ar(), `[0.97,1.0,1.0,1.0,0.97],`[0.5,1.0,0.2],`[0.01,0.02,0.01,0.005]) * 0.1;
    in = in * velocity.linlin(1,30, 0,1) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= PitchShift.ar(in, 0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out)
}).send(s);

// formants (Ambisonic 2)
SynthDef(\sr_form_ambisonic2, {
    arg busnum= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, master=1,
    azimuth= 0, elevation= 0, distance= 1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var env, in, out, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
    in= env * RLPF.ar(
        in: LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -40, 40)),
        freq: LinLin.kr(mod, -1, 1, 80, 30).midicps,
        rq: 0.1,
        mul: ( amp * mod.linlin(-1,1, 0.01, 0.1) ).clip(0.01, 0.99) * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(busnum, out);
    }
).send(s);

SynthDef(\sr_lsaw_ambisonic2, {
    arg outbus= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, master=1,
    azimuth= 0, elevation= 0, distance= 1, velocity=10, depth=5;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var env, in, out, dist;
    dist = distance.linlin(0.0,1.41, 0.5,depth);
    env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
    in= env * LFSaw.ar(
        freq: mnote + freqBase + mod.linlin(-1,1, -50, 0),
        mul: ( amp * mod.linlin(-1,1, 0.01, 0.25) ).clip(0.01, 0.99) * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.stereo(w, z);
    Out.ar(outbus, out);
    }
).send(s);

// ================================================
//
// 					   Ambisonic 4
//
// ================================================

// audio in (Ambisonic 4)
SynthDef(\audioin_1_ambisonic4, {
    arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, dl, env, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr(Env.asr(att, master, rel, [crva, crvr]), gate: gate, doneAction: 2);
    dl= DelayL.ar(InFeedback.ar(inbus, 1), 110/344, distance/3.44);
    in= RLPF.ar(
        FreeVerb.ar(
            InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out)
    }
).send(s);

// buffer player (Ambisonic 4)
SynthDef(\sr_play_ambisonic4, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=0.5, rel= 1, gate=1, done= 2,
    azimuth=0, elevation=0, distance=1;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var env, signal, in, out, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
    in= PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2) * env;
    signal= RLPF.ar(
        FreeVerb.ar(
            in,
            distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
        ),
        distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// == GRANULAR SYNTHS
// "regular" granulating (Ambisonic 4)
SynthDef( \sr_regu_ambisonic4, { // regular
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rate=1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
    dur= 4 / trate;
    clk= Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(azimuth));
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos,
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// "drone" (Ambisonic 4)
SynthDef( \sr_dron_ambisonic4, {
    arg bufnum=0, busnum=0, ax=0, ay=0.5, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rate=1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
    trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur= 12 / trate;
    clk= Impulse.kr(trate);
    pos= ax*BufDur.kr(bufnum);
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos + TRand.kr(0, 0.01, clk),
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000,500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// "gusts of wind" (Ambisonic 4)
SynthDef( \sr_gust_ambisonic4, {
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, d, zz, signal, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    pos= round((distance*0.19)+0.1, 0.01);
    trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
    clk= Impulse.ar(trate);
    d= {Dwhite(0.1, 0.2, 1)};
    zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// "slicing" (Ambisonic 4)
SynthDef( \sr_slid_ambisonic4, {
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
    trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
    dur= 8 / trate;
    clk= Dust.kr(trate);
    pos= ax * BufDur.kr(bufnum);
    rateratio= (2 ** WhiteNoise.kr(2)) * rate;
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rateratio,
        centerPos: pos,
        dur: dur,
        amp: amp * rateratio.linlin(0,4, 1,0.5)
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
        distance.linlin(0,1.41, 10000,500), 0.5)
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// looper (Ambisonic 4)
SynthDef(\sr_loop_ambisonic4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, signal, startPos=0.0, rate=1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= ay.linlin(-0.5pi,0.5pi, 0.1, 1.9);
    in = PlayBuf.ar(
        1,
        bufnum,
        rate*BufRateScale.kr(bufnum),
        Impulse.ar(BufDur.kr(bufnum).reciprocal),
        BufFrames.ir(bufnum)*startPos
    )
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, amp);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

// == ELECTRONIC SYNTHS
// doors (Ambisonic 4)
SynthDef(\sr_doors_ambisonic4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var freq, in, out, signal, grav, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    freq= 1/(2..5);
    grav= 7-(1/freq);
    in= GVerb.ar(
        Ball.ar(
            LPF.ar(Impulse.ar(freq), 500),
            grav, 1e-5,
            LFNoise2.kr(freq/5,2e-4,12e-4))/2,
        5, 0.5, 0.9, mul:5.3);
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= PitchShift.ar(in, 0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

// probe (Ambisonic 4)
SynthDef(\sr_prob_ambisonic4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance= 1, velocity=10;
    var	dtl=0.01, dtr=0.05;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, fbase, scale, signal, startPos=0.0, rate=1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= velocity.linlin(1,30, 0.5, 3) * exprand(3,8);
    scale = FloatArray[0, 3, 10, 12, 19];
    fbase= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi,0.5pi, 15,0), 24, 1, 17).midicps;
    in = LPZ2.ar(
        LFPulse.ar(
            fbase, 2pi.rand, 0.1,
            (
                Mix.ar(SinOsc.ar(rate * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand])).abs
                * (amp*0.2))
        )
    );
    2.do({ in= AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2); });
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).send(s);

// cmb (Ambisonic 4)
SynthDef(\sr_cmb_ambisonic4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
    delayL= elevation.linlin(-0.5pi, 0.5pi, 0.01, 0.05);
    delayR= ax.linlin(0,1, 0.01, 0.05);
    mix= Klank.ar(
        `[Array.fill(n, {exprand(1.0,20.0)}),
            nil,
            Array.fill(n, {0.2.rand})
        ],
        Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
    ).fold2(0.2).cubed * 12;
    mix= Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
    in= mix.distort * 0.5;
    6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
    in= Mix.ar(LeakDC.ar(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.4
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

// starfield (Ambisonic 4)
SynthDef(\sr_star_ambisonic4, {
    arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, gate=1, frate=1, modf=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
    dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
    q= dir[1].atan2(dir[0])+pi;
    a= frate.linlin(0,2, 2pi, 0);
    b= dir[1].hypot(dir[0])*400+200;
    c= modf.linlin(-440,440, 0, 50);
    in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp*0.2);
    in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    signal= RLPF.ar(FreeVerb.ar(in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2), distance.linlin(0,1.41, 10000, 500), 0.5);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).send(s);

// "melodic" (Ambisonic 4)
SynthDef( \sr_melo_ambisonic4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, freq, scale, signal, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    scale = FloatArray[0, 3, 10, 12, 19];
    freq= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 17).midicps;
    in= RLPF.ar(
        LFSaw.ar(freq)
        + Impulse.ar( XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand)
        + WhiteNoise.ar(0.8.rand, mul:0.2),
        LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp*0.15
    );
    in= [in, DelayN.ar(in, 0.04, 0.04) ];
    4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
    in= Mix.ar(LeakDC.ar(in))*EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
    }
).send(s);

// ringz (Ambisonic 4)
SynthDef(\sr_ringz_ambisonic4, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance= 1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var in, out, signal;
    var fbase, phase, cutoff, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    fbase= distance.linexp(0,1.41, 10,40);
    phase= velocity*100;
    cutoff= distance.linexp(0,1.41, 200,2000);
    in=
    Ringz.ar(SinOsc.ar(fbase, phase.lag(0.01), amp*0.02), cutoff, 0.01);
    5.do({in});
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).send(s);

// formants (Ambisonic 4)
SynthDef(\sr_form_ambisonic4, {
    arg busnum= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, master=1,
    azimuth= 0, elevation= 0, distance= 1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var env, in, out, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
    in= env * RLPF.ar(
        in: LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -40, 40)),
        freq: LinLin.kr(mod, -1, 1, 80, 30).midicps,
        rq: 0.1,
        mul: ( amp * mod.linlin(-1,1, 0.01, 0.1) ).clip(0.01, 0.99) * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

SynthDef(\sr_lsaw_ambisonic4, {
    arg outbus= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, master=1,
    azimuth= 0, elevation= 0, distance= 1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
    var env, in, out, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
    in= env * LFSaw.ar(
        freq: mnote + freqBase + mod.linlin(-1,1, -50, 0),
        mul: ( amp * mod.linlin(-1,1, 0.01, 0.25) ).clip(0.01, 0.99) * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar( outbus, out );
    }
).send(s);



// ================================================
//
// 					   Ambisonic 8
//
// ================================================

// audio in (Ambisonic 8)
SynthDef(\audioin_1_ambisonic8, {
    arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var in, out, dl, env, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr(Env.asr(att, master, rel, [crva, crvr]), gate: gate, doneAction: 2);
    dl= DelayL.ar(InFeedback.ar(inbus, 1), 110/344, distance/3.44);
    in= RLPF.ar(
        FreeVerb.ar(
            InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(outbus, out)
    }
).send(s);

// buffer player (Ambisonic 8)
SynthDef(\sr_play_ambisonic8, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=0.5, rel= 1, gate=1, done= 2,
    azimuth=0, elevation=0, distance=1;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var env, signal, in, out, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
    in= PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2) * env;
    signal= RLPF.ar(
        FreeVerb.ar(
            in,
            distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
        ),
        distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// == GRANULAR SYNTHS
// "regular" granulating (Ambisonic 8)
SynthDef( \sr_regu_ambisonic8, { // regular
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rate=1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
    dur= 4 / trate;
    clk= Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(azimuth));
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos,
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// "drone" (Ambisonic 8)
SynthDef( \sr_dron_ambisonic8, {
    arg bufnum=0, busnum=0, ax=0, ay=0.5, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rate=1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
    trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur= 12 / trate;
    clk= Impulse.kr(trate);
    pos= ax*BufDur.kr(bufnum);
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos + TRand.kr(0, 0.01, clk),
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000,500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// "gusts of wind" (Ambisonic 8)
SynthDef( \sr_gust_ambisonic8, {
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, d, zz, signal, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    pos= round((distance*0.19)+0.1, 0.01);
    trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
    clk= Impulse.ar(trate);
    d= {Dwhite(0.1, 0.2, 1)};
    zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// "slicing" (Ambisonic 8)
SynthDef( \sr_slid_ambisonic8, {
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
    trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
    dur= 8 / trate;
    clk= Dust.kr(trate);
    pos= ax * BufDur.kr(bufnum);
    rateratio= (2 ** WhiteNoise.kr(2)) * rate;
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rateratio,
        centerPos: pos,
        dur: dur,
        amp: amp * rateratio.linlin(0,4, 1,0.5)
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
        distance.linlin(0,1.41, 10000,500), 0.5)
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

// looper (Ambisonic 8)
SynthDef(\sr_loop_ambisonic8, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var in, out, signal, startPos=0.0, rate=1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= ay.linlin(-0.5pi,0.5pi, 0.1, 1.9);
    in = PlayBuf.ar(
        1,
        bufnum,
        rate*BufRateScale.kr(bufnum),
        Impulse.ar(BufDur.kr(bufnum).reciprocal),
        BufFrames.ir(bufnum)*startPos
    )
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, amp);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

// == ELECTRONIC SYNTHS
// doors (Ambisonic 8)
SynthDef(\sr_doors_ambisonic8, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var freq, in, out, signal, grav, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    freq= 1/(2..5);
    grav= 7-(1/freq);
    in= GVerb.ar(
        Ball.ar(
            LPF.ar(Impulse.ar(freq), 500),
            grav, 1e-5,
            LFNoise2.kr(freq/5,2e-4,12e-4))/2,
        5, 0.5, 0.9, mul:5.3);
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= PitchShift.ar(in, 0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

// probe (Ambisonic 8)
SynthDef(\sr_prob_ambisonic8, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance= 1, velocity=10;
    var	dtl=0.01, dtr=0.05;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var in, out, fbase, scale, signal, startPos=0.0, rate=1, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= velocity.linlin(1,30, 0.5, 3) * exprand(3,8);
    scale = FloatArray[0, 3, 10, 12, 19];
    fbase= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi,0.5pi, 15,0), 24, 1, 17).midicps;
    in = LPZ2.ar(
        LFPulse.ar(
            fbase, 2pi.rand, 0.1,
            (
                Mix.ar(SinOsc.ar(rate * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand])).abs
                * (amp*0.2))
        )
    );
    2.do({ in= AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2); });
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).send(s);

// cmb (Ambisonic 8)
SynthDef(\sr_cmb_ambisonic8, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
    delayL= elevation.linlin(-0.5pi, 0.5pi, 0.01, 0.05);
    delayR= ax.linlin(0,1, 0.01, 0.05);
    mix= Klank.ar(
        `[Array.fill(n, {exprand(1.0,20.0)}),
            nil,
            Array.fill(n, {0.2.rand})
        ],
        Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
    ).fold2(0.2).cubed * 12;
    mix= Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
    in= mix.distort * 0.5;
    6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
    in= Mix.ar(LeakDC.ar(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.4
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}).send(s);

// starfield (Ambisonic 8)
SynthDef(\sr_star_ambisonic8, {
    arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, gate=1, frate=1, modf=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
    dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
    q= dir[1].atan2(dir[0])+pi;
    a= frate.linlin(0,2, 2pi, 0);
    b= dir[1].hypot(dir[0])*400+200;
    c= modf.linlin(-440,440, 0, 50);
    in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp*0.2);
    in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    signal= RLPF.ar(FreeVerb.ar(in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2), distance.linlin(0,1.41, 10000, 500), 0.5);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).send(s);

// "melodic" (Ambisonic 8)
SynthDef( \sr_melo_ambisonic8, {
    arg bufnum=0, busnum=0, ax=0, ay=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var trate, dur, pos, in, out, clk, freq, scale, signal, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    scale = FloatArray[0, 3, 10, 12, 19];
    freq= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 17).midicps;
    in= RLPF.ar(
        LFSaw.ar(freq)
        + Impulse.ar( XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand)
        + WhiteNoise.ar(0.8.rand, mul:0.2),
        LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp*0.01
    );
    in= [in, DelayN.ar(in, 0.04, 0.04) ];
    4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
    in= Mix.ar(LeakDC.ar(in))*EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out)
    }
).send(s);

// ringz (Ambisonic 8)
SynthDef(\sr_ringz_ambisonic8, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance= 1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var in, out, signal;
    var fbase, phase, cutoff, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    fbase= distance.linexp(0,1.41, 10,40);
    phase= velocity*100;
    cutoff= distance.linexp(0,1.41, 200,2000);
    in=
    Ringz.ar(SinOsc.ar(fbase, phase.lag(0.01), amp*0.02), cutoff, 0.01);
    5.do({in});
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
}).send(s);

// formants (Ambisonic 8)
SynthDef(\sr_form_ambisonic8, {
    arg busnum= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, master=1,
    azimuth= 0, elevation= 0, distance= 1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var env, in, out, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
    in= env * RLPF.ar(
        in: LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -40, 40)),
        freq: LinLin.kr(mod, -1, 1, 80, 30).midicps,
        rq: 0.1,
        mul: ( amp * mod.linlin(-1,1, 0.01, 0.1) ).clip(0.01, 0.99) * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar(busnum, out);
    }
).send(s);

SynthDef(\sr_lsaw_ambisonic8, {
    arg outbus= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, master=1,
    azimuth= 0, elevation= 0, distance= 1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= [-0.20pi, -0.5pi, -0.70pi, -pi, 0.70pi, 0.5pi, 0.20pi, 0pi], speakerElev= 0, speakerDist= [6.3, 4.7, 6, 6, 6, 4.7, 6.3, 6.3], maxDist=6.3, scaleFlag=1;
    var env, in, out, dist;
    dist= distance.linlin(0.0,1.41, 0.5, 3);
    env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
    in= env * LFSaw.ar(
        freq: mnote + freqBase + mod.linlin(-1,1, -50, 0),
        mul: ( amp * mod.linlin(-1,1, 0.01, 0.25) ).clip(0.01, 0.99) * master
    );
    #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
    out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
        azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
    Out.ar( outbus, out );
    }
).send(s);


// ================================================
//
// 						VBAP 4
//
// ================================================

// audio in (Ambisonic 8)
SynthDef(\audioin_1_vbap4, {
    arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;
    var in, out, dl, env;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //	in= RLPF.ar(InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 10000,800), 0.5) * env;
    //Conversion.
    env= EnvGen.kr(Env.asr(att, master, rel, [crva, crvr]), gate: gate, doneAction: 2);
    dl= DelayL.ar(InFeedback.ar(inbus, 1), 110/344, distance/3.44);
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in= RLPF.ar(
        FreeVerb.ar(
            InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    out= VBAP.ar(4, in, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(outbus, out)
    }
).send(s);

// buffer player (VBAP 4)
SynthDef(\sr_play_vbap4, {
    arg bufnum=0, busnum=0, amp=1, master=1, att=0.5, rel= 1, gate=1, done= 2,
    azimuth=0, elevation=0, distance=1;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var env, signal, in, out;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
    in= PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2) * env;
    signal= RLPF.ar(
        FreeVerb.ar(
            in,
            distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
        ),
        distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).send(s);

// == GRANULAR SYNTHS
// "regular" granulating (VBAP 4)
SynthDef( \sr_regu_vbap4, { // regular
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rate=1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
    dur= 4 / trate;
    clk= Dust.kr(trate);
    pos = Integrator.kr(BrownNoise.kr(azimuth));
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos,
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).send(s);

// "drone" (VBAP 4)
SynthDef( \sr_dron_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0.5, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rate=1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
    trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
    dur= 12 / trate;
    clk= Impulse.kr(trate);
    pos= ax*BufDur.kr(bufnum);
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rate,
        centerPos: pos + TRand.kr(0, 0.01, clk),
        dur: dur,
        amp: amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000,500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).send(s);

// "gusts of wind" (VBAP 4)
SynthDef( \sr_gust_vbap4, {
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=1, distance=1, velocity=10;
    var w, x, y, z, r, s, t, u, v; // !!
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, d, zz, signal;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    pos= round((distance*0.19)+0.1, 0.01);
    trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
    clk= Impulse.ar(trate);
    d= {Dwhite(0.1, 0.2, 1)};
    zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
        centerPos: Dseq(zz.dup(8), inf) / pos,
        dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
        amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(
                in, distance.clip(0.01, 0.99), distance/3.44, 0.2
            )
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    )
    * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).send(s);

// "slicing" (VBAP 4)
SynthDef( \sr_slid_vbap4, {
    arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
    trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
    dur= 8 / trate;
    clk= Dust.kr(trate);
    pos= ax * BufDur.kr(bufnum);
    rateratio= (2 ** WhiteNoise.kr(2)) * rate;
    in= TGrains.ar(
        numChannels: 2,
        trigger: clk,
        bufnum: bufnum,
        rate: BufRateScale.kr(bufnum) * rateratio,
        centerPos: pos,
        dur: dur,
        amp: amp * rateratio.linlin(0,4, 1,0.5)
    );
    signal= RLPF.ar(
        Mix.new(
            FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
        distance.linlin(0,1.41, 10000,500), 0.5)
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
    }
).send(s);

// looper (VBAP 4)
SynthDef(\sr_loop_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal, startPos=0.0, rate=1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    rate= ay.linlin(-0.5pi,0.5pi, 0.1, 1.9);
    in = PlayBuf.ar(
        1,
        bufnum,
        rate*BufRateScale.kr(bufnum),
        Impulse.ar(BufDur.kr(bufnum).reciprocal),
        BufFrames.ir(bufnum)*startPos
    )
    * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(
            FreeVerb.ar(
                in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
            ), 110/344, distance/3.44
        ), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
}).send(s);

// == ELECTRONIC SYNTHS
// doors (VBAP 4)
SynthDef(\sr_doors_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var freq, in, out, signal, grav;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    freq= 1/(2..5);
    grav= 7-(1/freq);
    in= GVerb.ar(
        Ball.ar(
            LPF.ar(Impulse.ar(freq), 500),
            grav, 1e-5,
            LFNoise2.kr(freq/5,2e-4,12e-4))/2,
        5, 0.5, 0.9);
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= PitchShift.ar(
        RLPF.ar(
            DelayL.ar(
                FreeVerb.ar(
                    in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
                ), 110/344, distance/3.44
            ), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
        ),
        0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out)
}).send(s);

// probe (VBAP4)
SynthDef(\sr_prob_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var dtl=0.01, dtr=0.05;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, scale, fbase, signal, startPos=0.0, rate=1;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    rate= velocity.linlin(1,30, 0.5, 3) * exprand(3,8);
    scale = FloatArray[0, 3, 10, 12, 19];
    fbase= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi,0.5pi, 15,0), 24, 1, 17).midicps;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in = LPZ2.ar(
        LFPulse.ar(
            fbase, 2pi.rand, 0.1,
            (
                Mix.ar(SinOsc.ar(rate * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand], 0.04)).max(0)
                * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand])).abs
                * (amp*0.2))
        )
    );
    2.do({ in= AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2); });
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(in, 30/344, distance.linlin(0.0,1.41, 30,75)/344), //~30kph
        distance.linlin(0.0,1.41, 10000,500).clip(500,10000), 0.5, mul: amp * master
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
}).send(s);

// cmb (VBAP 4)
SynthDef(\sr_cmb_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
    pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
    delayL= elevation.linlin(-0.5pi, 0.5pi, 0.01, 0.05);
    delayR= ax.linlin(0,1, 0.01, 0.05);
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    mix= Klank.ar(
        `[Array.fill(n, {exprand(1.0,20.0)}),
            nil,
            Array.fill(n, {0.2.rand})
        ],
        Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
    ).fold2(0.2).cubed * 12;
    mix= Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
    in= mix.distort * 0.5;
    6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
    in= Mix.ar(LeakDC.ar(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.3
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out)
}).send(s);

// starfield (VBAP 4)
SynthDef(\sr_star_vbap4, {
    arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, gate=1, frate=1, modf=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
    dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
    q= dir[1].atan2(dir[0])+pi;
    a= frate.linlin(0,2, 2pi, 0);
    b= dir[1].hypot(dir[0])*400+200;
    c= modf.linlin(-440,440, 0, 50);
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
    in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
    signal= RLPF.ar(FreeVerb.ar(in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2), distance.linlin(0,1.41, 10000, 500), 0.5);
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).send(s);

// "melodic" (VBAP 4)
SynthDef( \sr_melo_vbap4, {
    arg bufnum=0, busnum=0, ax=0, ay=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance=1, velocity=10;
    var speakerAzim= #[-45, -140, 140, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, freq, scale, signal;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    scale = FloatArray[0, 3, 10, 12, 19];
    freq= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 17).midicps;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    in= RLPF.ar(
        LFSaw.ar(freq)
        + Impulse.ar( XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand)
        + WhiteNoise.ar(0.8.rand, mul:ay.linlin(0,1,1,0.1)),
        LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp*0.02
    );
    in= [in, DelayN.ar(in, 0.04, 0.04) ];
    4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
    in= Mix.ar(LeakDC.ar(in))*EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
    signal= RLPF.ar(
        FreeVerb.ar(
            in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
        ), distance.linlin(0,1.41, 10000, 500), 0.5
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out)
    }
).send(s);

// ringz (VBAP4)
SynthDef(\sr_ringz_vbap4, {
    arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
    azimuth=0, elevation=0, distance= 1, velocity=10;
    var speakerAzim= #[-45, -140, 140, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal;
    var fbase, phase, cutoff;
    //Speakers config.
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    //Conversion.
    azimuth= azimuth.linlin(-pi,pi, -180,180);
    elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
    spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
    fbase= distance.linexp(0,1.41, 10,40);
    phase= velocity*100;
    cutoff= distance.linexp(0,1.41, 200,2000);
    in=
    Ringz.ar(SinOsc.ar(fbase, phase.lag(0.01), amp*0.02), cutoff, 0.01);
    5.do({in});
    in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
    signal= RLPF.ar(
        DelayL.ar(in, 30/344, distance.linlin(0.0,1.41, 30,75)/344), //~30kph
        distance.linlin(0.0,1.41, 10000,500).clip(500,10000), 0.5, mul: amp * master
    );
    out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
    Out.ar(busnum, out);
}).send(s);
)