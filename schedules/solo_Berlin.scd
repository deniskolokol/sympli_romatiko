// solo concert for SPEKTRUM, Berlin

//
// main idea
// adapt /Users/deniskolokol/Documents/dev_music/utils/markov_signs.scd
// every tick leads to the change of a "scene"
//
// every scene can be one of the following:
// a) the same synth connected to both hands
// b) combination of synths taken from a library, where synths that fit each other aregrouped together
// c) (a) or (b) plus "something happening around" (objects and particles flying around)
// d) (a) or (b) plus a rhythm
//
// change of scene is "marked" by a designated sound from the library
// (dictionary with keys as types of coming sequence [short, mid, long] and
// samples that can "symbolize" those sequences)


//
// research and adapt (parts):
// /Users/deniskolokol/Music/CD_cassette_vynil/Compilations/Egypt - Echoes Of The Nile/12 Rhythmic Improvisation.m4a
// samples - /Users/deniskolokol/Music/material/Drum samples/513TubeDrumHits_Wav_SP/Samples/


(
var samplesDir;
var guideBuff; // buffers (sound files and scales)
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime

//GLOBAL
~sequence = (
    title: "solo-B",
    events: Dictionary.new,
    marks: Dictionary.new,
    tasks: Dictionary.new,
    samples: List.new,
    voices: List.new,
    scales: List.new,
);

// INITIAL
//
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
PathName.new(samplesDir +/+ "drums").entries.do { |f, i|
    try { ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
PathName.new(samplesDir +/+ "voices").entries.do { |f, i|
    try { ~sequence.voices.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
guideBuff = Buffer.readChannel(~scsynth,
    PathName(samplesDir +/+ "drums/drumguide.wav").fullPath, channels: [0]
);

[
    #[0, 3, 7, 10], // scales[0] is the main scale
    #[0, 1, 3, 7, 8], // the rest are specific to sequence's parts
    #[0, 2],
    #[0, 3],
    #[1, 3],

	#[0,3,6,7,11], // Todi
    #[0,1,4,6,7,8,11], // Purvi
    #[0,1,4,6,7,9,11], // Marva
    #[0,1,4,5,7,8,11], // Bhairav
    #[0,1,4,5,7,9,10], // Ahirbhairav
].do { |c, i|
    ~sequence.scales.add(Buffer.sendCollection(~scsynth, c));
};

~sequence.events = (
    0: [
        (
            // WARNING!
            // call for main scheduler should always be called first (key 0)
            info: "CALL main_scheduler",
            message: \task, name: \main_scheduler, act: 1
        )
    ],
    5: [
        (
            wait: 0.5,
            message: \action,  params: [\remove, \all],
            info: "Remove all before start\n Apply initial settings",
        ),
        (message: \physics, params: [\gravX, \default]),
        (message: \physics, params: [\gravY, \default]),
        (message: \physics, params: [\gravZ, \default]),
        (message: \physics, params: [\drag, 0.001]),
        (message: \physics, params: [\repulsion, \default]),
        (message: \physics, params: [\starMass, \default]),
        (message: \physics, params: [\particles, \default]),
        (message: \physics, params: [\springRestLen, \default]),
        (message: \physics, params: [\springStrength, \default]),
        (message: \physics, params: [\springDamp, \default]),
        (message: \physics, params: [\mutualAttraction, \default]),
    ],
    // 6: [
    //     (
    //         info: "INTRO, no objects, only .kr buses",
    //         wait: 20,
    //         message: \g_new,
    //         id: \intro_bundle,
    //         //XXX: Fix cliping!
    //         params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
    //             ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
    //                 \depth, ~depth,
    //                 \route, 14, // getting signal from synth
    //             \outbus, ~outbus], // to main output
    //             ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
    //                 \route, 14, // feeding into spatilizer
    //             \velocity, 0.5, \att, 40, \bufnum, ~sequence.scales[4].bufnum],
    //             ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.2, \mul, 1pi, \outbus, 0],
    //             ["/n_map", \group_id, \azimuth, 0],
    //             ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.08, \mul, 0.3, \add, 0.7, \outbus, 1],
    //             ["/n_map", \group_id, \distance, 1],
    //             ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.1, \mul, 0.25, \add, 0.5, \outbus, 2],
    //             ["/n_map", \group_id, \velocity, 2],
    //             ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.01, \mul, 0.1, \add, 0.1, \outbus, 3],
    //             ["/n_map", \group_id, \az, 3]
    //         ]
    //     )
    // ],
    // 7: [
    //     (
    //         wait: 20,
    //         info: "INTRO: Particles",
    //         message: \physics, params: [particles: 1]
    //     ),
    //     (
    //         message: \physics, params: [\maxVel, 2]
    //     ),
    //     (
    //         info: "Silent object",
    //         message: \particle,
    //         synth: (name: \sr__e__silent),
    //         particle: (mass: 1, x: 470, y: 300, z: 250)
    //     ),
    //     (
    //         message: \task, name: \randomParticles, act: 1
    //     ),
    // ],
    // 10: [
    //     ( // Remove all objects.
    //         wait: 20,
    //         message: \action,  params: [\remove, \all]
    //     ),
    //     (
    //         info: "INTRO: objects",
    //         message: \task, name: \intro, act: 1
    //     )
    // ],
    // 11: [
    //     (
    //         info: "INTRO: long noisy",
    //         wait: 5,
    //         message: \g_new,
    //         id: \intro_noisy,
    //         params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
    //             ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
    //                 \depth, ~depth,
    //                 \route, 15, // getting signal from synth
    //             \outbus, ~outbus], // to main output
    //             ["/s_new", \sr__e__noisy, \next_node_id, 0, \group_id, // add synth to new group's head
    //                 \route, 15, // feeding into spatilizer
    //             \velocity, 0.5, \att, 120],
    //             ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.2, \mul, 1pi, \outbus, 4],
    //             ["/n_map", \group_id, \azimuth, 4],
    //             ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08, \mul, 2.3, \add, 2.7, \outbus, 5],
    //             ["/n_map", \group_id, \distance, 5],
    //             ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 1, \mul, 0.2, \add, 0.6, \outbus, 6],
    //             ["/n_map", \group_id, \velocity, 6]
    //         ]
    //     )
    // ],
    // 15: [
    //     (
    //         info: "INTRO: voices",
    //         wait: 30,
    //         message: \task, name: \voices, act: 1
    //     ),
    // ],
    // 16: [
    //     (
    //         info: "INTRO: voices background",
    //         message: \particle,
    //         synth: (name: \sr__g__reg, params: [
    //             \ca, 5, \att, rand(40, 60), \rel, 10, \bufnum, ~sequence.voices.choose.bufnum
    //         ]),
    //         particle: (mass: 0.5),
    //     ),
    //     (
    //         message: \particle,
    //         synth: (name: \sr__g__drone, params: [
    //             \ca, 5, \att, rand(80, 120), \rel, 10, \bufnum, ~sequence.voices.choose.bufnum
    //         ]),
    //         particle: (mass: 0.5),
    //     ),
    // ],
    20: [
        (wait:3,
            info: "Physics environment change",
            message: \physics, params: [\drag, 0.5]),
        (message: \physics, params: [\repulsion, 10]),
        (message: \physics, params: [\maxVel, 150]),
    ],
    // 22: [
    //     (
    //         info: "INTRO: stop voices",
    //         message: \task, name: \voices, act: 0
    //     ),
    //     (
    //         message: \physics, params: [audioIn: false]
    //     )
    // ],
    // 30: [
    //     (
    //         info: "INTRO: __analog cutoff= -1",
    //         message: \task, name: \introAnalogCutoff, act: 1
    //     ),
    // ],
    31: [
        ( // Remove all objects.
            wait: 60,
            info: "SCI-FI",
            message: \action, params: [\remove, \all]
        ),
        ( // Stop schedule with sporadic \sr__e__analog, cutoff= -1
            info: "Remove all, stop sched, particles OFF",
            message: \task, name: \introAnalogCutoff, act: 0
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
        ( // remove noisy synth group from server
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
            synth: (name: \sr__e__analog, params: [\att, 40, \rel, 20]),
            particle: (mass: 1, spring: 0, x: 300, y: 300, z: 250),
        ),
        (
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 40, \rel, 20]),
            particle: (mass: 1, spring: 0, x: 470, y: 300, z: 250)
        )
    ],
    32: [
        (
            wait: 0.5,
            info: "SCI-FI: Remove all",
            message: \action,  params: [\remove, \all]
        ),
        ( // switch mutual attraction off
            message: \physics, params: [\mutualAttraction, 0]
        ),
        (
            info: "Schedule sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 1
        ),
        (
            info: "heavy __analog - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__analog,
            params: [\bufnum, ~sequence.scales[0].bufnum, \att, 2 + 1.0.rand2, \rel, 5, \threshold, 0.5]),
            particle: (mass: 1, spring: 1, x: 300, y: 300, z: 550)
        ),
    ],
    33: [
        (
            wait: 0.1,
            info: "SCI-FI: heavy __analog 2",
            message: \particle,
            synth: (name: \sr__e__analog,
            params: [\bufnum, ~sequence.scales[0].bufnum, \att, 2 + 1.0.rand2, \rel, 5, \threshold, 0.5]),
            particle: (mass: 1, spring: 1, x: 470, y: 300, z: 550)
        ),
    ],

    34: [
        (
            info: "INTRO: heavy bass 1",
            wait: 5,
            message: \g_new,
            id: \intro_heavy_bass1,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 16, // getting signal from synth
                    \outbus, ~outbus, // to main output
                \azimuth, -0.5pi],
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 16, // feeding into spatilizer
                    \ax, 1, \distance, 0, \velocity, 0.8, \att, 1,
                    \attenuate, 0.2,
                    \offset, 33,
                    \bufnum, ~sequence.scales[0].bufnum
                ],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.25, \mul, 0.2, \add, 0.8, \outbus, 0],
                ["/n_map", \group_id, \velocity, 0],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.5, \mul, 0.1, \add, 0.1, \outbus, 2],
                ["/n_map", \group_id, \az, 2],
            ]
        )
    ],

    // XXX
    // + improve kick drum
    // + add bass to drumline (maybe __lowe as a bass instrument?)
    // + form drum line better (logically) structured
    // - more vivid off-beat
    // - more interesting syncopes
    // + why \gate, 0 doesn't switch drumline off??
    // - compose drum line for ~5min
    // - volume control in HEAVY!!!

    35: [
        (
            wait: 300,
            info: "SCI-FI: drum line",
            message: \g_new,
            id: \scifi_drumline,
            params: [
                ["/s_new", \scifi_drumline, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 0, \amp, 0.05,
                    \att, 20
                ]
            ]
        ),
    ],
    36: [
        (
            wait: 300,
            info: "METAL: Change scale",
            message: \n_set,
            synth: (
                params: [
                    \bufnum, ~sequence.scales[1].bufnum,
                    \threshold, 0.3,
                    \scope, 24,
                    \offset, 24
                ]
            )
        ),
        ( // change scale to bass
            message: \g_free, id: \intro_heavy_bass1, params: [\release, 10]
        ),
        (
            info: "INTRO: heavy bass 2",
            message: \g_new,
            id: \intro_heavy_bass2,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 16, // getting signal from synth
                    \outbus, ~outbus, // to main output
                    \azimuth, -0.5pi],
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 16, // feeding into spatilizer
                    \ax, 1, \distance, 0, \velocity, 1, \att, 10,
                    \amp, 0.4,
                    \bufnum, ~sequence.scales[0].bufnum
                ],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.25, \mul, 0.5, \add, 0.5, \outbus, 0],
                ["/n_map", \group_id, \velocity, 0],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.25, \mul, 0.1, \add, 0.1, \outbus, 2],
                ["/n_map", \group_id, \az, 2],
            ]
        ),
        (
            info: "Stop sporadic __pulse",
            message: \task, name: \sporadicPulse, act: 0
        ),
    ],
    37: [
        (
            info: "METAL-TO-FREE: reset to chromatic scale",
            message: \n_set,
            synth: (
                params: [
                    \bufnum, Buffer.sendCollection(~scsynth, Scale.chromatic.degrees[..4]).bufnum,
                ]
            )
        ),
    ],
    40: [
        (
            info: "HEAVY: Reset scale",
            message: \n_set,
            synth: (
                params: [\bufnum, nil]
            )
        ),
        (
            info: "Light __lowe ~heaviness",
            message: \particle,
            synth: (name: \sr__e__lowe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
            particle: (mass: 0.8, spring: 1, x: 470, y: 300, z: 250)
        ),
    ],
    45: [
        (
            info: "One more __analog w/cutoff",
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 2, \rel, 10, \cutoff, -1]),
            particle: (age: inf, mass: 0.7, spring: 1)
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
    50: [
        (
            info: "AIRY",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __probe - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10, \bufnum, ~sequence.scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    55: [
        (
            info: "AIRY: heavy __probe 2",
            message: \particle,
            synth: (name: \sr__e__probe, params: [\att, 2 + 1.0.rand2, \rel, 10, \bufnum, ~sequence.scales[0].bufnum]),
            particle: (age: inf, mass: 0.9, spring: 1),
        ),
        (
            info: "Schedule sporadic __cmb & __melo",
            message: \task, name: \sporadicCMB, act: 1
        ),
        (
            message: \task, name: \sporadicMelo, act: 1
        ),
        (
            info: "Schedule scale switch",
            message: \task, name: \switchScale, act: 1
        )
    ],
    60: [
        ( // Remove all objects.
            message: \action,  params: [\remove, \all]
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
        ),
    ],
    70: [
        (
            info: "ELECTRO SOLO",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy __melo - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    71: [
        (
            info: "heavy __melo 2",
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 5.0.rand, \rel, 8, \bufnum, ~sequence.scales[1].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    80: [
        (
            info: "BREAKS",
            message: \action,  params: [\remove, \all]
        ),
        ( // IMPORTANT! switchScale sends scales as buffers to all nodes
            // It should be stopped before starting granWave to prevent
            // sending scales instead of samples.
            info: "Stop all schedules",
            message: \task, name: \switchScale, act: 0
        ),
        (
            message: \task, name: \sporadicCMB, act: 0
        ),
        (
            message: \task, name: \sporadicMelo, act: 0
        ),
        (
            info: "heavy __entro + TAP for __radio",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    81: [
        (
            info: "heavy __radio 2",
            message: \particle,
            synth: (name: \sr__e__radio),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    82: [
        (
            info: "BREAKS",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __entro - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    83: [
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
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __gauss - TAP twice for 2!",
            message: \particle,
            synth: (name: \sr__e__gauss, params: [\att, 100, \rel, 16, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    91: [
        (
            info: "heavy __gauss 2",
            message: \particle,
            synth: (name: \sr__e__gauss, params: [\att, 100, \rel, 16, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],
    92: [
        ( // Remove all objects.
            info: "OUTRO",
            message: \action,  params: [\remove, \all]
        ),
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
            synth: (name: \sr__e__pulse, params: [\att, 120, \rel, 10, \ca, 5, \bufnum, ~sequence.scales[3].bufnum]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],
    98: [
        (
            // very rough draft for the last groove
            info: "GROOVE back",
            message: \g_new,
            id: \scene_groove,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \distance, 0.2,
                    \route, 14, // getting signal from synth
                    \outbus, ~outbus], // to main output
                ["/s_new", \sr__e__plane, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 14, // feeding into spatilizer
                    \velocity, 0.5],
                ["/s_new", \sr__k__keyscale, \next_node_id, 0, \group_id, \bufnum, ~sequence.scales[0].bufnum,
                    \add, 16, \outbus, 0],
                ["/n_map", \group_id, \freq, 0],
                ["/s_new", \sr__k__saw, \next_node_id, 0, \group_id, \lfo, 5, \mul, 0.2, \add, 0.3, \outbus, 1],
                ["/n_map", \group_id, \velocity, 1],

                // modulate note
                ["/s_new", \sr__k__pulse,
                    \next_node_id, 0, \group_id, \lfo, 5, \mul, 0.2, \add, 0.2, \outbus, 2],
                ["/n_map", \group_id, \val, 2], // map modulator's value to another modulator's output

                // modulate amp
                ["/s_new", \sr__k__saw,
                    \next_node_id, 0, \group_id, \lfo, 5,
                    \mul, 0.5, \add, 0.5, // for sharper use \mul, 0.25, \add, 0.75
                    \outbus, 3],
                ["/n_map", \group_id, \amp, 3],

                // modulate azimuth
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.08,
                    \mul, 0.5pi, \add, -0.5pi, // for full circle: \mul, 1pi and no add
                    \outbus, 4],
                ["/n_map", \group_id, \azimuth, 4], // map modulator's value to another modulator's output

                // ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.25, \add, 0.5, \outbus, 2],
                // ["/n_map", \group_id, \velocity, 2],
                // ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.01, \mul, 0.1, \add, 0.1, \outbus, 3],
                // ["/n_map", \group_id, \az, 3]

                // // tune
                // s.queryAllNodes
                // s.sendMsg("/n_set", 1009, \mul, 0.5, \add, 0.5)
                // s.sendMsg("/n_set", 1009, \lfo, 5)

            ]
        )
    ],
    99: [
        (
            info: "FIN",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Remove all, particles OFF",
            message: \physics, params: [particles: 0]
        ),
        (
            info: "Stop main scheduler",
            message: \task, name: \main_scheduler, act: 0
        )
    ]
);


// Tasks dictionary.
//
~sequence.tasks = (
    main_scheduler: Task({
        //
        // main schedule
        // XXX
        // schedule it 1min after start or sthn like that!
        //
        // collects waitingTimes and their waiting times
        var waitList, waitingTimes=List.new;

        ~sequence.events.keys.asArray.sort.do { |eventKey|
            if (eventKey.asInteger != 0) {
                waitList = List.new;
                ~sequence.events[eventKey].do { |message|
                    // it is enough that one message in n event would contain \wait key,
                    // if there are more than one message contains that, only the biggest
                    // one is being taken intto consideration.
                    if (message.keys.includes(\wait)) {
                        waitList.add(message[\wait].asFloat)
                    };
                };
                if (waitList.size > 0) {
                    waitingTimes.add(waitList.maxItem)
                } {
                    waitingTimes.add(30) // default waiting time
                };
            };
        };

        waitingTimes.do { |wait|
            ~sendMessage.('/action', [\event, 1]);
            wait.wait;
        }
    }),

    randomParticles: Task({
        var key, next;
        var particleParams = [ // list of acceptable configurations
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.3, \partAgeThresh, 1.67, \partInitAccel, 30 ],
            [                           \partSigmoidRatio, 0.7, \partAgeThresh, 3.20, \partInitAccel, 10 ],
            [\partSynth, \sr__e__melo,  \partSigmoidRatio, 0.7, \partAgeThresh, 0.78, \partInitAccel, 2.0],
            [\partSynth, \sr__e__cmb,   \partSigmoidRatio, 0.4, \partAgeThresh, 0.20, \partInitAccel, 2.0],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.7, \partAgeThresh, 1.08, \partInitAccel, 10 ],
            [\partSynth, \sr__e__pulse, \partSigmoidRatio, 0.2, \partAgeThresh, 1.03, \partInitAccel, 10 ],
            [\partSynth, \sr__e__noisy, \partSigmoidRatio, 0.2, \partAgeThresh, 1.67, \partInitAccel, 1.0],
        ];
        inf.do { |i|
            2.do { |j|
                key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.3, 0.6, 0.1]);
                next = msetObjSeq.next(key);
                next = (next + rand2(next * 0.25));
                ~sendMessage.(\physics, particleParams[i % particleParams.size]);
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
        var key, next, synth, x, y, z, mass, age, node;
        loop {
            key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.1, 10, 1].normalizeSum);
            dictObjSeq[key.asInteger][0].choose.do{ |i|
                next = msetObjSeq.next(key);
                age = next * (1 + (1/(next.pow(0.33))));
                mass = next.sqrt.clip(0.1, 0.3);
                synth = (
                    name: [\sr__e__humm, \sr__e__radio][i % 2], // alternate
                    params:[
                        \att, rrand(1, 2),
                        \bufnum, ~sequence.scales[4].bufnum
                    ]
                );
                ~sendParticle.(
                    synth: synth,
                    particle: (mass:mass, age:age)
                );

                if (0.7.coin) {
                    synth = (
                        name: [\sr__e__lowe, \sr__e__radio, \sr__e__humm].wchoose([0.6, 0.2, 0.2])
                    );
                    ~sendParticle.(
                        synth: synth,
                        particle: (mass:mass, age:age + ((age * 0.25).rand2))
                    );
                };
                next.wait;
            };
            0.01.wait;
        }
    }),
    voices: Task({
        var buff, synth, age, x, y, z, prob=0.2;
        inf.do { |j|
            buff = ~sequence.voices[j % ~sequence.voices.size];
            age = buff.numFrames / buff.numChannels / buff.sampleRate;
            #x, y, z = { rrand(~worldSize, ~worldSize * ([0.1, 0.9].choose)) } ! 3;

            case
            // when voices are introduced, they should be clearly recognizable
            { j <= 5 } {
                synth = \sr__g__loop
            }
            { (j > 5) && (j <= 10) } {
                synth = [\sr__g__loop, \sr__g__loopdel, \sr__g__unst].choose
            }
            { j > 10 } { // later on "smooth them out" into a voice meshup
                // appear closer to the center of the world
                #x, y, z = { (~worldSize / 2 + rand2(~worldSize * 0.15))} ! 3;
                prob = 0.6; // bigger chance that the next sample will cross with the current one
                synth = [\sr__g__loop, \sr__g__unst, \sr__g__reg].wchoose([0.5, 0.3, 0.2]);

                // occasionally send a light __scratch with the same sample and age
                if (0.3.coin) {
                    ~sendParticle.(
                        particle: (mass:0.1, x:x, y:z, z:z, age:age),
                        synth: (
                            name:\sr__g__scratch,
                            params:[\att, 3, \bufnum, buff.bufnum]
                        )
                    );
                };
            };

            // main "voice particle"
            ~sendParticle.(
                particle: (mass:0.5, x:x, y:z, z:z, age:age),
                synth: (
                    name:synth,
                    params:[\att, 2, \bufnum, buff.bufnum]
                )
            );
            // vary waiting time - every now and then send the next particle
            // without waiting until the end of the sample
            if (prob.coin) { (age * 0.25).wait } { (age + rrand(4, 10)).wait }
        }
    }),
    introAnalogCutoff: Task({
        loop {
            ~sendParticle.(
                particle: (mass:0.6, age:rrand(3, 4),
                    x:(1.0.sum3rand * 100).abs + [100, 500].choose,
                    y:(1.0.sum3rand * 50).abs,
                    z:(1.0.sum3rand * 150).abs + 100
                ),
                synth: (name:\sr__e__analog, params:[\cutoff, -1, \att, 0.2, \rel, rrand(4, 6)])
            );
            (10 + 2.0.rand2).wait;
        }
    }),
    sporadicPulse: Task({
        var x, y, z;
        loop {
            #x, y, z = ({ (1.0.sum3rand * 150).abs + 100 } ! 3);
            (20 + rand2(20 * 0.25)).wait;
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: rrand(2.7, 5.0), mass: 0.9, spring:[1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__pulse, params: [\att, 2, \rel, 3]));
            (20 + rand2(20 * 0.5)).wait;
        }
    }),
    sporadicCMB: Task({
        var x, y, z;
        loop {
            #x, y, z = ({ (1.0.sum3rand * 150).abs + 100 } ! 3);
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: rrand(2, 5), mass: 0.9, spring: [1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__cmb, params: [\att, 1.5, \rel, 3]));
            (20 + rand2(20 * 0.25)).wait;
        }
    }),
    sporadicMelo: Task({
        var x, y, z;
        loop {
            #x, y, z = ({ (1.0.sum3rand * 150).abs + 100 } ! 3);
            (20 + rand2(20 * 0.25)).wait;
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: rrand(5, 10), mass: 0.9, spring: [1, 0].wchoose([0.7, 0.3])),
                synth: (name: \sr__e__melo, params: [\att, 1.5, \rel, 3, \bufnum, ~sequence.scales[0].bufnum]));
            ((20 + rand2(20 * 0.25))/2).wait;
        }
    }),
    switchScale: Task({
        var sca = ~sequence.scales[0..1];
        inf.do{ |i|
            s.sendMsg("/n_set", nil, \bufnum, sca[i % sca.size].bufnum);
            (1..3).choose.wait;
            s.sendMsg("/n_set", nil, \bufnum, nil);
            (60..120).choose.wait;
        }
    }),
);

CmdPeriod.doOnce({
    // Free buffers.
    guideBuff.free;
});


// sequence specific synths
SynthDef(\scifi_drumline, {
    arg route=0, amp=1, gate=1, att=1, rel=1, ca=3, cr= -3;

    var measure = 1/16!10 * 2;
    var rhythmTrig = {
        TDuty.ar(Dseq(measure, inf), 0,
            Dseq([
                // off-beat
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 1], 1),
                Dwhite(0.5, 1, 71) // 71 = 18 cycles * 4 - 1 empty; (old - inf)
            ], 1)
        )
    }!2;
    var kickTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                // off-beat
                Dseq([0, 0, 0, 0, 1, 1, 0, 0, 1, 1], 1),
                // main line
                Dseq([
                    // fig 1 - main line
                    Dseq([Dwrand([0, 1], [0.2, 0.8], 1), 0, 1, 0, 0, 0, 1, 1, 0, 0], 3),
                    Dxrand([
                        // fig 2 - syncope 1
                        Dseq([0, 0, 1, 0, 0, 1, 1, 1, 0, 0], 1),
                        // fig 3 - syncope 2
                        Dseq([0, 1, 0, 0, 1, 0, 0, 1, 0, 0], 1),
                        // fig 4 - syncope 3
                        Dseq([0, 1, 0, 0, 1, 1, 0, 0, 1, 1], 1),
                    ], 1),
                ], 4),
                // intermission
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1),
            ], 4)
        )
    }!2;
    var snareTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                // off-beat
                Dseq([0, 0, 0, 0, 0, 0, 1, 0, 1, 1], 1),

                Dseq([
                    // fig 1 - main line
                    Dseq([0, 0, 0, 1, 0, 0, 0, 0, 1, 0], 3),
                    Dxrand([
                        // fig 2 - syncope 1
                        Dseq([1, 1, 0, 0, 0, 1, 0, 0, 1, Drand([0, 1], 1)], 1),
                        // fig 3 - syncope 2
                        Dseq([1, 0, 0, 1, 0, 0, 1, 0, 1, Drand([0, 1], 1)], 1),
                        // fig 4 - syncope 3
                        Dseq([0, 0, 1, 0, 0, 0, 1, 0, 1, 1], 1),
                    ], 1),
                ], 4),
                // intermission
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1),
            ], 4)
        )
    }!2;
    var snareNatTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                // silent
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 5),
                // fig 1 - main line
                Dseq([0, 0, 0, 0, 0, 1, Dwrand([0, 1], [0.7, 0.3], 1), 0, 0, 1], 12),
                // intermission
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1),
            ], 4)
        )
    }!2;
    // var bassTrig = {
    //     Duty.ar(
    //         Dseq([1/8, 1/4, 1/16, 1/16, 1/4, 1/8, 1/4, 1/16, 1/16], inf) * 2,
    //         0,
    //         Dseq([
    //             Dseq([
    //                 // fig 1 - main line
    //                 Dseq([0, 3, 7, 10, 0, 0, 3, 7, 10]+24, 3),
    //                 Dseq([0, 1, 3, 7,  8, 1, 3, 7, 8 ]+36, 1),
    //             ], 4),
    //             Dseq([0, 1, 3, 7,  8, 0, 3, 7, 10]+48, 4),
    //         ], inf).midicps
    //     )
    // }!2;
    var kickFreq = #[58.0936, 47.3074, 10.2712, 57.8168, 75.0203];
    var kick = BPeakEQ.ar(
        SinOsc.ar(kickFreq, 0, 1/kickFreq.size), 1900, 1, 12.0
    ) * EnvGen.ar(Env([0, 1, 0.4, 0], [0, 0.2, 0.01], -5), kickTrig.abs)!2
    +
    LPF.ar(WhiteNoise.ar(Decay2.ar(kickTrig * LFNoise1.ar(8, 0.5, 0.5), TRand.ar(0.02, 0.3, kickTrig), 0.1)), 1500);
    var snareFreq = #[ 81.5224, 163, 244.3903, 326.7002, 407.7456 ];
    var snareMul = [0.05, 0.65, 0.1, 0.04, 0.01];
    var snare = (
        LPF.ar(
            Pulse.ar(snareFreq, 0.5, snareMul.sum),
            EnvGen.ar(Env.perc(0.05, 0.2, 0.2, -4), snareTrig)!2 * 3000 + 30
        ) * EnvGen.ar(Env.perc(0.05, 0.7, 1, -4), snareTrig)!2
    )
    + AllpassN.ar(
        BPF.ar(HPF.ar(WhiteNoise.ar(1), 500), 1000), 0.05, [0.05.rand, 0.05.rand], 4
    ) * EnvGen.ar(Env.perc(0.01, 0.3, 1, -3), snareTrig);
    var snareNat = (
        LPF.ar(
            Pulse.ar(snareFreq, 0.5, snareMul*0.6),
            EnvGen.ar(Env.perc(0.05, 0.2, 0.2, -4), snareNatTrig)!2 * 3000 + 30
        ) * EnvGen.ar(Env.perc(0.05, 0.7, 1, -4), snareNatTrig)!2
    )
    + AllpassN.ar(
        BPF.ar(HPF.ar(WhiteNoise.ar(0.35), 500), 1500), 0.05, [0.05.rand, 0.05.rand], 4
    ) * EnvGen.ar(Env.perc(0.01, 0.3, 1, -3), snareNatTrig);
    var hat = HPF.ar(
        LPF.ar(
            WhiteNoise.ar(
                TWChoose.ar(rhythmTrig, [
                    Decay2.ar(rhythmTrig * LFNoise1.ar(8, 0.5, 0.5), 0.02, 0.1),
                    Decay2.ar(rhythmTrig * LFNoise1.ar(8, 0.5, 0.5), 0.5, 0.1)
                ], [0.8, 0.2])
            ), 6000
        ),
        TRand.ar(1000, 8000, rhythmTrig)
    );

    var signal, out;

    // var bass = LFSaw.ar((1..5) * bassTrig, LFNoise1.ar(1, 1, 1))
    // + Impulse.ar(
    //     SinOsc.ar((4..8) * bassTrig).exprange(0.3, 300)
    // );
    // bass = RLPF.ar(Mix.ar(bass), 125, 0.8);
    // bass = bass * EnvGen.ar(Env.adsr(0.01, 0.3, 0.2, 0.2, 0.2), bassTrig.sign);

    signal = FreeVerb.ar(
        MidEQ.ar(
            hat
            +
            kick
            +
            snare
            +
            snareNat
            // +
            // bass
            , 14000, 0.7, 8
        ),
        0.05, 0.13, 0.2);
    out = Limiter.ar(signal, amp) * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]),
        gate: gate, doneAction: 2
    );
    Out.ar(route, out);
}).send(s);
)