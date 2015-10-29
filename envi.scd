// Sympli Romatikó
// module: Environment
// -------------------
// connecting together World, Sceduler and SynthDefs
//
(
var srEnv;
var currentDir;
var key, subkey, synthNames, conf, confFile, confKeys;

// root IDs for synths
var ar__ROOT_NODE = s.nextNodeID;
var kr__ROOT_NODE = s.nextNodeID;

// initial server groups
s.sendMsg("/g_new", ar__ROOT_NODE, 0, 1);
s.sendMsg("/g_new", kr__ROOT_NODE, 0, 1);

// ENVIRONMENT
//
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
                (dist: 3, azim: -0.25pi, elev: 0pi),
                (dist: 3, azim: -0.75pi, elev: 0pi),
                (dist: 3, azim: 0.65pi, elev: 0),
                (dist: 3, azim: 0.35pi, elev: 0)
            ])
        })[\items],
        maxDist: conf.atFail(\speakers, {(maxDist: 3)})[\maxDist],
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

    // wavetable buffers start from bufnum 0
    ~wavetable = 0;
    24.do { |i| // allocate and fill tables 0 to 23
        var n, a;
        // allocate table
        s.sendMsg(\b_alloc, i, 4096);
        // generate array of harmonic amplitudes
        n = (i+1)**2;
        // a = Array.fill(n, { |j| ((n-j)/n).squared.round(0.001) });
        a = Array.fill(i, 0) ++ [0.5, 1, 0.5];
        // fill table
        s.performList(\sendMsg, \b_gen, i, \sine1, 7, a);
    };

    synthNames = (
        sr__e__wasp: (
            key: 12, // q
            attenuate: 0.02,
        ),
        sr__e__radio: (
            key: 13, // w
            attenuate: 0.06,
        ),
        sr__e__humm: (
            key: 14, // e
            attenuate: 0.1,
        ),
        sr__e__gauss: (
            key: 15, // r
            attenuate: 0.2,
        ),
        sr__e__entro: (
            key: 17, // t
            attenuate: 0.1,
        ),
        sr__e__noisy: (
            key: 16, // y
            attenuate: 0.02,
        ),
        sr__e__probe: (
            key: 32, // u
            attenuate: 0.5,
        ),
        sr__e__cmb: (
            key: 34, // i
            attenuate: 0.5,
        ),
        sr__e__lowe: (
            key: 31, // o
            attenuate: 0.05,
        ),
        sr__e__melo: (
            key: 35, // p
            attenuate: 0.5,
        ),
        sr__e__ringz: (
            key: 33, // [
            attenuate: 0.2,
        ),
        sr__e__pulse: (
            key: 30, // ]
            attenuate: 0.1,
        ),
        \sr__g__reg: (
            key: 1, // s
            attenuate: 1,
        ),
        \sr__g__drone: (
            key: 2, // d
            attenuate: 1,
        ),
        \sr__g__gust: (
            key: 3, // f
            attenuate: 1,
        ),
        \sr__g__slic: (
            key: 5, // g
            attenuate: 1,
        ),
        \sr__g__loop: (
            key: 4, // h
            attenuate: 1,
        ),
        \sr__g__scratch: (
            key: 38, // j
            attenuate: 1,
        ),
        \sr__g__unst: (
            key: 40, // k
            attenuate: 1,
        ),
        \sr__g__chunk: (
            key: 37, // l
            attenuate: 1,
        ),
        \sr__e__therem: (
            key: 41, // ;
            attenuate: 1.5,
        ),
        \sr__e__growl: (
            key: 39, // "
            attenuate: 0.3,
        ),
        \sr__e__analog: (
            key: 42, // \ (the answer to the ultimate question ))
            attenuate: 0.05,
        ),
        \sr__e__silent: (
            key: nil,
            attenuate: 1,
        ),
        \sr__e__tbl: (
            key: nil,
            attenuate: 0.1,
        ),
        \sr__e__sawy: (
            key: nil,
            attenuate: 0.05,
        ),
        \sr__e__electro: (
            key: nil,
            attenuate: 0.05,
        ),
        \sr__e__wind: (
            key: nil,
            attenuate: 0.05,
        ),
    );
    ~synths = merge( // update default ~synths settings by those in conf
        synthNames, conf.atFail(\synths, {Dictionary.new}), { |a, b| b }
    );

    ~clipInc = {
        // Increments `in` until `in + step` reaches `hi`, then resets to `lo`.
        arg in=0, step=1, lo=0, hi=inf;
        ((in + step).clip(lo, hi) % hi).clip(lo, hi)
    };

    ~sendToSrv = { |messages, time=0.1|
        s.listSendBundle(time, messages);
    };

    ~groupInit = { |synth, bufnum, inbus, outbus, spatial, params|
        // Creates new group on Server, inserts synth and spatializer into it.
        // Assigns internal bus for routing: each group of synth and its
        // spatializer should have a separate routing bus for spatialization to
        // take place individually.
        var node, spatializer, generator, messages, synthPar, l=30, h=53;
        node = s.nextNodeID;
        inbus = inbus ? ~mainInput;
        outbus = outbus ? ~mainOutput;
        ~route = ~clipInc.(~route ?? l, lo:l, hi:h); // calculate and save for subsequent assignments
        spatial = spatial ? ~getSpatial.();
        spatializer = [
            "/s_new", spatial, s.nextNodeID, 1, node, // spatializer goes to a new group's tail
            \route, ~route,
            \outbus, outbus,
            \depth, ~depth
        ] ++ [\maxDist, ~speakers.maxDist]
        ++ [\speakerAzim, $[] ++ ~speakers.collectAzim() ++ [$]]
        ++ [\speakerDist, $[] ++ ~speakers.collectDist() ++ [$]]
        ++ [\speakerElev, $[] ++ ~speakers.collectElev() ++ [$]];

        synthPar = ~synths.atFail(synth.asSymbol, {~synths[\sr__e__silent]});
        generator = [
            "/s_new", synth, s.nextNodeID, 0, node, // synth goes to a new group's head
            \inbus, inbus,
            \route, ~route,
            \bufnum, bufnum,
            \attenuate, synthPar[\attenuate]
        ] ++ (params ? []);
        messages = [
            ["/error", 0], // turn errors off locally
            ["/g_new", node, 0, ar__ROOT_NODE],
            spatializer,
            generator
        ];
        ~sendToSrv.(messages);
        node // return ID of the Group created
    };

    ~modulatorInit = { |synth, bufnum, inbus, outbus, params|
        // Creates a .kr synth on Server. Doesn't need spatializer.
        // Returns nil, if outbus is not given (.kr doesn't make
        // sense without outbus).
        var messages, node = s.nextNodeID;
        params = params ? [];
        if (inbus.isNil.not) {
            params = params ++ [\inbus, inbus]
        };
        if (outbus.isNil.not) {
            params = params ++ [\outbus, outbus];
            messages = [
                ["/s_new", synth, node, 0, kr__ROOT_NODE],
                ["/n_set", node] ++ (params ? [])
            ];
            ~sendToSrv.(messages);
        } {
            node = nil
        };
        node
    };

    ~getSpatial = {
        format("sr__s__%%", ~surround, ~speakers.items.size)
    };

    ~groupFree = { |node, release=2|
        // Release all synths from group, wait until released, then remove
        // group node from server.
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

    ~sendMessage = { |msg, params, lag=0.001|
        // Sends message to the World.
        if (msg.isNil.not) {
            ~receiver.sendBundle(lag, [msg] ++ (params ? []));
        };
    };

    ~sendParticle = { |particle, synth|
        // Sends particle creation message to the World:
        // [create:1, node, spring:0|1, mass:9, x:470, y:300, z:250, age:inf]
        // Returns Server node.
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

    ~valAsApec = { |param|
        param.atFail(\spec, {
            [
                param.atFail(\minval, {0}), param.atFail(\maxval, {1}),
                param.atFail(\warp, {\lin}),
                param.atFail(\step, {0}),
                param.atFail(\default, {0})
            ]
        }).asSpec
    };
};
currentEnvironment = srEnv;


// MODULES
//
// XXX - Need some confirmation from server that all are loaded!
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
"Loading control matrix...".postln;
if (this.executeFile(~currentDir +/+ "ctrlmatrix.scd").isNil.not) {
    postf("OK\n\n")
};


CmdPeriod.doOnce({
    "Saving environment conf...".postln;
    confKeys = [ // keys to save to conf file
        'surround', 'depth',
        'inbus', 'outbus', 'audioThruBus', 'mainInput', 'mainOutput',
        'worldSize', 'receiver', 'speakers', 'synths'
    ];
    conf = Dictionary.newFrom(currentEnvironment);
    currentEnvironment.keysValuesDo { |envKey, envVal|
        if (confKeys.includes(envKey).not) {
            conf.removeAt(envKey)
        };
        if (envVal.class == Dictionary || envVal.class == Event) {
            envVal.keys.do { |key|
                if (envVal[key].class == Function) { // XXX - use .isFunction (?)
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