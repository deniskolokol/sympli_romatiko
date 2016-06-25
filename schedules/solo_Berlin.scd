// solo concert for SPEKTRUM, Berlin

//
// main idea
// adapt ~/Documents/dev_music/utils/markov_signs.scd
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
// ~/Music/CD_cassette_vynil/Compilations/Egypt - Echoes Of The Nile/12 Rhythmic Improvisation.m4a
// samples - ~/Music/material/Drum samples/513TubeDrumHits_Wav_SP/Samples/


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
    #[0,4,6,8,11], // Purvi
    #[0,4,6,9,11], // Marva
    #[0,4,7,8,11], // Bhairav
    #[0,4,7,9,10], // Ahirbhairav
].do { |c, i|
    ~sequence.scales.add(Buffer.sendCollection(~scsynth, c));
};

~sequence.events = (
    // 0: [
    //     (
    //         // WARNING!
    //         // call for main scheduler should always be called first (key 0)
    //         info: "CALL main_scheduler",
    //         message: \task, name: \main_scheduler, act: 1
    //     )
    // ],
    5: [
        (
            info: "Remove all before start\n Apply initial settings",
            wait: 0.5,
            message: \action,  params: [\remove, \all],
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
    6: [
        (
            info: "INTRO, no objects, only .kr buses",
            wait: 90,
            message: \g_new,
            id: \intro_bundle,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 14, // getting signal from synth
                \outbus, ~outbus], // to main output
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 14, // feeding into spatilizer
                \velocity, 0.5, \att, 40, \bufnum, ~sequence.scales[4].bufnum],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.2, \mul, 1pi, \outbus, 0],
                ["/n_map", \group_id, \azimuth, 0],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.08, \mul, 0.3, \add, 0.7, \outbus, 1],
                ["/n_map", \group_id, \distance, 1],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.1, \mul, 0.25, \add, 0.5, \outbus, 2],
                ["/n_map", \group_id, \velocity, 2],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \lfo, 0.01, \mul, 0.1, \add, 0.1, \outbus, 3],
                ["/n_map", \group_id, \az, 3]
            ]
        )
    ],
    7: [
        (
            wait: 90,
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
            wait: 20,
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "INTRO: objects",
            message: \task, name: \intro, act: 1
        ),
        (
            info: "INTRO: long noisy",
            wait: 5,
            message: \g_new,
            id: \intro_noisy,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 15, // getting signal from synth
                \outbus, ~outbus], // to main output
                ["/s_new", \sr__e__noisy, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 15, // feeding into spatilizer
                \velocity, 0.5, \att, 60],
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
            wait: 120,
            message: \task, name: \voices, act: 1
        ),
    ],
    16: [
        (
            info: "INTRO: voices background",
            wait: 120,
            message: \particle,
            synth: (name: \sr__g__reg, params: [
                \ca, 5, \att, rand(40, 60), \rel, 10, \bufnum, ~sequence.voices.choose.bufnum
            ]),
            particle: (mass: 0.5),
        ),
        (
            message: \particle,
            synth: (name: \sr__g__drone, params: [
                \ca, 5, \att, rand(80, 120), \rel, 10, \bufnum, ~sequence.voices.choose.bufnum
            ]),
            particle: (mass: 0.5),
        ),
    ],
    20: [
        (
            wait: 3,
            info: "Physics environment change",
        message: \physics, params: [\drag, 0.5]),
        (message: \physics, params: [\repulsion, 10]),
        (message: \physics, params: [\maxVel, 150]),
        (message: \physics, params: [audioIn: false])
    ],
    30: [
        (
            info: "INTRO: __analog cutoff= -1",
            message: \task, name: \introAnalogCutoff, act: 1
        ),
    ],
    31: [
        ( // Remove all objects.
            wait: 60,
            info: "SCIFI",
            message: \action, params: [\remove, \all]
        ),
        ( // Stop schedule with sporadic \sr__e__analog, cutoff= -1
            info: "Remove all, stop sched, particles OFF",
            message: \task, name: \introAnalogCutoff, act: 0
        ),
        ( // stop voices
            message: \task, name: \voices, act: 0
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
            info: "SCIFI: remove intro group from server",
            wait: 10,
            message: \g_free, id: \intro_bundle, params: [\release, 80]
        ),
    ],
    33: [
        (
            wait: 0.5,
            info: "SCIFI: Remove all",
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
            info: "heavy __analog 1",
            message: \particle,
            synth: (name: \sr__e__analog,
            params: [\bufnum, ~sequence.scales[0].bufnum, \att, 2 + 1.0.rand2, \rel, 5, \threshold, 0.5]),
            particle: (mass: 1, spring: 1, x: 300, y: 300, z: 550)
        ),
    ],
    34: [
        (
            wait: 0.5,
            info: "SCIFI: heavy __analog 2",
            message: \particle,
            synth: (name: \sr__e__analog,
            params: [\bufnum, ~sequence.scales[0].bufnum, \att, 2 + 1.0.rand2, \rel, 5, \threshold, 0.5]),
            particle: (mass: 1, spring: 1, x: 470, y: 300, z: 550)
        ),
        (
            info: "SCIFI: heavy bass 1",
            message: \g_new,
            id: \scifi_heavy_bass1,
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
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.5, \mul, 0.1, \add, 0.1, \outbus, 1],
                ["/n_map", \group_id, \az, 1],
            ]
        )
    ],
    35: [
        (
            wait: 215,
            info: "SCIFI: drum line",
            message: \g_new,
            id: \scifi_drumline,
            params: [
                ["/s_new", \scifi_drumline, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 0, \att, 10,
                    \amp, 0.07,
                ]
            ]
        ),
    ],
    36: [
        (
            wait: 180,
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
            message: \g_free, id: \scifi_heavy_bass1, params: [\release, 10]
        ),
        (
            info: "SCIFI: heavy bass 2",
            message: \g_new,
            id: \scifi_heavy_bass2,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 17, // getting signal from synth
                    \outbus, ~outbus, // to main output
                \azimuth, -0.5pi],
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 17, // feeding into spatilizer
                    \ax, 1, \distance, 0, \velocity, 1, \att, 10,
                    \amp, 0.4,
                    \bufnum, ~sequence.scales[1].bufnum
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
        (
            info: "add mega-bass with no scale",
            message: \particle,
            synth: (name: \sr__e__lowe,
            params: [\att, 10, \rel, 5]),
            particle: (mass: 1, spring: 0, x: 470, y: 600, z: 550)
        ),
    ],
    37: [
        (
            info: "SCIFI: release drum line",
            wait: 1,
            message: \g_free, id: \scifi_drumline, params: [\release, 1]
        ),
    ],
    40: [
        (
            info: "HEAVY: Reset scale",
            wait: 1,
            message: \n_set,
            synth: (
                params: [\bufnum, nil]
            )
        ),
        // XXX - bass
        // (
        //     info: "Light __lowe ~heaviness",
        //     message: \particle,
        //     synth: (name: \sr__e__lowe, params: [\att, 2 + 1.0.rand2, \rel, 10]),
        //     particle: (mass: 0.8, spring: 1, x: 470, y: 300, z: 250)
        // ),
    ],
    45: [
        (
            info: "One more __analog w/cutoff",
            wait: 0.5,
            message: \particle,
            synth: (name: \sr__e__analog, params: [\att, 60, \rel, 10, \cutoff, -1, \amp, 0.5]),
            particle: (age: inf, mass: 0.8, spring: 1)
        ),
    ],
    46: [
        (
            info: "Add heavy __therem 1",
            wait: 0.5,
            message: \particle,
            synth: (name: \sr__e__therem, params: [\att, 2, \rel, 10, \amp, 0.7]),
            particle: (age: inf, mass: 0.8, spring: 1),
        )
    ],
    47: [
        (
            info: "heavy __therem 2",
            wait: 60,
            message: \particle,
            synth: (name: \sr__e__therem, params: [\att, 2, \rel, 10, \amp, 0.7]),
            particle: (age: inf, mass: 0.8, spring: 1)
        ),
    ],

    // XXX
    // There should be some sign before switching to AIRY

    50: [
        (
            info: "AIRY",
            wait: 0.5,
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __probe 1",
            message: \particle,
            synth: (
                name: \sr__e__probe,
                params: [\att, 3, \rel, 10, \bufnum, ~sequence.scales[5].bufnum]
            ),
            particle: (age: inf, mass: 0.9, spring: 1)
        ),
    ],
    51: [
        (
            info: "AIRY: heavy __probe 2",
            wait: 60,
            message: \particle,
            synth: (
                name: \sr__e__probe,
                params: [\att, 3, \rel, 10, \bufnum, ~sequence.scales[5].bufnum]
            ),
            particle: (age: inf, mass: 0.9, spring: 1),
        ),
        (
            info: "Schedule __cmb & __melo",
            wait: 180,
            message: \task, name: \randomCMBMelo, act: 1
        ),
    ],
    // 56: [
    //     (
    //         info: "Schedule __cmb & __melo",
    //         wait: 180,
    //         message: \task, name: \randomCMBMelo, act: 1
    //     ),
    //     (
    //         info: "AIRY: background-1",
    //         message: \g_new,
    //         id: \airy_bg_plane1,
    //         params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
    //             ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
    //                 \depth, ~depth,
    //                 \route, 18, // getting signal from synth
    //                 \outbus, ~outbus, // to main output
    //             \azimuth, -0.5pi],
    //             ["/s_new", \sr__e__plane, \next_node_id, 0, \group_id, // add synth to new group's head
    //                 \route, 18, // feeding into spatilizer
    //                 \offset, 93, \velocity, 0.37,
    //                 \distance, 0.1, \att, 120,
    //                 \bufnum, ~sequence.scales[5].bufnum
    //             ],
    //             ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.2, \mul, 0.5, \add, 0.5, \outbus, 0],
    //             ["/n_map", \group_id, \az, 0],
    //             ["/s_new", \sr__k__pulse, \next_node_id, 0, \group_id, \lfo, 0.067, \mul, 0.375, \add, 0.625, \outbus, 1],
    //             ["/n_map", \group_id, \distance, 1],
    //             ["/s_new", \sr__k__tri, \next_node_id, 0, \group_id, \lfo, 0.5, \mul, 0.5pi, \add, -0.5pi, \outbus, 2],
    //             ["/n_map", \group_id, \azimuth, 2],
    //         ]
    //     ),
    // ],
    60: [
        ( // Remove all objects.
            info: "AIRY",
            wait: 0.5,
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "Heavy __cmb 1",
            message: \particle,
            synth: (name: \sr__e__cmb, params: [\att, 2, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1),
        ),
    ],
    61: [
        (
            info: "AIRY: Heavy __cmb 2",
            wait: 90,
            message: \particle,
            synth: (name: \sr__e__cmb, params: [\att, 2, \rel, 10]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    70: [
        (
            info: "AIRY",
            wait: 0.5,
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "release bass",
            message: \g_free, id: \scifi_heavy_bass2, params: [\release, 10]
        ),
        (
            info: "Heavy __melo 1",
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 0.5, \rel, 8, \bufnum, ~sequence.scales[5].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    71: [
        (
            info: "AIRY: heavy __melo 2",
            wait: 60,
            message: \particle,
            synth: (name: \sr__e__melo, params: [\att, 0.5, \rel, 8, \bufnum, ~sequence.scales[5].bufnum]),
            particle: (age: inf, mass: 1, spring: 1)
        ),
    ],
    72: [
        (
            info: "AIRY: Schedule scale switch",
            wait: 180,
            message: \task, name: \switchScale, act: 1
        ),
    ],
    73: [
        // (
        //     info: "AIRY: release background",
        //     message: \g_free, id: \airy_bg_plane1, params: [\release, 30]
        // ),
        (
            info: "TRANCE: pulse",
            wait: 60,
            message: \g_new,
            id: \airy_trance,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 19, // getting signal from synth
                    \outbus, ~outbus, // to main output
                \azimuth, -0.5pi],
                ["/s_new", \sr__e__analog, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 19, // feeding into spatilizer
                    \offset, 88,
                    \distance, 0.1, \att, 10,
                    \bufnum, ~sequence.scales[5].bufnum
                ],
                ["/s_new", \sr__k__sawperc, \next_node_id, 0, \group_id, \lfo, 4, \mul, 1, \outbus, 0],
                ["/n_map", \group_id, \amp, 0],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.5, \mul, 0.2, \add, 0.8, \outbus, 1],
                ["/n_map", \group_id, \velocity, 1],
            ]
        ),
    ],
    76: [
        (
            info: "TRANCE: pitch",
            wait: 240,
            message: \task, name: \trancePitch, act: 1
        ),
    ],
    80: [
        (
            wait: 1, // 60,
            info: "TRANCE -> BREAK",
            message: \g_new,
            id: \trance_break,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \route, 20, // getting signal from synth
                    \outbus, ~outbus, // to main output
                \azimuth, -0.5pi],
                ["/s_new", \sr__e__analog, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 20, // feeding into spatilizer
                    \offset, 88,
                    \distance, 0.1, \att, 0.1,
                    \bufnum, ~sequence.scales[5].bufnum
                ],
                ["/s_new", \sr__k__breaknoise, \next_node_id, 0, \group_id, \lfo, 1, \mul, 0.75, \outbus, 2],
                ["/n_map", \group_id, \amp, 2],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 5, \mul, 0.5, \add, 0.5, \outbus, 3],
                ["/n_map", \group_id, \az, 3],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 1, \mul, 25, \add, 43, \outbus, 4],
                ["/n_map", \group_id, \offset, 4],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.5, \mul, 0.2, \add, 0.8, \outbus, 5],
                ["/n_map", \group_id, \velocity, 5],
            ]
        )
    ],
    82: [
        (
            info: "BREAKS",
            wait: 0.5,
            message: \action,  params: [\remove, \all]
        ),
        ( // IMPORTANT! switchScale sends scales as buffers to all nodes
            // It should be stopped before starting granWave to prevent
            // sending scales instead of samples.
            info: "Stop all schedules",
            message: \task, name: \switchScale, act: 0
        ),
        (
            message: \task, name: \randomCMBMelo, act: 0
        ),
        (
            message: \task, name: \trancePitch, act: 0
        ),
        (
            message: \g_free, id: \airy_trance, params: [\release, 30]
        ),
        (
            info: "heavy __entro 1",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    85: [
        (
            info: "heavy __radio 2",
            wait: 10,
            message: \particle,
            synth: (name: \sr__e__radio),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    87: [
        (
            info: "BREAKS - entro",
            wait: 0.5,
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "heavy __entro 1",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    88: [
        (
            info: "heavy __entro 2",
            message: \particle,
            synth: (name: \sr__e__entro),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
        // (
        //     wait: 60,
        //     info: "BREAKS: drum line",
        //     message: \g_new,
        //     id: \breaks_drumline,
        //     params: [
        //         ["/s_new", \breaks_drumline, \next_node_id, 0, \group_id,
        //             \route, 0, \amp, 0.05,
        //             \att, 0.1, \freq, 2.5,
        //         ]
        //     ]
        // ),
    ],
    89: [
        (
            info: "BREAKS: free trance_break",
            wait: 140,
            message: \g_free, id: \trance_break, params: [\release, 1]
        )
    ],
    90: [
        (
            info: "GROOVE",
            wait: 1,
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "drum line",
            message: \g_new,
            id: \groove_drumline,
            params: [
                ["/s_new", \groove_drumline, \next_node_id, 0, \group_id, // add synth to new group's head
                    \route, 0, \att, 60,
                    \amp, 0.8],
            ]
        ),
        (
            info: "stop breaks",
            message: \g_free, id: \trance_break, params: [\release, 0.5]
        ),
        // (
        //     info: "stop breaks_drumline",
        //     message: \g_free, id: \breaks_drumline, params: [\release, 0.5]
        // ),
        (
            info: "heavy __gauss 1",
            message: \particle,
            synth: (name: \sr__e__gauss, params: [\att, 10, \rel, 30, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    91: [
        (
            info: "heavy __gauss 2",
            wait: 240,
            message: \particle,
            synth: (name: \sr__e__gauss, params: [\att, 10, \rel, 30, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],
    92: [
        ( // Remove all objects.
            info: "OUTRO",
            wait: 20,
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "release drumline",
            message: \g_free, id: \groove_drumline, params: [\release, 15]
        ),
        (
            info: "heavy __noisy 1",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
    ],
    93: [
        (
            wait: 120,
            info: "heavy __noisy 2",
            message: \particle,
            synth: (name: \sr__e__noisy, params: [\att, 5.0.rand, \rel, 10]),
            particle: (spring: 1, age: inf, mass: 0.9)
        ),
        (
            info: "heavy __pulse with long attack",
            message: \particle,
            synth: (name: \sr__e__pulse, params: [\att, 20, \rel, 20, \ca, 5, \bufnum, ~sequence.scales[3].bufnum]),
            particle: (spring: 1, age: inf, mass: 0.9)
        )
    ],
    // 98: [
    //     (
    //         // very rough draft for the last groove
    //         info: "GROOVE back",
    //         message: \g_new,
    //         id: \scene_groove,
    //         params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
    //             ["/s_new", ~getSpatial.(), \next_node_id, 1, \group_id, // add spatializer to new group's tail
    //                 \depth, ~depth,
    //                 \distance, 0.2,
    //                 \route, 14, // getting signal from synth
    //             \outbus, ~outbus], // to main output
    //             ["/s_new", \sr__e__plane, \next_node_id, 0, \group_id, // add synth to new group's head
    //                 \route, 14, // feeding into spatilizer
    //             \velocity, 0.5],
    //             ["/s_new", \sr__k__keyscale, \next_node_id, 0, \group_id, \bufnum, ~sequence.scales[0].bufnum,
    //             \add, 16, \outbus, 0],
    //             ["/n_map", \group_id, \freq, 0],
    //             ["/s_new", \sr__k__saw, \next_node_id, 0, \group_id, \lfo, 5, \mul, 0.2, \add, 0.3, \outbus, 1],
    //             ["/n_map", \group_id, \velocity, 1],
    //
    //             // modulate note
    //             ["/s_new", \sr__k__pulse,
    //             \next_node_id, 0, \group_id, \lfo, 5, \mul, 0.2, \add, 0.2, \outbus, 2],
    //             ["/n_map", \group_id, \val, 2], // map modulator's value to another modulator's output
    //
    //             // modulate amp
    //             ["/s_new", \sr__k__saw,
    //                 \next_node_id, 0, \group_id, \lfo, 5,
    //                 \mul, 0.5, \add, 0.5, // for sharper use \mul, 0.25, \add, 0.75
    //             \outbus, 3],
    //             ["/n_map", \group_id, \amp, 3],
    //
    //             // modulate azimuth
    //             ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \lfo, 0.08,
    //                 \mul, 0.5pi, \add, -0.5pi, // for full circle: \mul, 1pi and no add
    //             \outbus, 4],
    //             ["/n_map", \group_id, \azimuth, 4], // map modulator's value to another modulator's output
    //
    //             // ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.25, \add, 0.5, \outbus, 2],
    //             // ["/n_map", \group_id, \velocity, 2],
    //             // ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.01, \mul, 0.1, \add, 0.1, \outbus, 3],
    //             // ["/n_map", \group_id, \az, 3]
    //
    //             // // tune
    //             // s.queryAllNodes
    //             // s.sendMsg("/n_set", 1009, \mul, 0.5, \add, 0.5)
    //             // s.sendMsg("/n_set", 1009, \lfo, 5)
    //
    //         ]
    //     )
    // ],
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
                    x: (1.0.sum3rand * 100).abs + [100, 500].choose,
                    y: rrand(~worldSize*0.15, ~worldSize*0.2),
                    z: ~worldSize*0.8
                ),
                synth: (name:\sr__e__analog, params:[\cutoff, -1, \att, 0.2, \rel, rrand(4, 6), \amp, 0.6])
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
            (20 * rrand(0.5, 1.5)).wait;
        }
    }),
    randomCMBMelo: Task({
        var x, y, z, synthName=[\sr__e__cmb, \sr__e__melo];
        inf.do { |j|
            x = ~worldSize * [0.2, 0.8].choose;
            #y, z = ~worldSize * 0.2 ! 2;
            ~sendParticle.(
                particle: (x:x, y:z, z:z, age: rrand(3, 6), mass: 0.9, spring: 1),
                synth: (name: synthName[j % synthName.size] , params: [\att, 1.5, \rel, 3])
            );
            (20 * rrand(0.8, 1.3)).wait;
        }
    }),
    switchScale: Task({
        var sca = ~sequence.scales[5..9];
        inf.do{ |i|
            s.sendMsg("/n_set", nil, \bufnum, sca[i % sca.size].bufnum);
            (6..9).choose.wait;
            s.sendMsg("/n_set", nil, \bufnum, nil);
            (30, 32..60).choose.wait;
        }
    }),
    trancePitch: Task({
        inf.do { |j|
            ~sendMessage.("/action", [\srv_msg, \n_set, \id, \airy_trance, \offset, [24, 36].choose]);
            2.wait;
            ~sendMessage.("/action", [\srv_msg, \n_set, \id, \airy_trance, \offset, [85, 88].choose]);
            (30 * rrand(0.8, 1.3)).wait;
        }
    })
);

CmdPeriod.doOnce({
    // Free buffers.
    guideBuff.free;
});

// sequence specific synths
SynthDef(\scifi_drumline, {
    arg route=0, amp=1, gate=1, att=1, rel=1, ca=6, cr= -3;

    var introN=10;
    var outroN=24;
    var fullN=4; // full cycles of main line + syncope
    var measure = 1/16!10 * 2;
    var rhythmTrig = {
        TDuty.ar(Dseq(measure, inf), 0, Dwhite(0.5, 1, 2278)) //inf))
    }!2;
    var kickTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                // intro silent (hat only)
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], introN-1),
                Dseq([
                    // off-beat
                    Dseq([0, 0, 0, 0, 0, 0, 1, 1, 0, 1], 1),
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
                    Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 3),
                ], fullN),
                // outro silent (hat only)
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], outroN),
                // outro hit
                Dseq([0, 0, 0, 0, 1, 1, 0, 1, 1, 1], 1)
            ], 1)
        )
    }!2;
    var snareTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                // intro silent (hat only)
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], introN-1),
                Dseq([
                    // off-beat
                    Dseq([0, 0, 0, 0, 0, 1, 0, 0, 1, 0], 1),
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
                    Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 3),
                ], fullN),
                // outro silent (hat only)
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], outroN),
                // outro hit
                Dseq([0, 0, 0, 0, 0, 1, 0, 1, 1, 0], 1)
            ], 1)
        )
    }!2;
    var tomTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                // intro silent (hat only)
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], introN + (fullN*4 + 3)),
                Dseq([
                    // off-beat (tom is silent)
                    Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1),
                    Dseq([
                        // fig 1 - main line
                        Dseq([0, 0, 0, 0, 0, 1, Dwrand([1, 0], [0.7, 0.3], 1), 0, 0, 1], 3),
                        Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1),
                    ], 4),
                    // intermission
                    Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 3),
                ], fullN-1),
                // outro silent (hat only)
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], outroN),
                // outro hit
                Dseq([0, 0, 0, 0, 0, 0, 0, 1, 1, 0], 1)
            ], 1)
        )
    }!2;
    var kickFreq = #[58.0936, 47.3074, 10.2712, 57.8168, 75.0203];
    var kick =
    // (
    //     BPeakEQ.ar(
    //         SinOsc.ar(kickFreq, 0, 1/kickFreq.size), 1900, 1, 12.0
    //     )
    //     + SinOsc.ar(
    //         0,
    //         (Sweep.ar(kickTrig, 2pi * [52.8, 740]) + (pi/3)).wrap(-pi, pi),
    //         [2, 0.05]
    //     ).mean.tanh
    // )
    SinOsc.ar(
        0,
        (Sweep.ar(kickTrig, 2pi * [52.8, 740]) + (pi/3)).wrap(-pi, pi),
        [2, 0.05]
    ).mean.tanh
    * EnvGen.ar(Env([0, 0.5, 0.4, 0], [0, 0.2, 0.01], -5), kickTrig.abs)!2
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
        BPF.ar(HPF.ar(WhiteNoise.ar(1), 500), 1500), 0.05, [0.05.rand, 0.05.rand], 4
    ) * EnvGen.ar(Env.perc(0.01, 0.3, 1, -3), snareTrig);
    var tomFreq = snareFreq+66;
    var tom = (
        LPF.ar(
            Pulse.ar(tomFreq, 0.5, snareMul),
            EnvGen.ar(Env.perc(0.05, 0.5, 0.2, -4), tomTrig)!2 * 3000 + 30
        ) * EnvGen.ar(Env.perc(0.05, 0.7, 1, -4), tomTrig)!2
    )
    + AllpassN.ar(
        BPF.ar(HPF.ar(WhiteNoise.ar(0.35), 500), 1500), 0.05, [0.05.rand, 0.05.rand], 4
    ) * EnvGen.ar(Env.perc(0.01, 0.1, 0.5, -6), tomTrig);
    var hat = HPF.ar(
        LPF.ar(
            WhiteNoise.ar(
                TWChoose.ar(rhythmTrig, [
                    Decay2.ar(rhythmTrig * LFNoise1.ar(8, 0.3, 0.5), 0.02, 0.1),
                    Decay2.ar(rhythmTrig * LFNoise1.ar(8, 0.3, 0.5), 0.5, 0.1)
                ], [0.8, 0.2])
            ), 6000
        ),
        TRand.ar(1000, 8000, rhythmTrig)
    );
    var signal = MidEQ.ar(
        hat
        +
        kick
        +
        snare
        +
        tom
        , 14000, 0.7, 3
    );
    var out = Limiter.ar(signal, amp)
    * EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]), gate: gate, doneAction: 2);

    Out.ar(route, out);
}).send(s);


SynthDef(\breaks_drumline, {
    arg route=0, freq=1, amp=1, gate=1, att=1, rel=1, ca=6, cr= -3;

    var measure = 1/16!10 * freq;
    var num = 60;
    var rhythmTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], (num/2).ceil),
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], (num/4).ceil),
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], (num/4).ceil),
                Dseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 1], 1) // hat is only for a final chord
            ], 1)
        )
    }!2;
    var kickTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                Dseq([1, 0, 1, 0, 1, 0, 1, 0, 1, 0], (num/2).ceil),
                Dseq([1, 0, 1, Dwrand([1, 0], [0.1, 0.9], 1), 1, Dwrand([1, 0], [0.1, 0.9], 1), 1, 0, 1, 0], (num/4).ceil),
                Dseq([1, 0.2, 1, 0, 1, 0, 1, 0, 1, 0], (num/4).ceil),
                Dseq([1, 0, 0, 0, 0, 0, 1, 0, 0, 1], 1)
            ], 1)
        )
    }!2;
    var snareTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                Dseq([1, 0, 1, 0, 1, 0, 1, 0, 1, 0], (num/2).ceil),
                Dseq([1, Dwrand([1, 0], [0.1, 0.9], 1), 1, 0, 1, 0, 1, Dwrand([1, 0], [0.1, 0.9], 1), 1, 0], (num/4).ceil),
                Dseq([1, Dwrand([1, 0], [0.3, 0.7], 1), 1, 0, 1, 0, 1, Dwrand([1, 0], [0.3, 0.7], 1), 1, 0], (num/4).ceil),
                Dseq([1, 0, 0, 0, 0, 0, 1, 0, 0, 1], 1)
            ], 1)
        )
    }!2;
    var tomTrig = {
        TDuty.ar(Dseq(measure, inf) * 2, 0,
            Dseq([
                Dseq([1, 0, 1, 0, 1, 0, 1, 0, 1, 0], (num/2).ceil),
                Dseq([1, 0, 1, 0, 1, Dwrand([1, 0], [0.1, 0.9], 1), 1, 0, 1, 0], (num/4).ceil),
                Dseq([1, 0, 1, 0, 1, Dwrand([1, 0], [0.3, 0.7], 1), 1, 0, 1, 0], (num/4).ceil),
                Dseq([1, 0, 0, 0, 0, 0, 1, 0, 0, 1], 1)
            ], 1)
        )
    }!2;
    var kickFreq = #[58.0936, 47.3074, 10.2712, 57.8168, 75.0203];
    var kick =
    // (
    //     BPeakEQ.ar(
    //         SinOsc.ar(kickFreq, 0, 1/kickFreq.size), 1900, 1, 12.0
    //     )
    //     + SinOsc.ar(
    //         0,
    //         (Sweep.ar(kickTrig, 2pi * [52.8, 740]) + (pi/3)).wrap(-pi, pi),
    //         [2, 0.05]
    //     ).mean.tanh
    // )
    SinOsc.ar(
        0,
        (Sweep.ar(kickTrig, 2pi * [52.8, 740]) + (pi/3)).wrap(-pi, pi),
        [2, 0.05]
    ).mean.tanh
    * EnvGen.ar(Env([0, 0.5, 0.4, 0], [0, 0.2, 0.01], -5), kickTrig.abs)!2
    +
    LPF.ar(WhiteNoise.ar(Decay2.ar(kickTrig * LFNoise1.ar(8, 0.5, 0.5), TRand.ar(0.02, 0.3, kickTrig), 0.1)), 1500);
    var snareFreq = #[ 81.5224, 163, 244.3903, 326.7002, 407.7456 ];
    var snareMul = [0.05, 0.65, 0.1, 0.04, 0.01];
    var snare = (
        LPF.ar(
            Pulse.ar(snareFreq, 0.5, snareMul.sum),
            EnvGen.ar(Env.perc(0.05, 0.3, 0.2, -4), snareTrig)!2 * 3000 + 30
        ) * EnvGen.ar(Env.perc(0.05, 0.2, 1, -4), snareTrig)!2
    )
    + AllpassN.ar(
        BPF.ar(HPF.ar(WhiteNoise.ar(1), 500), 1000), 0.05, [0.05.rand, 0.05.rand], 4
    ) * EnvGen.ar(Env.perc(0.01, 0.3, 1, -3), snareTrig);
    var tomFreq = snareFreq+66;
    var tom = (
        LPF.ar(
            Pulse.ar(tomFreq, 0.5, snareMul),
            EnvGen.ar(Env.perc(0.05, 0.3, 0.2, -4), tomTrig)!2 * 3000 + 30
        ) * EnvGen.ar(Env.perc(0.05, 0.2, 1, -4), tomTrig)!2
    )
    + AllpassN.ar(
        BPF.ar(HPF.ar(WhiteNoise.ar(0.35), 500), 1500), 0.05, [0.05.rand, 0.05.rand], 4
    ) * EnvGen.ar(Env.perc(0.01, 0.1, 0.5, -6), tomTrig);
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

    var signal = MidEQ.ar(
        hat
        +
        kick
        +
        snare
        +
        tom
        , 14000, 0.7, 8
    );
    var out = Limiter.ar(signal, amp) * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]),
        gate: gate, doneAction: 2
    );
    Out.ar(route, out);
}).send(s);

SynthDef(\sr__k__breaknoise, {
    arg outbus=0, lfo=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var freq = Duty.kr(SinOsc.kr(lfo, 0, 0.5, 0.5),
        0,
        Dxrand([1, 1.5, 2.5, 3, 4, 10], inf)
    );
    var out = env * LFSaw.ar(freq, 0, mul, add).cubed.neg.clip;
    SendTrig.kr(Impulse.kr(30), trigID, out);
    Out.kr(outbus, out);
}).send(s);


SynthDef(\groove_drumline, {
    arg route=0, amp=1, gate=1, att=1, rel=1, ca=6, cr= -3;
    var t_trig=0;
    var trig = TDuty.kr(
        [0.5, 1, 0.25]/2,
        TDuty.kr(Dser([0.75, 0.75, 0.5]/2, inf))
    );
    var snare = Ringz.ar(
        T2A.ar([trig[0], trig[1]]), [45, 330], [0.5, 0.1], [0.9, 0.1]
    );
    var pulse = Ringz.ar(T2A.ar(trig[2]), 90, 0.2,2).clip*0.2;
    var hat = BPF.ar(
        LFNoise0.ar(8000), 8000, 1, 0.75
    ) * EnvGen.kr(
        Env.perc(0, 0.2, 1, -5), trig[1]
    );
    var rim = BPF.ar(
        LFNoise0.ar(98**2,0.4), 98**2, 1, 0.04
    ) * EnvGen.kr(
        Env.perc(0.2,0,1,-5), trig[1]
    );
    var signal = MidEQ.ar(
        snare
        +
        rim
        +
        hat
        +
        pulse
        , 14000, 0.7, 8
    );
    var out = Limiter.ar(signal, amp) * EnvGen.kr(
        Env.adsr(att, 0.1, 1, rel, curve:[ca, cr]),
        gate: gate, doneAction: 2
    );
    Out.ar(route, out);
}).send(s);
)