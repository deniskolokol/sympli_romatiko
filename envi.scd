// Sympli Romatikó
// module: Environment
// -------------------
// connecting together World, Scheduler and SynthDefs
//
(
var srEnv;
var currentDir;
var key, subkey;
var conf, confFile, confKeys;
var seqPathsFile, seqPaths;
var harmonics, numHarmonics, numWavetables;
var scsynthOnBoot;
var ar__ROOT_NODE, kr__ROOT_NODE; // root IDs for synths

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

// SEQUENCES
//
"Loading sequences...".postln;
seqPathsFile = currentDir +/+ "conf/sequences.conf";
seqPaths = ["", "Load..."];
try { // to load from settings file
    seqPaths = seqPaths ++ File(seqPathsFile, "r").readAllString.interpret;
    postf("OK\n\n");
};
seqPaths = seqPaths.asList;

srEnv = Environment.make {
    ~currentDir = currentDir;
    ~seqPaths = seqPaths;
    // ~scsynth = Server("scsynth", NetAddr.new("192.168.1.106", 57110));
    ~scsynth = Server.internal;
    ~surround = conf.atFail(\surround, {"ambisonic"});
    ~depth = conf.atFail(\depth, {3.5});
    ~inbus = conf.atFail(\inbus, {4});
    ~outbus = conf.atFail(\outbus, {0});
    ~audioThruBus = conf.atFail(\audioThruBus, {[12, 13]}); // two buses for audio through on skeletons hands
    ~worldSize = conf.atFail(\worldSize, {700}); // assume the World is a cube
    ~receiver = conf.atFail(\receiver, {NetAddr.new("127.0.0.1", 57120)}); // World
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

    ~synths = (
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
            attenuate: 0.8,
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
        \sr__e__orbit: (
            key: 122, // z
            attenuate: 0.1,
        ),
        \sr__e__perc: (
            key: 47, // \?
            attenuate: 1,
        ),
    );
    ~clipInc = {
        // Increments `in` until `in + step` reaches `hi`, then resets to `lo`.
        arg in=0, step=1, lo=0, hi=inf;
        ((in + step).clip(lo, hi) % hi).clip(lo, hi)
    };

    ~sendToSrv = { |messages, time=0.1|
        ~scsynth.listSendBundle(time, messages);
    };

    ~groupInit = { |synth, bufnum, inbus, outbus, spatial, params|
        // Creates new group on Server, inserts synth and spatializer into it.
        // Assigns internal bus for routing: each group of synth and its
        // spatializer should have a separate routing bus for spatialization to
        // take place individually.
        var node, spatializer, generator, messages, synthPar, l=30, h=53;

        node = s.nextNodeID;
        params = Dictionary.newFrom(params ? []);
        if (inbus.isNil) {
            inbus = params.removeAt(\inbus) ? ~inbus;
        };
        if (outbus.isNil) {
            outbus = params.removeAt(\outbus) ? ~outbus;
        };
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
        if (bufnum.isNil) {
            // buffer can also be found in params
            bufnum = params.removeAt(\bufnum) ? ~getDefaultBuffer.(synth).bufnum;
        };
        params = params.asKeyValuePairs;
        generator = [
            "/s_new", synth, s.nextNodeID, 0, node, // synth goes to a new group's head
            \inbus, inbus,
            \route, ~route,
            \bufnum, bufnum,
            \attenuate, synthPar[\attenuate]
        ] ++ params;
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

    ~groupInitCustom = { |data, time=0.1|
        // Sends bundle to server, places everything mentioned to the top level group.
        // This is different from ~groupInit by allowing for an arbitrary number of
        // synths and flexible group's structure.
        var node, messages;
        node = ~scsynth.nextNodeID;
        messages = data[\params];
        messages.do { |l, i|
            l.do { |m, j| // replace keywords with node ids
                m.switch(
                    \group_id, { messages[i][j] = node },
                    \next_node_id, { messages[i][j] = ~scsynth.nextNodeID }
                )
            }
        };
        messages = [["/g_new", node, 0, ar__ROOT_NODE]] ++ messages; // add group creation
        ~sendToSrv.(messages, time);
        node // return node for registration purposes
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
                ~scsynth.listSendMsg(msg);
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
        var x, y, z, node, spring, source, age, params;
        #x, y, z = [\x, \y, \z].collect({ |k| particle.atFail(k, { ~worldSize.rand }) });
        particle.putAll((x: x, y: y, z: z));
        node = ~groupInit.(synth[\name], params:synth[\params]);
		spring = particle.atFail(\spring, {0});
        params = [
            1, // create
            node,
            spring, // spring:0|1
            particle.mass,
            particle.x, particle.y, particle.z,
            particle.atFail(\age, {inf}) // if inf, particle will be waiting for the romoval signal
        ];
		if (spring.booleanValue) {
			source = particle.atFail(\source, {nil});
			if (source.isNil.not) {
				params = params ++ [source]
			};
		};
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

    ~getDefaultBuffer = { |synthName|
        var buff;
        if (synthName.asString.beginsWith("sr__e__")) {
            buff = ~sequence.scales[0]
        };
        if (synthName.asString.beginsWith("sr__g__")) {
            buff = ~sequence.voices.choose
        };
        if (buff.isNil) {
            buff = ~defaultBuff
        };
        buff
    };

    // Converts timecode to readable format.
    ~convertTime = { |timecode|
        var sec=0, min=0, minstring="00", secstring="00";
        if(timecode >= 60) {
            min = trunc(timecode / 60);
            sec = round(timecode % 60, 0.1);
        } {
            sec = round(timecode, 0.1)
        };
        if (min < 10) {minstring = "0"++min.asString} {minstring = min.asString};
        if (sec < 10) {secstring = "0"++sec.asString} {secstring = sec.asString};
        if (sec == sec.round) {secstring = secstring++".0"};
        format("%:%", minstring, secstring);
    };

    // Obtains index of val in container (list, array, etc.)
    // WARNING! Quick and dirty, not universal!
    ~getIndex = { |container, val|
        var ind;
        if (val.class == String) {
            container.do { |el, i| if (el == val) { ind = i } };
        } {
            ind = container.indexOf(val)
        };
        ind
    };

    ~stopSequence = {
        // Stops sequence and all its events.
        // Warning! Order matters!
        fork {
            "[...] STOPPING SEQUENCE: stopping / resetting tasks.".postln;
            ~sequence.tasks.keys.do { |taskName|
                ~sequence.tasks[taskName].stop;
            };
            0.5.wait;
            "[...] STOPPING SEQUENCE: removing objects.".postln;
            ~sendMessage.(\action, [\remove, \all]);
            0.5.wait;
            // clean up everything including "custom" synths
            // Warning! "Custom" synths should be placed under
            // designated ..._ROOT_NODE in order to be cleaned.
            postf("[...] STOPPING SEQUENCE: cleaning root nodes %, %\n", ar__ROOT_NODE, kr__ROOT_NODE);
            ~scsynth.listSendMsg(["/n_set", ar__ROOT_NODE, \rel, 0.2, \gate, 0]);
            ~scsynth.listSendMsg(["/n_set", kr__ROOT_NODE, \rel, 0.2, \gate, 0]);
            0.5.wait;
            ~scsynth.listSendMsg(["/g_deepFree", ar__ROOT_NODE]);
            ~scsynth.listSendMsg(["/g_deepFree", kr__ROOT_NODE]);
            0.5.wait;
            ~scsynth.listSendMsg(["/g_freeAll", ar__ROOT_NODE]);
            ~scsynth.listSendMsg(["/g_freeAll", kr__ROOT_NODE]);
            0.5.wait;
            "[...] STOPPING SEQUENCE: freeing buffers".postln;
            try { ~sequence.samples.do { |buff| buff.free}};
            try { ~sequence.voices.do { |buff| buff.free}};
            try { ~sequence.scales.do { |buff| buff.free}};
            0.5.wait;
            "[...] STOPPING SEQUENCE: done".postln;
        };
    };

    // Loads sequence from file.
    ~loadSequence = { |path|
        if (path.isNil) { path = ~seqPaths[2] };
        postf("Loading sequence %...\n", PathName.new(path).fileName);
        path = path.absolutePath;
        if (this.executeFile(path).isNil.not) {
            "OK...".postln;
            if (~seqPaths.asString.contains(path).not) {
                ~seqPaths.insert(2, path); // to the top, but after ["", "Load.."]
            };
            ~getIndex.(~seqPaths, path)
        } {
            "Loading sequence has failed!".postln;
            try {
                ~seqPaths.removeAt(~getIndex.(~seqPaths, path));
            };
            0 // if unsuccessful, return 1st element ("")
        };
    };

    ~ensureRecDir = {
        var dirname = ~currentDir +/+ "rec";
        if (File.type(dirname) == \not_found) {
            File.mkdir(dirname)
        };
        dirname
    };

    // Generates the next filename for recording.
    ~setRecPath = {
        var dirname, numbers=List.new;
        dirname = ~ensureRecDir.();
        PathName(dirname).filesDo { |fname|
            fname = fname.absolutePath;
            if ("sr__rec__[0-9]+.aif".matchRegexp(fname)) {
                numbers.add(
                    fname.split($\.)[0].split($\_).last.asInteger
                )
            }
        };
        ~recPath = dirname +/+ format(
            "sr__rec__%.aif",
            (numbers.maxItem ? 0 + 1).asString
        );
    };

    // Records to a multichannel AIFF file set by ~recPath.
    ~recordAudio = { |start|
        var filename, msg;
        if (start.booleanValue) {
            ~setRecPath.();
            // If the first channel of the main mix is not 0, record all audio buses.
            if (~outbus == 0) { ~scsynth.recChannels = ~speakers.items.size };
            ~scsynth.recHeaderFormat = "aiff";
            ~scsynth.recSampleFormat = "int24";
            AppClock.sched(0, {
                fork {
                    ~scsynth.prepareForRecord(~recPath);
                    ~scsynth.sync;
                    ~scsynth.record
                }
            });
            format("ENTER: recording started %\n", ~recPath)
        } {
            if (~recPath.isNil) {
                "WARNING: Nothing is being recorded currently"
            } {
                ~scsynth.stopRecording;
                format("INFO: recording stopped %\n", ~recPath)
            }
        };
    }
};
currentEnvironment = srEnv;


// MODULES
//

scsynthOnBoot = {
    // initial server groups
    ar__ROOT_NODE = ~scsynth.nextNodeID;
    kr__ROOT_NODE = ~scsynth.nextNodeID;
    ~scsynth.sendMsg("/g_new", ar__ROOT_NODE, 0, 1);
    ~scsynth.sendMsg("/g_new", kr__ROOT_NODE, 0, 1);

    "Loading wavetables...".postln;
    numHarmonics = 1024;
    numWavetables = 8;
    numWavetables.do { |i| // allocate and fill tables
        ~scsynth.sendMsg(\b_alloc, i, numHarmonics);
        harmonics = Harmonics(numHarmonics).formant(12,
            (i**2).linlin(0, numWavetables**2, 1, numHarmonics).ceil
        );
        ~scsynth.performList(\sendMsg, \b_gen, i, \sine1, n, harmonics);
    };

    // default scale buffer
    ~defaultBuff = Buffer.sendCollection(~scsynth, Scale.ahirbhairav.degrees, 1, 0.2);

    // internal buffer
    ~internalBuff = Buffer.alloc(~scsynth, ~scsynth.sampleRate, 1); // 1 seconds 1 channel

    "Loading synth definitions...".postln;
    if (this.executeFile(~currentDir +/+ "synthdef.scd").isNil.not) {
        postf("OK\n\n")
    };

    "Loading world...".postln;
    if (this.executeFile(~currentDir +/+ "world.scd").isNil.not) {
        postf("OK\n\n")
    };

    "Initiating audio-through synth".postln;
    ~nodeAudioThrough = ~groupInit.(\sr__r__authro);

    // // XXX - in progress
    // "Loading control matrix...".postln;
    // if (this.executeFile(~currentDir +/+ "ctrlmatrix.scd").isNil.not) {
    //     postf("OK\n\n")
    // };
};

if (~scsynth == Server.internal) {
    s = ~scsynth; // default server

    s.options.numInputBusChannels = 4;
    s.options.numOutputBusChannels = 12; // 10 outputs on the interface + one aux stereo output
    s.options.memSize = 262144;
    s.options.blockSize = 512;

    s.boot;
    ~scsynth.waitForBoot(scsynthOnBoot);
} {
    {
        try {
            ~scsynth.addr.connect;
            s = ~scsynth; // default server

            postf("Connected to Server % at %...\n", ~scsynth.name, ~scsynth.addr.ip);
            ~scsynth.notify;
            ~scsynth.initTree;
            ~scsynth.meter;
            ~scsynth.queryAllNodes;

            scsynthOnBoot.()
        } { |error|
            postf("Server % at % is not running!\n", ~scsynth.name, ~scsynth.addr.ip);
            error.postln;
        }
    }.defer(1);
};

CmdPeriod.doOnce({
    "Freeing buffers...".postln;
    ~wavetable.do(_.free);
    ~sequence.samples.do { |buff| buff.free};
    ~sequence.scales.do { |buff| buff.free};
    ~sequence.voices.do { |buff| buff.free};
    ~defaultBuff.free;
    ~internalBuff.free;

    "Killing audio-through".postln;
    ~groupFree.(~nodeAudioThrough);

    "Disconnecting from synth server...".postln;
    ~scsynth.addr.disconnect;

    "Saving environment conf...".postln;
    confKeys = [ // keys to save to conf file
        'surround', 'depth',
        'inbus', 'outbus', 'audioThruBus', 'inbus', 'outbus',
        'worldSize', 'receiver', 'speakers'
    ];
    conf = Dictionary.newFrom(currentEnvironment);
    currentEnvironment.keysValuesDo { |envKey, envVal|
        if (confKeys.includes(envKey).not) {
            conf.removeAt(envKey)
        };
        if (envVal.class == Dictionary || envVal.class == Event) {
            envVal.keys.do { |key|
                if (envVal[key].isFunction) {
                    conf[envKey].removeAt(key)
                }
            }
        };
    };
    confFile = File.new(confFile, "w");
    confFile.write(conf.asCompileString);
    confFile.close;

    "Saving sequences...".postln;
    seqPathsFile = File.new(seqPathsFile, "w");
    seqPathsFile.write(seqPaths[2..].asCompileString); // drop ["", "Load.."]
    seqPathsFile.close;

    postf("OK\n\n");
});
)