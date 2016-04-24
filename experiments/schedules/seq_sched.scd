(
var playRout, quant= 0.01, current;
var w, lbKey, lbSteps, lbWait, liWait; // main window
var warn= 0.6, crit= 0.9;
var key, next, syn, obj, age, mass;
var sched; // Main schedule dictionary (timestamp -> event description)
var synths=Dictionary.new; // temp dictionary of the synths symbolic IDs vs. server Nodes
var sGroupId, receiverNet;
var dictObjSeq, msetObjSeq; // Markov chains used for creating sequences and obtaining objects' birthtime.

// Group for synths.
sGroupId= s.nextNodeID;
s.sendMsg("/g_new", sGroupId);

// Schedule events - constants.
// TO-DO:
// - opportunity to hook synth from node to the object and back (only change \busnum??)
sched = (
    '0': ( // Initial settings.
        message: \worldpar,
        params: [
            // Audio settings.
            \audioIn: false, \confSurround: "Ambisonic4", \inbus: 8, \fieldDepth: 3,
            \master: 1,
            // World settings.
            \darkEnergy: 20, \heavy: 5, \initMass: 2, \starMass: 120, \world_maxVel: 30,
            \objAttract: false, \world_damping: 0.8, \world_gravity: 0.98,
            // General.
            \visualize: 1
        ]
    ),
    '5': ( // Launch the first object.
        message: \worldobj,
        synth: (
            name: \sr_pulse,
            params: [\att, 5]
        ),
        object: (
            type: "a RedBoid",
            age: 50,
            mass: 1.8
        )
    ),
    '30': ( // Launch another object.
        message: \worldobj,
        synth: (
            name: \sr_pulse,
        ),
        object: (
            type: "a RedBoid",
            age: 50,
            mass: 3
        )
    ),
    '120': ( // Increase entropy.
        message: \worldpar,
        params: [\starMass, 300]
    ),
    '135': ( // Raise max velocity.
        message: \worldpar,
        params: [\world_maxVel, 100]
    ),
    '145': ( // Substantially increase entropy.
        message: \worldpar,
        params: [\starMass, 1000]
    ),
    '165': ( // Decrease entropy.
        message: \worldpar,
        params: [\starMass, 120]
    )
    // GAP for m1, m2: 169 - 600
);

// Create a sequence rules for Markov set.
dictObjSeq = (
    // [number of repeats] (to choose from) -> [timelapse] (current moment and age)
    0: [(4..12), (1..6)], // short
    1: [[1, 3, 5, 7, 9], ({rrand(5, 40)} ! 10)], // average
    2: [[1, 2], ({rrand(30, 120)} ! 10)] // long (repeat)
);
msetObjSeq= MarkovSetN([], 2);
dictObjSeq.keysValuesDo{|k, v| msetObjSeq[k] = v[1]};

// ~1' (60) - 5' (360): pulses "rolling" around.
current = 60;
while {current <= 360} {
    var key, next, syn, obj, age;

    // Pick up a key and the number of iterations randomly.
    // Average sequences are the most probable, long are the least probable.
    key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.3125, 0.625, 0.0625]);

    dictObjSeq[key.asInteger][0].choose.do{
        next = msetObjSeq.next(key);
        current = current + next;

        // Choose a synth:
        // \sr_pulse is more probable, it creates better background;
        // \sr_ringz is required to diversify the audio field every now and then.
        syn = [\sr_pulse, \sr_ringz].wchoose([0.7, 0.3]);

        // Age spans over to the next object birth - no gaps!
        // The lighter objects the faster they die, but their demography is denser.
        age = next * (1 + (5/(next.pow(0.33))));

        // Mass is of a sqrt propotion to life cycle.
        mass = next.sqrt;

        // Create an event (object and corresponding synth).
        // Check if this time is already there.
        if (sched.keys.asArray.includes(current)) {current = current + quant};
        sched[current.asSymbol] = (
            message: \worldobj,
            synth: (
                name: syn,
                params: []
            ),
            object: (
                age: age,
                mass: mass,
                type: "a RedBoid"
            )
        )
        //postf("key: %\t\tnext: %\t\tcurrent: %\t age: %\n", key, next, current, age);
    }
};

// ~3' (180) - 6' (360): add sharp "_analog" bursts.
current = 180;
// current = 10;
while {current <= 360} {
    var age, next=8.30;
    age = rrand(1.70, 2.30);

    if (sched.keys.includes(current)) {current = current + quant};
    sched[current.asSymbol] = (
        message: \worldobj,
        synth: (
            name: \sr_analog,
            params: [\cutoff, -1]
        ),
        object: (
            age: age,
            mass: 6,
            type: "a RedObject"
        )
    );
    current = current + next;
};

// ~6 (359) - 10' (600): pulses still "rolling" around, but "analog" synth taking over.
current = 359;
while {current <= 600} {
    // Pick up a key and the number of iterations randomly.
    // Here average sequences are the most probable, short are the least probable.
    key = msetObjSeq.dict.keys.asArray.sort.wchoose([0.0625, 0.625, 0.3125]);

    dictObjSeq[key.asInteger][0].choose.do{
        next = msetObjSeq.next(key);
        current = current + next;

        // Choose a synth:
        // \sr_analog is the most probable, it is kind of "soloing" now;
        // \sr_pulse is of ave probability, creates good background;
        // \sr_ringz is the least probable, only connecting with the prev part.
        syn = [\sr_analog, \sr_pulse, \sr_ringz].wchoose([0.625, 0.3125, 0.0625]);

        // Choose a type of the object to create:
        // boids are more preferable for background, since they are less active.
        if (syn == \sr_analog) {obj = "a RedObject"} {obj = "a RedBoid"};

        // Age spans over to the next object birth - no gaps!
        // The lighter objects the faster they die, but their demography is denser.
        age = next * (1 + (5/(next.pow(0.33))));

        //postf("key: %\t\tnext: %\t\tcurrent: %\t age: %\n", key, next, current, age);

        // Create an event (object and corresponding synth).
        // See "WARNING!" in the prev schedule.
        //
        if (sched.keys.includes(current)) {
            current = current + 0.5
        };
        sched[current.asSymbol] = (
            message: \worldobj,
            synth: (
                name: syn,
                params: []
            ),
            object: (
                type: obj,
                age: age,
                mass: if (obj == "a RedObject") {rrand(5, 10)} {rrand(1, 4)} // Objects are much heavier than boids.
            )
        )
    }
};

// Report.
sched.keys.asArray.sort.do{ |k| postf("% (%) %\n", k, k.class, sched[k])};

// GUI.
w= Window("sequencing and scheduling", Rect(1800, 900, 270, 150), resizable:false)
	.acceptsMouseOver_(true);
w.view.decorator = FlowLayout(w.view.bounds);
b = StaticText(w, 260@50).font_(Font("Helvetica", 36));
c = StaticText(w, 260@50).font_(Font("Helvetica", 18));
Button(w, 77@30)
.states_([
    ["RUN", Color.black, Color.white],
    ["STOP", Color.white, Color.red]
])
.action_({ arg bt; if (bt.value == 1) {playRout.play(quant:5)} {playRout.pause}});
Button(w, 77@30)
	.states_([["RESTART", Color.black, Color.white]])
	.action_({ arg bt; playRout.reset;});

// Net Address and Port of the Receiver.
receiverNet = NetAddr.new("127.0.0.1", 57120);

sched.keys.do { |k| k.postln};
sched.keys.asArray.includes("165").postln;

playRout= Task({
	var key, keySteps, waitKey, nextKey, wait, waitCycle, action;
    var objType, synthType;
	inf.do({ |now|
        current =  now * quant;

        {b.string = current}.defer;

        // Process scheduler.
        if (sched.keys.asArray.includes(current.asSymbol)) {
            // postf("found % (%): %\n", current, current.class, sched[current.asInteger] ? sched[current.asFloat]);
            { c.string = current.asSymbol ++ " " ++ m.asString[0..12] }.defer;
            m = sched[current.asSymbol];
            m[\message].switch(
                \worldobj, {
                    p = m[\object].atFail(\pos, {nil});

                    // Check if position given correctly.
                    if (p.isNil || (p.class != Array)) {p = [0, 0, 0]};

                    // It might also be only X & Y or even X given, in that case the rest must be 0.
                    3.do{|i| try {p[i] = p[i].asFloat} { |err| err.postln; p.add(0)}};

                    // Send object creation message.
                    receiverNet.sendBundle(0.01,
                        [
                            "/worldobj",
                            m[\synth][\name], m[\object][\type], m[\object][\age],
                            p[0], p[1], p[2], m[\object][\mass]
                        ]
                        ++ m[\synth].atFail(\params, {[]})
                    )
                },
                \worldpar, {
                    if (m.atFail(\params, {[]}).size > 1) {
                        m[\params].pairsDo { |n, v| receiverNet.sendMsg("/worldpar", n, v)}
                    }
                },
                \s_new, { // Send a new synth message directly to the server.
                    synths.put(m[\synth][\id], s.nextNodeID);
                    s.listSendMsg(["/s_new", m[\synth][\name],
                        synths.at(m[\synth][\id]), 0, sGroupId] ++ m[\synth].atFail(\params, {[]}));
                },
                \n_set, { // Send a 'set params' message directly to the server.
                    s.listSendMsg(["/n_set", synths.at(m[\synth][\id])] ++ m[\synth].atFail(\params, {[]}))
                }
            )
        };
        quant.wait;
    });
});

w.refresh;
w.front;

CmdPeriod.doOnce({
    playRout.stop;
    w.close;
	});
)