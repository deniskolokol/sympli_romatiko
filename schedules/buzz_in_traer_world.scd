(
~sequence = (
    title: "Buzz in Traer World",
    events: Dictionary.new,
    tasks: Dictionary.new,
    scales: List.new,
    samples: List.new,
    voices: List.new,
);
[
    FloatArray[0, 1],
    FloatArray[0, 2],
    FloatArray[0, 3],
    FloatArray[0, 3, 5, 7],
    FloatArray[0, 1, 7, 10],
].do { |c, i|
    ~sequence.scales.add(Buffer.loadCollection(s, c));
};


// events
 ~sequence.events = (
    0: [
        (message: \action,  params: [\remove, \all],
            info: "Remove all before start"),
        (message: \audio,   params: [\surround, ~surround],
            info: "Initial settings"),
        (message: \audio,   params: [\depth, ~depth]),
        (message: \physics, params: [\gravX, \default]),
        (message: \physics, params: [\gravY, \default]),
        (message: \physics, params: [\gravZ, \default]),
        (message: \physics, params: [\drag, 0.45]),
        (message: \physics, params: [\repulsion, \default]),
        (message: \physics, params: [\starMass, \default]),
        (message: \physics, params: [\particles, \default]),
        (message: \physics, params: [\mutualAttraction, \default]),
    ],
    5: [
        (
            info: "Constant humm",
            message: \g_new,
            id: \constant_humm,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", "sr__s__" ++ ~surround, \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \inbus, 12, // getting signal from synth
                    \outbus, ~mainOutput // to main output
                ],
                ["/s_new", \sr__e__humm, \next_node_id, 0, \group_id, // add synth to new group's head
                    \outbus, 12, // feeding into spatilizer
                    \velocity, 0.5,
                    \att, 40,
                    \bufnum, ~sequence.scales[3].bufnum,
                    \offset, 24
                ],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 1pi, \outbus, 0],
                ["/n_map", \group_id, \azimuth, 0],

                // distance - further!
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08, \mul, 1.25, \add, 2.75, \outbus, 1],
                ["/n_map", \group_id, \distance, 1],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.1, \mul, 0.25, \add, 0.5, \outbus, 2],
                ["/n_map", \group_id, \velocity, 2],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.01, \mul, 0.1, \add, 0.1, \outbus, 3],
                ["/n_map", \group_id, \az, 3]
            ]
        ),
        (
            info: "Disturbing pulse",
            message: \g_new,
            id: \disturbing_pulse,
            params: [ // Keywords \next_node_id & \group_id are to be substituted by real IDs.
                ["/s_new", "sr__s__" ++ ~surround, \next_node_id, 1, \group_id, // add spatializer to new group's tail
                    \depth, ~depth,
                    \inbus, 13, // getting signal from synth
                    \outbus, ~mainOutput], // to main output
                ["/s_new", \sr__e__pulse, \next_node_id, 0, \group_id, // add synth to new group's head
                    \outbus, 13, // feeding into spatilizer
                    \velocity, 0.5,
                    \att, 120,
                    \bufnum, ~sequence.scales[4].bufnum,
                ],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.05, \mul, 1pi, \outbus, 4],
                ["/n_map", \group_id, \azimuth, 4],

                // distance - stretch!
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.08, \mul, 1.25, \add, 2.75, \outbus, 5],
                ["/n_map", \group_id, \distance, 5],
                ["/s_new", \sr__k__lfnoise1, \next_node_id, 0, \group_id, \freq, 0.05, \mul, 0.4, \add, 0.8, \outbus, 6],
                ["/n_map", \group_id, \velocity, 6],
                ["/s_new", \sr__k__stepnoise, \next_node_id, 0, \group_id, \freq, 0.01, \mul, 0.4, \add, 0.21, \outbus, 7],
                ["/n_map", \group_id, \az, 7]
            ]
        ),
        // ( task for occasional particles: __lowe, __neural and __pulse (with more "natural" velocity))
    ],
);

CmdPeriod.doOnce({
    ~sequence.scales.do  { |buff| buff.free};
});
)