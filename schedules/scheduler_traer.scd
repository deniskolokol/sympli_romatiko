(
var thePiece; // main dictionary with the sequence of scheduled tasks
var samplesDir;
var surround, mainInput, mainOutput; // audio setup for the current piece
var inbus=12, outbus=0, audioThruBus=[21, 22]; // to main output
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

// fill buff with sample connected to guide object
guideBuff = Buffer.readChannel(s,
    PathName(samplesDir ++ "drumguide.wav").fullPath,
    // PathName("~/Music/Sympli_Romatiko/solo/Audio/drumguide.wav").fullPath,
    channels: [0]);

samples = List.new; // fill samples
[
    "drumloop00.wav", "drumloop01.wav", "drumloop02.wav", "drumloop03.wav", "drumloop04.wav"
].do { |f, i|
    samples.add(Buffer.readChannel(s, PathName(samplesDir ++ f).fullPath, channels: [0]));
};

voices = List.new; // fill voices
[
    "marcin00.wav", "agata00.wav", "marcin01.wav", "agata01.wav", "marcin02.wav", "agata02.wav",
    "marcin03.wav", "agata03.wav", "marcin04.wav", "agata04.wav", "marcin05.wav", "agata05.wav",
    "marcin06.wav", "agata06.wav", "marcin07.wav", "agata07.wav", "marcin08.wav", "agata08.wav",
    "marcin09.wav", "agata09.wav", "marcin10.wav", "agata10.wav", "marcin11.wav", "agata11.wav",
    "marcin12.wav", "agata12.wav", "marcin13.wav", "agata13.wav", "marcin14.wav", "agata14.wav",
    "marcin15.wav", "marcin16.wav"
].do { |f, i|
    voices.add(Buffer.readChannel(s, PathName(samplesDir ++ f).fullPath, channels: [0]));
};

scales = List.new; // fill scales
[
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 1, 3, 7, 8], // the rest are specific to thePiece's parts
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
    42, \sr__e__analog, // \ (the answer to the ultimate question ))
    1,  \sr__g__reg,    // s
    2,  \sr__g__drone,  // d
    3,  \sr__g__gust,   // f
    5,  \sr__g__slic,   // g
    4,  \sr__g__loop,   // h
    38, \sr__g__scratch,// j
    40, \sr__g__unst,   // k
    37, \sr__g__chunk,  // l
    41, \sr__e__therem, // ;
];
synthNames = Dictionary.newFrom(trigSynth);
// TO-DO: names should be obtained automatically
keyNames = (12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y",
    32: "u", 34: "i", 31: "o", 35: "p", 33: "[", 30: "]", 42: "\\",
    1:  "s", 2:  "d", 3:  "f", 5:  "g", 4:  "h", 38: "j", 40: "k",
    37: "l", 41: ";");

surround = "ambisonic2";
mainOutput = 0;
mainInput = 20;
worldSize = 800;

physics = (
    drag: (label: "drag", minval: 0.000, maxval: 0.500, step: 0.001, default: 0.001, midicc: 24),
    repulsion: (label: "repulsion", minval: 1, maxval: 100, step: 5, default: 100, midicc: 25),
    starMass: (label: "star mass", minval: 0.1, maxval: 5, step: 0.1, default: 1, midicc: 26),
    gravX: (label: "grav X", minval: -2.1, maxval: 2.0, default: 0, midicc: 27),
    gravY: (label: "grav Y", minval: -2.1, maxval: 2.0, default: 0, midicc: 28),
    gravZ: (label: "grav Z", minval: -2.1, maxval: 2.0, default: 0, midicc: 29),
    springRestLen: (label: "rest len", minval: 1, maxval: 15, step: 1, default: 2, midicc: 31),
    springStrength: (label: "strength", minval: 0.1, maxval: 2, default: 1, midicc: 32),
    springDamp: (label: "damp", minval: 0.1, maxval: 2, default: 2, midicc: 33),
    particles: (label: "particl", default: false, midinote: 44),
    mutualAttraction: (label: "mutual", default: true, midinote: 45)
);
physics.keys.do { |key|
    physics[key][\gui] = nil; // GUI element that controls the parameter
};
dummyParam = (param: "<NONE>", minval: 0, maxval: 1, step: 0.01, default: 0);
valAsApec = { |param|
    var spec;
    param.atFail(\spec, {[
            param.atFail(\minval, {0}), param.atFail(\maxval, {1}),
            param.atFail(\warp, {\lin}),
            param.atFail(\step, {0}),
            param.atFail(\default, {0})
        ]}
    ).asSpec
};

thePiece = (
    0: [
        (message: \action,  params: [\action, \remove, \all],
            info: "Remove all before start"),
        (message: \audio,   params: [\surround, surround],
            info: "Initial settings"),
        (message: \audio,   params: [\depth, ~depth]),
        (message: \physics, params: [\gravX, physics.gravX.default]),
        (message: \physics, params: [\gravY, physics.gravY.default]),
        (message: \physics, params: [\gravZ, physics.gravZ.default]),
        (message: \physics, params: [\drag, physics.drag.default]),
        (message: \physics, params: [\repulsion, physics.repulsion.default]),
        (message: \physics, params: [\starMass, physics.starMass.default]),
        (message: \physics, params: [\particles, physics.particles.default]),
        (message: \physics, params: [\springRestLen, physics.springRestLen.default]),
        (message: \physics, params: [\springStrength, physics.springStrength.default]),
        (message: \physics, params: [\springDamp, physics.springDamp.default]),
        (message: \physics, params: [\mutualAttraction, physics.mutualAttraction.default]),
    ],
    5: [
        // TO-DO:
        // Re-write it to use groupInit, get read of groupNew,
        (
            info: "INTRO, no objects, only .kr buses",
            message: \g_new,
            id: \intro_bundle,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", "sr__s__"++surround, \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \inbus, 12, // getting signal from synth
                    \outbus, mainOutput], // to main output
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \outbus, 12, // feeding into spatilizer
                    \velocity, 0.5, \att, 30, \bufnum, scales[4].bufnum],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.2, \mul, 1pi, \outbus, 0],
                ["/n_map", \group_id, \azimuth, 0],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08, \mul, 2.3, \add, 2.7, \outbus, 1],
                ["/n_map", \group_id, \distance, 1],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 1, \mul, 0.2, \add, 0.6, \outbus, 2],
                ["/n_map", \group_id, \velocity, 2],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.01, \mul, 0.1, \add, 0.1, \outbus, 3],
                ["/n_map", \group_id, \az, 3]
            ]
        )
    ],
    7: [
        (
            info: "INTRO: Particles",
            message: \physics, params: [particles: 1]
        ),
        (
            message: \physics, params: [\maxVel, 2]
        ),
        (
            info: "Silent object",
            message: \particle,
            synth: (name: \sr__e__silent),
            particle: (mass: 1, x: 470, y: 300, z: 250)
        ),
        (
            message: \task, name: \randomParticles, act: 1
        ),
    ],
    10: [
        ( // Remove all objects.
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "INTRO: objects",
            message: \task, name: \intro, act: 1
        )
    ],
    11: [
        (
            info: "INTRO: long noisy",
            message: \g_new,
            id: \intro_noisy,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", "sr__s__"++surround, \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \inbus, 13, // getting signal from synth
                    \outbus, mainOutput], // to main output
                ["/s_new", \sr__e__noisy, \next_node_id, 0, \group_id, // add synth to new group's head
                    \outbus, 13, // feeding into spatilizer
                    \velocity, 0.5, \att, 120],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.2, \mul, 1pi, \outbus, 4],
                ["/n_map", \group_id, \azimuth, 4],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08, \mul, 2.3, \add, 2.7, \outbus, 5],
                ["/n_map", \group_id, \distance, 5],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 1, \mul, 0.2, \add, 0.6, \outbus, 6],
                ["/n_map", \group_id, \velocity, 6]
            ]
        )
    ],
    15: [
        (
            info: "INTRO: voices",
            message: \task, name: \voices, act: 1
        ),
        (
            message: \physics, params: [audioIn: true]
        )
    ],
    16: [
        (
            info: "INTRO: voices background",
            message: \particle,
            synth: (name: \sr__g__reg, params: [\ca, 5, \att, rand(40, 60), \rel, 10, \bufnum, voices.choose.bufnum]),
            particle: (mass: 0.5),
        ),
        (
            message: \particle,
            synth: (name: \sr__g__drone, params: [\ca, 5, \att, rand(80, 120), \rel, 10, \bufnum, voices.choose.bufnum]),
            particle: (mass: 0.5),
        ),
    ],
    20: [
        (info: "Physics environment change",
            message: \physics, params: [\drag, 0.5]),
        (message: \physics, params: [\repulsion, 10]),
        (message: \physics, params: [\maxVel, 150]),
    ],
    22: [
        (
            info: "INTRO: stop voices",
            message: \task, name: \voices, act: 0
        ),
        (
            message: \physics, params: [audioIn: false]
        )
    ],
    30: [
        (
            info: "INTRO: __analog cutoff= -1",
            message: \task, name: \sporadicAnalogCutoff, act: 1
        ),
    ],
    31: [
        ( // Remove all objects.
            info: "SCI-FI",
            message: \action,  params: [\action, \remove, \all]
        ),
        ( // Stop schedule with sporadic \sr__e__analog, cutoff= -1
            info: "Remove all, stop sched, particles OFF",
            message: \task, name: \sporadicAnalogCutoff, act: 0
        ),
        ( // Clear \intro schedule
            message: \task, name: \intro, act: 0
        ),
        ( // Stop occasional particles
            message: \task, name: \randomParticles, act: 0
        ),
        ( // switch particles OFF
            message: \physics, params: [particles: 0]
        ),
        ( // remove intro group from server
            message: \g_free, id: \intro_bundle, params: [\release, 80]
        ),
        ( // remove intro group from server
            message: \g_free, id: \intro_noisy, params: [\release, 80]
        ),
        (
            info: "Ave __pulse, 2 heavy __analog",
            message: \particle,
            synth: (name: \sr__e__pulse, params: [\att, 40, \rel, 10]),
            particle: (age: rrand(80, 150), mass: 0.6, x: 350, y: 120, z: 750),
        ),
        // Start 2 heavy sr__e__analog w/default cutoff and long attack
        (
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 40, \rel, 10]),
            particle: (mass: 1, x: 300, y: 300, z: 250),
        ),
        (
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 40, \rel, 10]),
            particle: (mass: 1, x: 470, y: 300, z: 250)
        )
    ],
    35: [
        (
            info: "SCI-FI: Remove all",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "Schedule sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 1
        ),
        (
            info: "heavy __analog - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 1.0.rand, \rel, 10, \bufnum, scales[0].bufnum]),
            particle: (mass: 1, spring: 1)
        ),
    ],
    36: [
        (
            info: "SCI-FI: heavy __analog 2",
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 10, \bufnum, scales[0].bufnum]),
            particle: (mass: 1, spring: 1)
        ),
    ],
    40: [
        (
            info: "HEAVY: Remove all",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "Heavy __analog (no scale) - TAP twice for 2 more!",
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 1.0.rand, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1),
        ),
        (
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 10, \cutoff, -1]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
        (
            info: "Light __lowe ~heaviness",
            message: \particle,
            synth: (name: \sr__e__lowe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            particle: (mass: 0.8, spring: 1, x: 470, y: 300, z: 250)
        ),
        (
            info: "Stop sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 0
        ),
    ],
    45: [
        (
            info: "2 more heavy __analog (no scale)",
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 2, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1),
        ),
        (
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 2, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    46: [
        (
            info: "Add heavy __therem - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__therem, params: [\att, 2, \rel, 10]),
            particle: (age: inf, mass: 0.8, spring: 1),
        )
    ],
    47: [
        (
            info: "heavy __therem 2",
            message: \particle,
            synth: (name: \sr__e__therem, params: [\att, 2, \rel, 10]),
            particle: (age: inf, mass: 0.8, spring: 1)
        ),
    ],
    48: [
        (
            info: "Remove all",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "leave only 2 __therem - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__therem, params: [\att, 2, \rel, 10]),
            particle: (age: inf, mass: 0.8, spring: 1)
        ),
    ],
    49: [
        (
            info: "Heavy __therem 2",
            message: \particle,
            synth: (name: \sr__e__therem, params: [\att, 2, \rel, 10]),
            particle: (age: inf, mass: 0.8, spring: 1)
        ),
    ],
    50: [
        (
            info: "AIRY",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "heavy __probe - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10, \bufnum, scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    55: [
        (
            info: "AIRY: heavy __probe 2",
            message: \particle,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10, \bufnum, scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1),
        ),
        (
            info: "Schedule sporadic __cmb & __melo",
            message: \task, name: \sporadicCMB, act: 1
        ),
        (
            message: \task, name: \sporadicMelo, act: 1
        )
    ],
    60: [
        ( // Remove all objects.
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "Heavy __cmb - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__cmb, params: [\att, 1.0.rand, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1),
        ),
    ],
    61: [
        (
            info: "Heavy __cmb",
            message: \particle,
            synth: (name: \sr__e__cmb, params: [\att, 3 + 2.0.rand2, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1)
        )
    ],
    70: [
        (
            info: "ELECTRO SOLO",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "2 heavy __melo - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    71: [
        (
            info: "heavy __melo 2",
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    72: [
        (
            info: "Schedule scale switch",
            message: \task, name: \switchScale, act: 1
        ),
    ],
    // XXX
    // WARNING! This does not work properly, producing a lot of noise.
    // Omitting it temporarily.
    // 73: [
    //     (
    //         info: "2 heavy __audiothru - TAP twice for 2!",
    //         message: \particle,
    //         synth: (name: \sr__r__authro, params: [\inbus, audioThruBus[0]]),
    //         particle: (age: inf, mass: 0.9, spring: 1)
    //     ),
    // ],
    // 74: [
    //     (
    //         info: "Heavy __audiothru 2",
    //         message: \particle,
    //         synth: (name: \sr__r__authro, params: [\inbus, audioThruBus[1]]),
    //         particle: (age: inf, mass: 0.9, spring: 1)
    //     ),
    //     (
    //         info: "Schedule granular waves",
    //         message: \task, name: \granWave, act: 1
    //     )
    // ],
    // 79: [
    //     (
    //         info: "Add ave __noisy, long attack",
    //         message: \particle,
    //         synth: (name: \sr__e__noisy, params: [\att, 180, \rel, 10]),
    //         particle: (mass: 0.7)
    //     ),
    //     (
    //         info: "Stop percussive granWave",
    //         message: \task, name: \granWave, act: 0
    //     ),
    //     ( // switch audioIn off
    //         message: \physics,
    //         params: [audioIn: false]
    //     ),
    // ],
    80: [
        (
            info: "BREAKS",
            message: \action,  params: [\action, \remove, \all]
        ),
        ( // IMPORTANT! switchScale sends scales as buffers to all nodes
            // It should be stopped before starting granWave to prevent
            // sending scales instead of samples.
            info: "Stop all schedules",
            message: \task, name: \switchScale, act: 0
        ),
        ( // Stop schedule with sporadic \sr__e__cmb
            message: \task, name: \sporadicCMB, act: 0
        ),
        ( // Stop schedule with sporadic \sr__e__melo
            message: \task, name: \sporadicMelo, act: 0
        ),
        (
            info: "heavy __entro - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    86: [
        (
            info: "heavy __entro 2",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    90: [
        (
            info: "GROOVE",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "heavy __gauss - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__gauss, params: [\att, 1, \rel, 8]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    91: [
        (
            info: "heavy __gauss 2",
            message: \particle,
            synth: (name: \sr__e__gauss, params: [\att, 1, \rel, 8]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],

    92: [
        ( // Remove all objects.
            info: "OUTRO",
            message: \action,  params: [\action, \remove, \all]
        ),
        // XXX
        // - Particles don't work, because skeleton hands' velocity is 0 -
        //   substitute by a synth similar to sr__e__pulse, only hard thresholded
        //   by velocity. And attach particles with this synth to both hands.
        // - This will be solved indirectly when the issue 52 is completed:
        //   https://github.com/deniskolokol/sympli_romatiko/issues/52
        // (
        //     info: "Particles ON",
        //     message: \physics,
        //     params: [
        //         \particles, 1, \partSynth, \sr__e__analog,
        //         \partSigmoidRatio, 0.7, \partAgeThresh, 1.1, \partInitAccel, 3
        //     ]
        // ),
        (
            info: "heavy __noisy - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    93: [
        (
            info: "heavy __noisy 2",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
        (
            info: "heavy __pulse with long attack",
            message: \particle,
            synth: (name: \sr__e__pulse, params: [\att, 200, \rel, 10, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],
    99: [
        (
            info: "FIN",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "Remove all, particles OFF",
            message: \physics, params: [particles: 0]
        )
    ]
);

// Store global params of the piece in a dictionary.
parmDir.putPairs(thePiece[0][0][\params]);

// Tasks dictionary.
task = (
    randomParticles: Task({
        var key, next;
        var particleParams = [ // list of acceptable configurations
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.3, \partAgeThresh, 1.67, \partInitAccel, 10 ],
            [\partSynth, \sr__e__cmb,   \partSigmoidRatio, 0.8, \partAgeThresh, 0.08, \partInitAccel, 2.6],
            [                           \partSigmoidRatio, 0.4, \partAgeThresh, 1.04, \partInitAccel, 30 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.7, \partAgeThresh, 1.08, \partInitAccel, 8.0],
            [                           \partSigmoidRatio, 0.2, \partAgeThresh, 1.67, \partInitAccel, 1.0],
            [\partSynth, \sr__e__melo,  \partSigmoidRatio, 0.7, \partAgeThresh, 0.78, \partInitAccel, 2.0],
            [\partSynth, \sr__e__pulse, \partSigmoidRatio, 0.2, \partAgeThresh, 1.03, \partInitAccel, 20 ],
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
            age = buff.numFrames / buff.numChannels / buff.sampleRate;
            #x, y, z = { rrand(worldSize, worldSize * ([0.1, 0.9].choose)) } ! 3;
            case
            // when voices are introduced, they should be clearly recognizable
            {j <= 5} { syn = \sr__g__loop }
            {(j > 5) && (j <= 10)} {syn = [\sr__g__loop, \sr__g__loopdel, \sr__g__unst].choose}
            {j > 10} { // later on "smooth them out" into a voice meshup
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
            // vary waiting time - everynow and then send the next particle
            // without waiting until the end of the sample
            if (prob.coin) { (age * 0.25).wait } { (age + rrand(4, 10)).wait }
        }
    }),
    sporadicAnalogCutoff: Task({
        var x, y, z;
        loop {
            #x, y, z = (100 ! 3).rand2 + 350;
            sendParticle.(
                particle: (mass:0.7, x:x, y:z, z:z, age:rrand(3, 4)),
                synth: (name:\sr__e__analog, params:[\cutoff, -1, \att, 0.2, \rel, rrand(4, 6)])
            );
            (10 + 2.0.rand2).wait;
        }
    }),
    sporadicPulse: Task({
        loop {
            sendParticle.(
                particle: (age: rrand(1.7, 5.0), mass: 0.9, spring:[1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__pulse, params: [\att, 0.2, \rel, 3]));
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
        var sca = scales[1..]; // first scale is a default one, don't take it into consideration
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
    var nodeID = s.nextNodeID;

    try { // Ignore the case when doneAction = 2.
        synths.put(data[\synth][\id], nodeID);
    };

    s.listSendMsg(["/s_new", data[\synth][\name],
        nodeID, 0, sGroupId] ++ data[\synth].atFail(\params, {[]}));
};


// TO-DO:
// divide groupNew to 2 separate fuctions:
// - initGroup
// - registerGroup
//
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
    node = ~groupInit.(synth[\name], surround, params:synth[\params]);
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
    k = thePiece.keys.asArray.asInteger.sort;
    c = k.indexOf(current) ? -1;
    k[c + next] ? k[0]; // Go back to beginning upon reaching the upper threshold.
};


// Increments integers with a limit: resets to `lo` every time in + step reaches `hi`.
clipInc = { |in=0, step=1, lo=0, hi=inf| ((in + step).clip(lo, hi) % hi).clip(lo, hi)};


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
                s.listSendMsg(["/n_set", synths.at(d[\synth][\id])] ++ d[\synth].atFail(\params, {[]}))
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
win = Window("sequencing and scheduling", Rect(1070, 800, 610, Window.screenBounds.height-300))
    .acceptsMouseOver_(true);
win.view.decorator = FlowLayout(win.view.bounds);

info = CompositeView(win, 500@165);
info.decorator = FlowLayout(info.bounds);
stCurrNum = StaticText(info, 70@60).font_(Font("Monaco", 32)).background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stCurrInfo = StaticText(info, 410@60).font_(Font("Monaco", 12)).background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stNextNum = StaticText(info, 70@90).font_(Font("Monaco", 32)).background_(Color.grey(0.4)).stringColor_(Color.white);
stNextInfo = StaticText(info, 410@90).font_(Font("Monaco", 14)).background_(Color.grey(0.4)).stringColor_(Color.white);

elapsed = CompositeView(win, 85@150);
timeLabel = StaticText(elapsed, 85@80).font_(Font("Monaco", 18));

keyboard = CompositeView(win, 600@170);
keyboardFunc = { |synthName, params, spring=0, mass=1|
    sendParticle.(
        synth: (name: synthName, params: params),
        particle: (spring:spring, mass:mass));
};
keyboard.decorator = FlowLayout(keyboard.bounds);
keyboard.background = Color.new255(0, 0, 0, alpha:100);
trigSynth.do { |key, i|
    var view, buff;
    if (i % 2 == 0) {
        if (synthNames[key].asString.beginsWith("sr__e__")) { buff = scales.choose };
        if (synthNames[key].asString.beginsWith("sr__g__")) { buff = voices.choose };
        view = CompositeView(keyboard, 41@70);
        view.decorator = FlowLayout(view.bounds);
        Button(view, 41@45).states_(
            [[keyNames[key].toUpper, Color.black, Color.white]]
        ).canFocus_(false)
        // TO-DO: Make use of Shift+Key (with or without spring)
        .action_({ |bt| keyboardFunc.(synthNames[key], params: [\bufnum, buff.bufnum], spring:1) });
        StaticText(view, 41@25).string_(
            synthNames[key].asString.replace("sr__e__", "").replace("sr__g__", ""))
        .align_(\topLeft)
        .font_(Font("Monaco", 12))
        .stringColor_(Color.white);
    };
};

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

// MIDI interface (physics parameters)
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
button.(pane, dummyParam, "RESET", 0.6, 0.5);
miscParams[\reset] = (
    midinote: 70,
    gui: button.(pane, dummyParam, "X", 0.6, 0.5).action_({ |bt|
        physics.values.do { |element|
            try { element[\gui].valueAction_(element[\default]) };
        }
    })
);
miscParams[\removeall] = (
    midinote: 58,
    gui: button.(pane, dummyParam, "X", 0.6, 0.5).action_({ |bt|
        sendAct.((params: [\remove, \all]))
    })
);
button.(pane, dummyParam, "<NONE>", 0.6, 0.5);
pane = CompositeView(panePar, paneWidth.(panePar, 0.2)@paneHeight.(panePar, 0.17));
physics[\particles][\gui] = buttonCheckbox.(pane, physics[\particles], \particles);

// RIGHT PANE
panePar = CompositeView(midiView, paneWidth.(midiView)@paneHeight.(midiView))
    .background_(Color.grey(grey:0.7));
panePar.decorator = FlowLayout(panePar.bounds);
// RIGHT PANE LEFT SIDE
pane = CompositeView(panePar, paneWidth.(panePar, 0.33)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
param = (param: "depth", minval: 1, maxval: 10, step: 0.1, default: 5);
miscParams[\depth] = (
    midicc: 34, minval: param[\minval], maxval: param[\maxval], step: param[\step],
    gui: knob.(pane, param, "depth")
    .action_({ |ez|
        ~depth = ez.value;
        sendAudio.((params: [\depth, ~depth]));
    })
);
[\none, \none].do { |key| // Dummies
    knob.(pane, dummyParam, "<NONE>");
};
pane = CompositeView(panePar, paneWidth.(panePar, 0.17)@paneHeight.(panePar, 0.85));
slider.(pane, dummyParam, \vert);
// RIGHT PANE RIGHT SIDE
pane = CompositeView(panePar, paneWidth.(panePar, 0.33)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
[\springRestLen, \springStrength, \springDamp].do { |key|
    physics[key][\gui] = knob.(pane, physics[key], key);
};
pane = CompositeView(panePar, paneWidth.(panePar, 0.17)@paneHeight.(panePar, 0.85));
pane.decorator = FlowLayout(pane.bounds);
slider.(pane, dummyParam, \vert);
// RIGHT PANE BOTTOM
pane = CompositeView(panePar, paneWidth.(panePar, 0.8)@paneHeight.(panePar, 0.17));
pane.decorator = FlowLayout(pane.bounds);
4.do { button.(pane, dummyParam, "<NONE>", 0.6, 0.5) };
pane = CompositeView(panePar, paneWidth.(panePar, 0.2)@paneHeight.(panePar, 0.17));
physics[\mutualAttraction][\gui] = buttonCheckbox.(pane, physics[\mutualAttraction], \mutualAttraction);

// KEYBOARD
win.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    [char, modifiers, unicode, keycode].postln;
    case
    { keycode == 6 && [0, 256].includes(modifiers) } { // Z - info
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
(physics ++ miscParams).values.do { |element|
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