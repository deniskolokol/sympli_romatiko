// Sympli Romatikó
// module: Environment
// -------------------
// connecting together World, Sceduler and SynthDefs
//
(
var srEnv;
srEnv = Environment.make {
    ~surround = "ambisonic2";
    ~currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;
    ~depth = 3.5;
    ~inbus = 12;
    ~outbus = 0;
    ~audioThruBus = [21, 22];
    ~mainInput = 20;
    ~mainOutput = 0;
    ~worldSize = 700; // assume the World is a cube
    ~receiver = NetAddr.new("127.0.0.1", 57120);

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
        arg synth, spatial, bufnum, busnum, params;
        var node, l=30, h=53;
        if (spatial.isNil) {
            spatial = ~surround
        };
        spatial = spatial.asString;
        if (spatial.beginsWith("sr__s__").not) {
            spatial = "sr__s__" ++ spatial.toLower
        };
        node = s.nextNodeID;
        if (busnum.isNil) {
            busnum = ~clipInc.(~route ?? l, lo:l, hi:h);
            ~route = busnum;
        };
        s.sendBundle(0.01,
            ["/error", 0], // turn errors off locally
            ["/g_new", node],
            // add spatializer to new group's tail
            ["/s_new", spatial, s.nextNodeID, 1, node,
                \inbus, busnum, // getting signal from synth
                \outbus, ~mainOutput, // to main output
                \depth, ~depth],
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
        node = ~groupInit.(synth[\name], ~surround, params:synth[\params]);
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
)