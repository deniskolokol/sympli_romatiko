(
var thePiece; // main dictionary with the sequence of scheduled tasks
var samplesDir;
var surround, mainInput, mainOutput; // audio setup for the current piece
var depth=5, inbus=12, outbus=0, audioThruBus=[21, 22]; // to main output
var worldSize; // assume the World is a cube
var parmDir = Dictionary.new; // Global params of the piece dictionary.
var sGroupId; // root group
var receiver; // communication
var task; // tasks dictionary
var guideBuff, samples, scales, voices; // buffers (sound files and scales)
var trigSynth, synthNames, keyNames; // available SynthDefs
var synths=Dictionary.new; // temp dictionary of the synths symbolic IDs vs. server Nodes
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime
var key, current, next, syn, obj, age, mass; // object's properties
var win, info, buttons, keyboard, keyboardFunc, // interface
    stCurrNum, stCurrInfo, stNextNum, stNextInfo,
    btPrev, btNext, timeLabel;
var shade, count=0, animate=false; // schedule animation
var getKey, displayEventInfo, convertTime, clipInc; // helper functions
var midiServerVolume, midiNext, midiPrev, midiClean;
var processEvents, groupNew, groupFree, taskPlay, sendWorld,
    sendParticle, sendSNew, sendPhysics, sendAudio, sendAct; // acting functions

var testLabel; // DELETE IT


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
    FloatArray[0, 2, 4, 6, 9],
    FloatArray[0, 3, 6, 9, 11],
    FloatArray[0, 1, 3, 7, 10],
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
    40, \sr__e__saw,    // k
];
synthNames = Dictionary.newFrom(trigSynth);
// TO-DO: names should be obtained automatically
keyNames = (12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y",
    32: "u", 34: "i", 31: "o", 35: "p", 33: "[", 30: "]", 42: "\\",
    1:  "s", 2:  "d", 3:  "f", 5:  "g", 4:  "h", 38: "j", 40: "k");

surround = "ambisonic2";
mainOutput = 0;
mainInput = 20;
worldSize = 800;

thePiece = (
    0: [
        (message: \action,  params: [\action, \remove, \all],
            info: "Remove all before start"),
        (message: \audio,   params: [\surround, surround]),
        (message: \audio,   params: [\depth: depth]),
        (message: \physics, params: [\gravity, 0, 0, 0],
            info: "Initial settings"),
        (message: \physics, params: [\drag, 0.001]),
        (message: \physics, params: [\repulsion, 100]),
        (message: \physics, params: [\starMass, 1]),
        (message: \physics, params: [\starSize, 10]),
        (message: \physics, params: [\particles, 0]),
        (message: \physics, params: [\springRestLen, 5]),
        (message: \physics, params: [\springStrength, 2]),
        (message: \physics, params: [\springDamp, 2]),
        (message: \physics, params: [\mutualAttraction, true]),
    ],
    5: [
        // TO-DO:
        // Re-write it to use ~groupInit, get read of groupNew,
        (
            info: "INTRO, no objects, only .kr buses",
            message: \g_new,
            id: \intro_bundle,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", "sr__s__"++surround, \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, depth,
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
    //
    // TO-DO: slowly increase repuslion 10..100, star mass 1..10
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
                    \depth, depth,
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
    12: [
        (
            info: "INTRO: voices",
            message: \task, name: \voices, act: 1
        ),
        (
            message: \physics, params: [audioIn: true]
        )
    ],
    // TO-DO:
    // This is necessary for objects on springs proper behavior
    // Hovewer this makes freely floating particles sluggish.
    // Invent something!
    20: [
        (info: "Physics environment change",
        message: \physics, params: [\gravity, 0, 0, -2]),
        (message: \physics, params: [\drag, 0.5]),
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
        //
        // IS IT STILL NECESSARY?
        //
        // (
        //     info: "Remove mutual attraction",
        //     message: \physics, params: [objAttract: false]
        // ),
        // (
        //     info: "Restore star mass",
        //     message: \physics,
        //     params: [starMass: 1]
        // ),
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
            info: "Light __lowe ~heaviness",
            message: \particle,
            synth: (name: \sr__e__lowe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            particle: (mass: 0.6, x: 470, y: 300, z: 250)
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
            info: "HEAVY",
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 1.0.rand, \rel, 10, \bufnum, scales[0].bufnum]),
            particle: (age: inf, mass: 1, spring: 1),
        ),
        (
            info: "2 more heavy __analog default and -1 cutoff",
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 2 + 1.0.rand2, \rel, 10, \cutoff, -1, \bufnum, scales[0].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
        (
            info: "Stop sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 0
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
        )
    ],
    51: [
        (
            info: "AIRY: heavy __probe 2",
            message: \particle,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10, \bufnum, scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1),
        )
    ],
    55: [
        (
            info: "Schedule sporadic __cmb & __melo",
            message: \task, name: \sporadicCMB, act: 1
        ),
        (
            message: \task, name: \sporadicMelo, act: 1
        )
    ],
    57: [
        ( // Remove all objects.
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "Leave __probe - TAP twice for __cmb!",
            message: \particle,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    58: [
        (
            info: "Heavy __cmb",
            message: \particle,
            synth: (name: \sr__e__cmb, params: [\att, 1.0.rand, \rel, 10]),
            particle: (age: inf, mass: 0.9, spring: 1),
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
            particle: (age: inf, mass: 0.9, spring: 1),
        ),
    ],
    61: [
        (
            info: "Heavy __cmb",
            message: \particle,
            synth: (name: \sr__e__cmb, params: [\att, 3 + 2.0.rand2, \rel, 10]),
            particle: (age: inf, mass: 0.9, spring: 1)
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
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    71: [
        (
            info: "heavy __melo 2",
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, scales[1].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    72: [
        (
            info: "Schedule scale switch",
            message: \task, name: \switchScale, act: 1
        ),
    ],
    73: [
        ( // IMPORTANT! switchScale sends sclaes as buffers to all nodes
            // It should be stopped before starting granWave to prevent
            // sending scales instead of samples.
            info: "Stop switching scales",
            message: \task, name: \switchScale, act: 0
        ),
        (
            info: "2 heavy __audiothru - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__r__authro, params: [\inbus, audioThruBus[0]]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    74: [
        (
            info: "Heavy __audiothru 2",
            message: \particle,
            synth: (name: \sr__r__authro, params: [\inbus, audioThruBus[1]]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
        (
            info: "Schedule granular waves",
            message: \task, name: \granWave, act: 1
        )
    ],
    77: [
        ( // Remove all - switch to ringz
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "Heavy __ringz - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__ringz, params: [\att, 10.0.rand]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
        (
            info: "Ave __lowe",
            message: \particle,
            synth: (name: \sr__e__lowe, params: [\att, 10.0.rand, \rel, 10]),
            particle: (mass: 0.6, spring: 1)
        ),
    ],
    78: [
        (
            info: "Heavy __ringz 2",
            message: \particle,
            synth: (name: \sr__e__ringz, params: [\att, 10.0.rand]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    79: [
        (
            info: "Add ave __noisy, long attack",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 180, \rel, 10]),
            particle: (mass: 0.7)
        ),
        (
            info: "Stop percussive granWave",
            message: \task, name: \granWave, act: 0
        ),
        ( // switch audioIn off
            message: \physics,
            params: [audioIn: true]
        ),
    ],
    80: [
        ( // Stop schedule with sporadic \sr__e__cmb
            info: "GROOVE_1",
            message: \task, name: \sporadicCMB, act: 0
        ),
        ( // Stop schedule with sporadic \sr__e__melo
            info: "Stop sched",
            message: \task, name: \sporadicMelo, act: 0
        ),
        (
            info: "Add one heavy __noisy",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 9]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    85: [
        (
            info: "BREAK GROOVE",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
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
            info: "BREAK GROOVE: heavy __entro 2",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    90: [
        (
            info: "GROOVE_2",
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
            info: "GROOVE_2: heavy __gauss 2",
            message: \particle,
            synth: (name: \sr__e__gauss, params: [\att, 1, \rel, 8]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],
    95: [
        ( // Remove all objects.
            info: "FADE AWAY",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "Particles ON",
            message: \physics,
            params: [
                particles: 1, partSigmoidRatio: 0.7, partFreq: 0.02, partAgeThresh: 80,
                partInitAccel: 3, partGuide: "object", partSynth: \sr__e__analog,
            ]
        ),
        (
            info: "2 light granular boids",
            message: \particle,
            synth: (name: \sr__g__reg, params: [\att, 5.0.rand, \rel, 10]),
            particle: (mass: 0.6)
        ),
        (
            message: \particle,
            synth: (name: \sr__g__loop, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.6)
        ),
        ( // ensure audioIn (drums)
            message: \physics,
            params: [audioIn: true]
        ),
        (
            info: "heavy __noisy - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    96: [
        (
            info: "heavy __noisy 2",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    99: [
        (
            info: "FIN",
            message: \action,  params: [\action, \remove, \all]
        ),
        (
            info: "Remove all, particles OFF",
            message: \physics, params: [particles: 0]
        ),
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
                synth = (name: [\sr__e__humm, \sr__e__radio][i % 2]); // alternate
                sendParticle.(synth: synth, particle: (mass:mass, x:x, y:y, z:z, age:age));
                if (0.5.coin) {
                    synth = (name: [\sr__e__radio, \sr__e__humm].choose);
                    sendParticle.(synth: synth, particle: (mass:mass, x:x, y:y, z:z,
                        age:age + ((age * 0.25).rand2)));
                };
                next.wait;
            };
            0.01.wait;
        }
    }),
    voices: Task({
        var buff, syn, age, x, y, z;
        inf.do { |j|
            buff = voices[(j % voices.size).asInt];
            age = buff.numFrames / buff.numChannels / buff.sampleRate;
            syn = [\sr__g__unst, \sr__g__loop, \sr__g__reg].wchoose([0.5, 0.3, 0.2]);
            #x, y, z = (50 ! 3).rand + [100, 500].choose;
            sendParticle.(
                particle: (mass:0.5, x:x, y:z, z:z, age:age),
                synth: (name:syn, params:[\att, 2, \bufnum, buff.bufnum])
            );
            if (0.3.coin) { (age * 0.25).wait } { (age + rrand(4, 10)).wait }
        }
    }),
    sporadicAnalogCutoff: Task({
        var x, y, z;
        loop {
            #x, y, z = (100 ! 3).rand2 + 350;
            sendParticle.(
                particle: (mass:0.4, x:x, y:z, z:z, age:rrand(3, 4)),
                synth: (name:\sr__e__analog, params:[\cutoff, -1, \att, 0.2, \rel, rrand(4, 6)])
            );
            (10 + 2.0.rand2).wait;
        }
    }),
    sporadicPulse: Task({
        loop {
            sendParticle.(
                particle: (age: rrand(1.7, 5.0), mass: 0.8, spring:[1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__pulse, params: [\att, 0.2, \rel, 3]));
            (20 + rand2(20 * 0.5)).wait;
        }
    }),
    sporadicCMB: Task({
        loop {
            sendParticle.(
                particle: (age: rrand(2, 5), mass: 0.6, spring:[1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__cmb, params: [\att, 1.5, \rel, 3]));
            (30 + rand2(30 * 0.25)).wait;
        }
    }),
    sporadicMelo: Task({
        loop {
            (20 + rand2(20 * 0.25)).wait;
            sendParticle.(
                particle: (age: rrand(5, 10), mass: 0.4, spring:[1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__melo, params: [\att, 1.5, \rel, 3, \bufnum, scales[1].bufnum]));
            ((20 + rand2(20 * 0.25))/2).wait;
        }
    }),
    switchScale: Task({
        inf.do{ |i|
            // WARNING! This works weird! Compare with example of
            // DegreeToKey from the doc! Investigate!!!
            //
            s.sendMsg("/n_set", nil, \bufnum, scales[i % scales.size].bufnum);
            (4..8).choose.wait;
        }
    }),
    granWave: Task({
        var buff, age, timeprop, next=20;
        var introSynths = [\sr__g__loop, \sr__g__slic, \sr__g__drone, \sr__g__reg, \sr__g__gust];
        // Probablity of choosing a particular synth decreases towards the end of the list.
        var introSynthProb = Array.fill(introSynths.size, {exprand(0.01, 1.00)}).normalizeSum.sort.reverse;
        inf.do{ |j|
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


//
// TO-DO:
// - Move this to the class in sympliRomatiko class hierarchy.
//
// Create new synths group on Server, insert synth and spatializer into it.
//
// Assigns internal bus for rounting: each group of synth and its spatializer
// should have a separate rounting bus for spatialization to take pkace individually.
~groupInit = { |synth, spatial, bufnum, busnum, params|
    var node, l=30, h=53;
    spatial = spatial.asString;
    if (spatial.beginsWith("sr__s__").not) {
        spatial = "sr__s__" ++ spatial.toLower
    };
    node = s.nextNodeID;
    if (busnum.isNil) {
        busnum = clipInc.(~route ?? l, lo:l, hi:h);
        ~route = busnum;
    };
    s.sendBundle(0.01,
        ["/error", 1], // turn errors off (locally)
        ["/g_new", node],
        ["/s_new", spatial, s.nextNodeID, 1, node, // add spatializer to new group's tail
            \inbus, busnum, // getting signal from synth
            \outbus, mainOutput, // to main output
            \depth, depth],
        ["/s_new", synth, s.nextNodeID, 0, node, // add synth to new group's head
            \inbus, mainInput, // getting signal from external input
            \outbus, busnum, // feeding into spatilizer
            \bufnum, bufnum] ++ (params ? [])
    );
    node // return ID of the Group created
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


// Sends message to the World.
sendWorld = { |msg|
    receiver.sendBundle(0.01, msg);
};


// Sends particle creation message to the World.
// Returns Server node.
sendParticle = { |particle, synth|
    var node, spring, pos, x, y, z, age;

    node = ~groupInit.(synth[\name], surround, params:synth[\params]);
    pos = [particle.x, particle.y, particle.z];
    #x, y, z = Array.fill(pos.size, { |i| pos[i] ? worldSize.rand});
    // create:1, node, spring:0|1, mass:9, x:470, y:300, z:250, age:inf
    sendWorld.(['/particle', 1, node, particle.atFail(\spring, {0}),
        particle.mass, x, y, z, particle.atFail(\age, {inf})]);
    node
};


// Sends parameter to the World.
sendPhysics = { |data|
    receiver.sendBundle(0.001, ['/physics'] ++ data[\params])
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
                groupFree.(d)
            },
            { // default function
                sendWorld.(d[\params])
            }
        )
    }
};

// GUI.
//
win = Window("sequencing and scheduling", Rect(1070, 1000, 610, 700))
.acceptsMouseOver_(true);
win.view.decorator = FlowLayout(win.view.bounds);

info = CompositeView(win, 500@165);
info.decorator = FlowLayout(info.bounds);
stCurrNum = StaticText(info, 70@60).font_(Font("Monaco", 32)).background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stCurrInfo = StaticText(info, 410@60).font_(Font("Monaco", 12)).background_(Color.gray(0.8)).stringColor_(Color.gray(0.2));
stNextNum = StaticText(info, 70@90).font_(Font("Monaco", 32)).background_(Color.grey(0.4)).stringColor_(Color.white);
stNextInfo = StaticText(info, 410@90).font_(Font("Monaco", 14)).background_(Color.grey(0.4)).stringColor_(Color.white);

buttons = CompositeView(win, 80@150);
buttons.decorator = FlowLayout(buttons.bounds);
btNext = Button(buttons, 70@45).states_([[">>", Color.black, Color.white]])
.action_({ |bt|
    if (animate.not) {animate = true}; // bring it on!
    stCurrNum.string = current = getKey.(current);
    stCurrInfo.string = displayEventInfo.(current);
    stNextNum.string = next = getKey.(current, 1);
    stNextInfo.string = displayEventInfo.(next, 50);

    processEvents.(current);
});

btPrev = Button(buttons, 70@45).states_([["<<", Color.black, Color.white]])
.action_({ |bt|
    stCurrNum.string = current = getKey.(current, -1);
    stCurrInfo.string = displayEventInfo.(current);
    stNextNum.string = next = getKey.(current, 1);
    stNextInfo.string = displayEventInfo.(next);

    processEvents.(current);
});

timeLabel = StaticText(buttons, 70@60).font_(Font("Monaco", 14));

keyboard = CompositeView(win, 600@170);
keyboardFunc = { |synthName, spring=0, mass=0.7|
    sendParticle.(synth: (name: synthName), particle: (spring:spring, mass:mass));
};
keyboard.decorator = FlowLayout(keyboard.bounds);
keyboard.background = Color.new255(0, 0, 0, alpha:100);
trigSynth.do { |key, i|
    var view;
    if (i % 2 == 0) {
        view = CompositeView(keyboard, 41@70);
        view.decorator = FlowLayout(view.bounds);
        Button(view, 41@45).states_(
            [[keyNames[key].toUpper, Color.black, Color.white]]
        ).canFocus_(false)
        // TO-DO: Make use of Shift+Key (with or without spring)
        .action_({ |bt| keyboardFunc.(synthNames[key], spring:1) });
        StaticText(view, 41@25).string_(
            synthNames[key].asString.replace("sr__e__", "").replace("sr__g__", ""))
        .align_(\topLeft)
        .font_(Font("Monaco", 12))
        .stringColor_(Color.white);
    };
};

testLabel = StaticText(win, 600@50).align_(\topLeft).font_(Font("Monaco", 20));

win.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    [char, modifiers, unicode, keycode].postln;
    case
    {keycode == 6} { // Z - info
        if( [0, 256].includes(modifiers), {
            postf("window: left %, top %, width %, height %\n",
                win.bounds.left, win.bounds.top, win.bounds.width, win.bounds.height);
        });
    }
    { synthNames.keys.includes(keycode) } { keyboardFunc.(synthNames[keycode], spring:1) }
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

// LOAD WORLD
"Loading world...".postln;
if (this.executeFile("/Users/deniskolokol/Documents/dev_music/sympli_romatiko/repo/sympli_romatiko/world.scd").isNil.not) {
    postf("OK\n\n")
};

MIDIIn.connectAll;
midiServerVolume = MIDIFunc.cc({ |val, ccNum, chan, srcID|
    s.volume.volume = \db.asSpec.map(\midinote.asSpec.unmap(val));
}, 12, 0);
midiNext = MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
    { btNext.valueAction_(1) }.defer;
}, 43, 0);
midiPrev = MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
    { btPrev.valueAction_(1) }.defer;
}, 46, 0);
midiClean = MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
    sendAct.(\remove, \all)
}, 58, 0);
midiClean = MIDIFunc.noteOn({ |val, noteNum, chan, srcID|
    sendAct.(\remove, \springs)
}, 70, 0);

CmdPeriod.doOnce({
    // Free buffers.
    guideBuff.free;
    samples.do { |buff| buff.free};
    scales.do  { |buff| buff.free};
    voices.do  { |buff| buff.free};
    win.close;
});
)