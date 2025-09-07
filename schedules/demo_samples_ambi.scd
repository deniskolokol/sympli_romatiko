(
var samplesDir;
var dictObjSeq, msetObjSeq; // Markov chains creating sequences and obtaining objects' birthtime

//GLOBAL
~sequence[\title] = "DEMO: samples in ambisonics 3D space";

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

samplesDir = "~/Music/MOON2/samples/";
PathName.new(samplesDir +/+ "drums").entries.do { |f, i|
    try { ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
PathName.new(samplesDir +/+ "voices").entries.do { |f, i|
    try { ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
PathName.new("~/Music/material/organic/").entries.do { |f, i|
    try { ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
PathName.new("~/Music/material/organic/").entries.do { |f, i|
    try { ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};
PathName.new("~/Music/solo/unsound_radio_spot/").entries.do { |f, i|
    try { ~sequence.samples.add(Buffer.readChannel(~scsynth, f.fullPath, channels: [0])) }
};



~sequence.events = (
    0: [
        (message: \action,  params: [\remove, \all],
            info: "Remove all before start\n Apply initial settings"),
        (message: \physics, params: [
            \gravX, \default,
            \gravY, \default,
            \gravZ, \default,
            \drag, 0.0,
            \repulsion, 100,
            \starMass, \default,
            \particleSystem, \default,
            \springRestLen, 3,
            \springStrength, 0.5,
            \springDamp, 2,
            \mutualAttraction, 0
        ]),
    ],
    15: [
        (
            info: "INTRO: samples",
            message: \task, name: \samples, act: 1
        ),
    ],
    16: [
        (
            info: "INTRO: samples background",
            message: \particle,
            synth: (name: "greg", params: [
                \ca, 5, \attack, rand(40, 60), \release, 10, \bufnum, ~sequence.samples.choose.bufnum
            ]),
            particle: (mass: 0.5),
        ),
        (
            message: \particle,
            synth: (name: "drone", params: [
                \ca, 5, \attack, rand(80, 120), \release, 10, \bufnum, ~sequence.samples.choose.bufnum
            ]),
            particle: (mass: 0.5),
        ),
    ],
    20: [
        (
            info: "Physics environment change",
            message: \physics,
            params: [\drag, 0.5, \repulsion, 10, \maxVel, 150]
        ),
    ],
    22: [
        (
            info: "INTRO: stop samples",
            message: \task, name: \samples, act: 0
        ),
        (
            message: \physics, params: [audioIn: false]
        )
    ],
    99: [
        (
            info: "FIN: Remove all",
            message: \action,  params: [\remove, \all]
        ),
    ]
);

// Tasks dictionary.
//
~sequence.tasks = (
    samples: Task({
        var buff, synth, age, x, y, z;
		var samplesSequence = ~sequence.samples.scramble;
        inf.do { |j|
			buff = samplesSequence[j % ~sequence.samples.size];

			// each sample should be not longer than 5 sec;
            age = min(buff.numFrames / buff.numChannels / buff.sampleRate, 5.0);
			#x, y, z = [200, 200, 100];
			x = ~worldSize * [0.3, 0.7].choose;
			y = ~worldSize * 0.75;
			z = ~worldSize * [0.3, 0.7].choose;
			// #x, y, z = { rrand(~worldSize, ~worldSize * ([0.2, 0.8].choose)) } ! 3;

			postf("x:%, y:%, z:%\n", x, y, z);

            // main "voice particle"
            ~sendParticle.(
                particle: (mass:0.5, x:x, y:y, z:z, age:age),
                synth: (
                    name: \loop,
                    params:[\attack, 2, \bufnum, buff.bufnum]
                )
            );
            // wait until the end of the sample and then add a small pause
            (age + rrand(1, 4)).wait
        }
    }),
)
)