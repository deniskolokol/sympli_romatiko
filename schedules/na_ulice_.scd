(
~sequence[\title] = "MOON2: Na ulice wyjsc nie sposob";
[
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 2, 5, 7, 10], // the rest are specific to sequence's parts
].do { |c, i|
    ~sequence.scales.add(Buffer.sendCollection(~scsynth, c));
};
~sequence.events = (
    0: [
        (message: \action,  params: [\remove, \all],
            info: "Remove all before start\n Apply initial settings"),
        (message: \physics, params: [
            \gravX, \default,
            \gravY, \default,
            \gravZ, \default,
            \drag, 0.5,
            \repulsion, 10,
            \maxVel, 150,
            \starMass, \default,
            \particleSystem, 0,
            \springRestLen, 3,
            \springStrength, 0.5,
            \springDamp, 2,
            \mutualAttraction, 0
        ]),
    ],
    10: [
        (
            info: "GROOVE",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "two heavy <gauss>",
            message: \particle,
            synth: (name: "gauss", params: [\attack, 60, \release, 3, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "gauss", params: [\attack, 60, \release, 3, \ca, 5]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand)
        )
    ],
    20: [
        ( // Remove all objects.
            info: "OUTRO",
            message: \action,  params: [\remove, \all]
        ),
        (
            info: "2 heavy <wind>",
            message: \particle,
            synth: (name: "wind", params: [\attack, 5.0.rand, \release, 10]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        ),
        (
            message: \particle,
            synth: (name: "wind", params: [\attack, 5.0.rand, \release, 10]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \r_hand)
        ),
        (
            info: "heavy <pulse> with long attack",
            message: \particle,
            synth: (name: "pulse",
                params: [\attack, 120, \release, 10, \ca, 5, \bufnum, ~sequence.scales[0].bufnum]),
            particle: (spring: 1, age: inf, mass: 0.9, source: \l_hand)
        )
    ],
    99: [
        (
            info: "FIN: remove all",
            message: \action,  params: [\remove, \all]
        ),
    ]
);
)