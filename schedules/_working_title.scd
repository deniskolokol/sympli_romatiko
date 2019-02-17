(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime
var woc = {
    // WOC = WObbly Center.
    (~worldSize / 2) + (~worldSize * 0.01).rand
};

//GLOBAL
~sequence[\title] = "Orbitalna";

// Set constant depth.
~depth = 8;

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
[
    FloatArray[0, 3, 7, 10], // scales[0] is the main scale
    FloatArray[0, 1, 3, 7, 8], // the rest are specific to sequence's parts
    FloatArray[0, 2],
    FloatArray[0, 3],
    FloatArray[1, 3],
].do { |c, i|
    ~sequence.scales.add(Buffer.sendCollection(~scsynth, c));
};

~sequence.events = (
    0: [
        (
            message: \action,  params: [\remove, \all],
            info: "Remove all before start\n Apply initial settings"
        ),
        (
            message: \physics,
            params: [
                \gravX, \default,
                \gravY, \default,
                \gravZ, \default,
                \drag, 0,
                \repulsion, 10,
                \maxVel, 150,
                \starMass, \default,
                \springRestLen, 3,
                \springStrength, 0.5,
                \springDamp, 2,
                \mutualAttraction, \default,
            ]
        ),
    ],
    10: [
        (
            info: "Persistent floating <buzz>",
            message: \particle,
            synth: (
                name: "buzz",
                node: 1100,
                params: [
                    \attack, 20,
                    \release, 20,
                    \ca: 2,
                    \amp, 0.6,
                    \freq, 440,
                ]
            ),
            particle: (
                age: inf,
                mass: 1,
                x: woc.(), y: woc.(), z: woc.())
        ),
        (
            info: "TASK: `startLoop`",
            message: \task, name: \startLoop, act: 1
        ),
    ],
    20: [
        (
            info: "TASK: `magma`",
            message: \task, name: \magma, act: 1
        ),
    ],
    99: [
        (
            info: "FIN: Remove all",
            message: \action,  params: [\remove, \all]
        )
    ]
);

// Tasks dictionary.
//
~sequence.tasks = (
    startLoop: Task({
        var age = 20.2;
        loop {
            ~sendParticle.(
                particle: (mass: 1, spring: 0, age: age, x: woc.(), y: woc.(), z: woc.()),
                synth: (name: "pole",
                    params: [\attack, rrand(1.0, 2.0), \ca, 2, \release, age, \amp, 0.5, \freq, "g 2".notemidi.midicps]
                )
            );
            ~sendParticle.(
                particle: (mass: 1, spring: 0, age: age, x: woc.(), y: woc.(), z: woc.()),
                synth: (name: "pole", params:
                    [\attack, rrand(2.0, 3.0), \ca, 2, \release, age, \amp, 0.5, \freq, "a 2".notemidi.midicps]
                )
            );
            ~sendParticle.(
                particle: (mass: 1, spring: 0, age: age, x: woc.(), y: woc.(), z: woc.()),
                synth: (name: "bass",
                    params: [\attack, 0.1, \ca, 2, \release, age, \amp, 0.7, \freq, "f 3".notemidi.midicps]
                )
            );
            age.wait;
        }
    }),
    magma: Task({
        var age;
        loop {
            #x, y, z = ~worldSize * ({ rrand(0.45, 0.55) } ! 3);
            age = 10;
            ~sendParticle.(
                particle: (mass: 1, age: age * rrand(0.85, 1), x: x, y: y, z: z),
                synth: (
                    name: "moog",
                    params:[\cutoff, -1, \attack, 0.2, \release, rrand(age*0.2, age*0.5)]
                )
            );
            ~sendParticle.(
                particle: (mass: 1, age: age * rrand(0.85, 1), x: x, y: y, z: z),
                synth: (
                    name: "silent",
                )
            );
            age.wait;
        }
    }),
)
)