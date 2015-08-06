// Sympli Romatikó
// module: Environment
// -------------------
// connecting together World, Sceduler and SynthDefs
//
(
var srEnv;
var currentDir;
var key, subkey, branch, conf, confFile, confKeys;
confKeys = [ // keys to save to conf file
    'surround', 'depth',
    'inbus', 'outbus', 'audioThruBus', 'mainInput', 'mainOutput',
    'worldSize', 'receiver', 'speakers'
];

// LOAD ENVIRONMENT
"Loading environment...".postln;
currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;
confFile = currentDir +/+ "conf/environment.conf";
conf = Dictionary.new;
try { // to load from conf file
    conf = File(confFile, "r").readAllString.interpret;
    postf("OK\n\n");
};

srEnv = Environment.make {
    ~currentDir = currentDir;
    ~surround = conf.atFail(\surround, {"ambisonic"});
    ~depth = conf.atFail(\depth, {3.5});
    ~inbus = conf.atFail(\inbus, {12});
    ~outbus = conf.atFail(\outbus, {0});
    ~audioThruBus = conf.atFail(\audioThruBus, {[21, 22]});
    ~mainInput = conf.atFail(\mainInput, {20});
    ~mainOutput = conf.atFail(\mainOutput, {0});
    ~worldSize = conf.atFail(\worldSize, {700}); // assume the World is a cube
    ~receiver = conf.atFail(\receiver, {NetAddr.new("127.0.0.1", 57120)});
    ~speakers = (
        items: conf.atFail(\speakers, {
            (items: List[
                (dist: 13, azim: -0.25pi, elev: 0.2pi),
                (dist: 9, azim: -0.75pi, elev: 0.2pi),
                (dist: 10.5, azim: 0.65pi, elev: 0),
                (dist: 10.5, azim: 0.35pi, elev: 0)
            ])
        })[\items],
        maxDist: conf.atFail(\speakers, {(maxDist: 15)})[\maxDist],
        collectAzim: { |self| all{: sp.azim, sp <- self.items} },
        collectDist: { |self| all{: sp.dist, sp <- self.items} },
        collectElev: { |self| all{: sp.elev, sp <- self.items} },
        removeSpeaker: { |self, index|
            if ((self.items.size - 1) < 2) {
                postf("WARNING! Cannot remove speaker %! At least two speakers should be defined!", index+1);
            } {
                self.items.pop(index);
            }
        }
    );

    // Increments integers with a limit: resets to `lo` every time
    // in + step reaches `hi`
    ~clipInc = {
        arg in=0, step=1, lo=0, hi=inf;
        ((in + step).clip(lo, hi) % hi).clip(lo, hi)
    };

    // Creates new group on Server, inserts synth and spatializer into it.
    // Assigns internal bus for rounting: each group of synth and its
    // spatializer should have a separate rounting bus for spatialization to
    // take place individually.
    ~groupInit = {
        arg synth, bufnum, busnum, params;
        var node, spatial, l=30, h=53;
        spatial = format("sr__s__%%", ~surround, ~speakers.items.size);
        node = s.nextNodeID;
        if (busnum.isNil) {
            busnum = ~clipInc.(~route ?? l, lo:l, hi:h);
            ~route = busnum;
        };
        spatial = ["/s_new", spatial, s.nextNodeID, 1, node,
            \inbus, busnum, // getting signal from synth
            \outbus, ~mainOutput, // to main output
            \depth, ~depth]
        ++ [\speakerAzim, $[] ++ ~speakers.collectAzim() ++ [$]]
        ++ [\speakerDist, $[] ++ ~speakers.collectDist() ++ [$]]
        ++ [\speakerElev, $[] ++ ~speakers.collectElev() ++ [$]]
        ++ [\maxDist, ~speakers.maxDist];
        s.sendBundle(0.01,
            ["/error", 0], // turn errors off locally
            ["/g_new", node],
            // add spatializer to new group's tail
            spatial,
            // add synth to new group's head
            ["/s_new", synth, s.nextNodeID, 0, node,
                \inbus, ~mainInput, // getting signal from external input
                \outbus, busnum, // feeding into spatilizer
                \bufnum, bufnum] ++ (params ? [])
        );
        node // return ID of the Group created
    };

    // Release all synths from group, wait until released, then remove
    // group node from server.
    ~groupFree = { |node, release=2|
        Routine({
            [
                ["/n_set", node, \rel, release ? 2.rand, \gate, 0],
                ["/n_free", node]
            ].do { |msg|
                s.listSendMsg(msg);
                release.wait;
            }
        }).play;
    };

    // Sends message to the World.
    ~sendMessage = { |msg, params, lag=0.001|
        if (msg.isNil.not) {
            ~receiver.sendBundle(lag, [msg] ++ (params ? []));
        };
    };

    // Sends particle creation message to the World:
    // [create:1, node, spring:0|1, mass:9, x:470, y:300, z:250, age:inf]
    // Returns Server node.
    ~sendParticle = { |particle, synth|
        var x, y, z, node, spring, age, params;
        #x, y, z = [\x, \y, \z].collect({ |k| particle.atFail(k, { ~worldSize.rand }) });
        particle.putAll((x: x, y: y, z: z));
        node = ~groupInit.(synth[\name], params:synth[\params]);
        params = [
            1, // create
            node,
            particle.atFail(\spring, {0}), // spring:0|1
            particle.mass,
            particle.x, particle.y, particle.z,
            particle.atFail(\age, {inf}) // if inf, particle will be waiting for the romoval signal
        ];
        ~sendMessage.('/particle', params);
        node
    };
};
currentEnvironment = srEnv;

// LOAD MODULES
"Loading synth definitions...".postln;
if (this.executeFile(~currentDir +/+ "synthdef.scd").isNil.not) {
    postf("OK\n\n")
};
"Loading scheduler...".postln;
if (this.executeFile(
    ~currentDir +/+ "scheduler.scd").isNil.not) {
    postf("OK\n\n")
};
"Loading world...".postln;
if (this.executeFile(~currentDir +/+ "world.scd").isNil.not) {
    postf("OK\n\n")
};

CmdPeriod.doOnce({
    "Saving environment conf...".postln;
    conf = Dictionary.newFrom(currentEnvironment);
    currentEnvironment.keysValuesDo { |envKey, envVal|
        if (confKeys.includes(envKey).not) {
            conf.removeAt(envKey)
        };
        if (envVal.class == Dictionary || envVal.class == Event) {
            envVal.keys.do { |key|
                if (envVal[key].class == Function) {
                    conf[envKey].removeAt(key)
                }
            }
        };
    };
    confFile = File.new(confFile, "w");
    confFile.write(conf.asCompileString);
    confFile.close;
    postf("OK\n\n");
});
)