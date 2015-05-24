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
};

currentEnvironment = srEnv;

// LOAD MODULES
"Loading synth definitions...".postln;
if (this.executeFile(~currentDir +/+ "synthdef.scd").isNil.not) {
    postf("OK\n\n")
};
"Loading scheduler...".postln;
if (this.executeFile(
    ~currentDir +/+ "schedules/scheduler_traer.scd").isNil.not) {
    postf("OK\n\n")
};
"Loading world...".postln;
if (this.executeFile(~currentDir +/+ "world.scd").isNil.not) {
    postf("OK\n\n")
};
)