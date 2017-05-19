// Sympli Romatikó
// module: Environment
// -------------------
// connecting together World, Scheduler and SynthDefs
//
(
var srEnv;
var loadComponents, loadCommonComponents;
var initAudioThrough;
var doTest, loadComponents__test;
var conf=Dictionary.new;
var confKeys = [ // keys to save to conf file
        'surround', 'depth',
        'inbus', 'outbus', 'audioThruBus', 'inbus', 'outbus',
        'worldSize', 'receiver', 'speakers'
    ];
var harmonics, numHarmonics=1024, numWavetables = 8;

var cleanPaths = { |paths|
	// Converts each element from `paths` to absolute path,
	// and returns unique paths.
	var lines="";
	paths.do { |path|
		path = path.absolutePath;
		if (PathName(path).isFile) {
			if (lines.contains(path).not) {
				lines = lines ++ format("%\n", path)
			}
		} {
			postf("WARNING: Skipping path % (not a file).\n", path);
		}
	};
	lines
};

var loadPaths = { |lines|
	// Converts paths separated by "\n" to List.
	lines.split($\n).reject({ |line| line.size == 0});
};

var isTest = thisProcess.argv.includesEqual("test");
var currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;
var seqPathsFile = currentDir +/+ "conf/sequences.conf";
var seqPaths = ["", "Load..."];
var confFile = currentDir +/+ "conf/envi.conf";

if (isTest) {
	confFile = confFile.replace("envi.conf", "envi_test.conf");
};

// ENVIRONMENT
//
"Loading environment...".postln;
try { // to load from conf file
    conf = File(confFile, "r").readAllString.interpret;
    postf("OK\n\n");
};

// SEQUENCES
//
"Loading sequences...".postln;
try { // to load from settings file
	seqPaths = seqPaths ++ loadPaths.(
		File(seqPathsFile, "r").readAllString
	);
    postf("OK\n\n");
} { |err|
	postf("WARNING: Problem loading sequences, cannot access file %\n", seqPathsFile);
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
                postf("WARNING: cannot remove speaker %! At least two speakers should be defined!", index+1);
            } {
                self.items.pop(index);
            }
        }
    );

	~sequence = ( // default empty sequence
		title: "<none>",

		// step marks (numbered) and time marks (entitled)
		// (
		//     0: [(event0), (event1), ...],
		//     1: [(eventN), (eventN+1), ...],
		//     foo: [...]
		// )
		events: Dictionary.new,

		// connector of time and time marks
		// (
		//     0_00: \foo,
		//     1_12_354: \gee
		// )
		marks: Dictionary.new,

		// descriptions of tasks
		// (
		//     taskX: Task({...}),
		//     taskY: Task({...}),
		// )
		tasks: Dictionary.new,

		// list of buffers
		samples: List.new,

		// list of buffers for voice samples
		voices: List.new,

		// list of buffers for scales
		scales: List.new,
	);

    ~synths = (
        \silent: (
            key: nil,
            attenuate: 1,
        ),
        \buzz: (
			key: 41, // ;
            attenuate: 0.3,
        ),
		\pole: (
            key: 39, // "
            attenuate: 0.5,
        ),
		\bass: (
			key: 47, // \?
			attenuate: 0.5,
		),
        \moog: (
            key: 42, // \ (the answer to the ultimate question ))
            attenuate: 0.05,
        ),
        \lowe: (
            key: 31, // o
            attenuate: 0.05,
        ),
		\wind: (
            key: 16, // y
            attenuate: 0.02,
        ),
        \komar: (
            key: 13, // w
            attenuate: 0.06,
        ),
		\neural: (
            key: 37, // l
            attenuate: 0.06,
        ),
        \entro: (
            key: 17, // t
            attenuate: 0.1,
        ),
        \humm: (
            key: 14, // e
            attenuate: 0.1,
        ),
        \melo: (
            key: 35, // p
            attenuate: 0.5,
        ),
        \cmb: (
            key: 34, // i
            attenuate: 0.5,
        ),
        \probe: (
            key: 32, // u
            attenuate: 0.8,
        ),
        \pulse: (
            key: 30, // ]
            attenuate: 0.1,
        ),
        \therem: (
            key: nil,
            attenuate: 1.5,
        ),
        \gauss: (
            key: 15, // r
            attenuate: 0.2,
        ),
        \loop: (
            key: 4, // h
            attenuate: 1,
        ),
        \loopdel: (
            key: nil,
            attenuate: 1,
        ),
        \drone: (
            key: 2, // d
            attenuate: 1,
        ),
        \greg: (
            key: 1, // s
            attenuate: 1,
        ),
        \scratch: (
            key: 38, // j
            attenuate: 1,
        ),
        \unst: (
            key: 40, // k
            attenuate: 1,
        ),
        \gust: (
            key: 3, // f
            attenuate: 1,
        ),
    );

    ~clipInc = {
        // Increments `in` until `in + step` reaches `hi`, then resets to `lo`.
        arg in=0, step=1, lo=0, hi=inf;
        ((in + step).clip(lo, hi) % hi).clip(lo, hi)
    };

    ~initSynth = { |synth, spatial, params|
        // Creates an .ar synth on Server.
		// Returns ID of the Node created.
		// `synth` - short name (i.e. \moog or \buzz).
		// `params` - anything convertable to Dictionary (i.e. list of pairs).
        var message;
        var node=~scsynth.nextNodeID;
        params = Dictionary.newFrom(params ? []);
        if (params.keys.includes(\in).not) {
			params[\in] = ~inbus;
        };
        if (params.keys.includes(\out).not) {
			params[\out] = ~outbus;
        };
        if (params.keys.includes(\bufnum).not) {
			params[\bufnum] = ~getDefaultBuffer.(synth).bufnum;
        };
		synth = format("%__%", synth, (spatial ? ~spatial.()));
        // report
        postf("-> ~initSynth synth % at node %\n", synth, node);
        params.keysValuesDo { |k,v| postf("\t%: %\n", k, v); };
        // gather everything in place
        message = [
			// each new synth goes to the root group's tail
            "/s_new", synth, node, 1, ~rootAr,
			\depth, ~depth,
			\maxDist, ~speakers.maxDist
        ]
		++ params.asKeyValuePairs
		++ [\azim, $[] ++ ~speakers.collectAzim() ++ [$]]
        ++ [\dist, $[] ++ ~speakers.collectDist() ++ [$]]
        ++ [\elev, $[] ++ ~speakers.collectElev() ++ [$]];
        // send
		~scsynth.listSendMsg(message);
        node
    };

    ~initModulator = { |synth, bufnum, inbus, outbus, params|
        // Creates a .kr synth on Server.
        // Returns nil, if outbus is not given (.kr doesn't make
        // sense without outbus).
        var messages, node = ~scsynth.nextNodeID;
        params = params ? [];
        if (inbus.isNil.not) {
            params = params ++ [\inbus, inbus]
        };
        if (outbus.isNil.not) {
            params = params ++ [\outbus, outbus];
            // report
            postf("INFO: init LFO % at node %\n", synth, node);
            Dictionary.newFrom(params).keysValuesDo { |k,v| postf("\t%: %\n", k, v); };
            messages = [
                ["/s_new", synth, node, 0, ~rootKr],
                ["/n_set", node] ++ (params ? [])
            ];
			~scsynth.listSendBundle(0.1, messages)
        } {
            node = nil
        };
        node
    };

	~initGroup = { |data, time=0.1|
        // Sends bundle to server, places everything mentioned to the top level group.
        // This allows for an arbitrary number of synths and flexible structure.
		// Returns node for registration purposes.
        var node = ~scsynth.nextNodeID;
        var messages = data[\params];
        messages.do { |l, i|
            l.do { |m, j| // replace keywords with node ids
                m.switch(
                    \group_id, { messages[i][j] = node },
                    \next_node_id, { messages[i][j] = ~scsynth.nextNodeID }
                )
            }
        };
		// add group creation (tail)
        messages = [["/g_new", node, 1, ~rootAr]] ++ messages;
		~scsynth.listSendBundle(time, messages);
		// report it
		postf("-> ~initGroup: %\n", node);
		messages.do { |m| postf("\t%\n", m) };
		// return group nodce id
        node
    };

    ~spatial = {
		format("%%", ~surround[0], ~speakers.items.size)
    };

    ~groupFree = { |node, release=2|
        // Release all synths from group, wait until released, then remove
        // group node from server.
        Routine({
            [
                ["/n_set", node, \rel, release, \gate, 0],
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
		node = ~initSynth.(synth[\name], params:synth[\params]);
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

	// XXX re-design
	//     no indicator of whether synth is gen or gran anymore
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

    ~convertTime = { |timecode|
		// Converts timecode to readable format.
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

    ~getIndex = { |container, val|
		// Obtains index of val in container (list, array, etc.)
		// WARNING! Quick and dirty, not universal!
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
            "INFO: stopping / resetting tasks".postln;
            ~sequence.tasks.keys.do { |taskName|
                ~sequence.tasks[taskName].stop;
            };
            0.5.wait;
            "INFO: removing objects".postln;
            ~sendMessage.(\action, [\remove, \all]);
            0.5.wait;
			"INFO: removing modulators".postln;
			~scsynth.listSendMsg(["/n_set", ~rootKr, \rel, 0.2, \gate, 0]);
            0.5.wait;
            ~scsynth.listSendMsg(["/g_deepFree", ~rootKr]);
            0.5.wait;
            ~scsynth.listSendMsg(["/g_freeAll", ~rootKr]);
            0.5.wait;
            "INFO: freeing buffers".postln;
            try { ~sequence.samples.do { |buff| buff.free}};
            try { ~sequence.voices.do { |buff| buff.free}};
            try { ~sequence.scales.do { |buff| buff.free}};
            0.5.wait;
            "INFO: done stopping sequence".postln;
        };
    };

    ~loadSequence = { |path|
		// Loads sequence from file.
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

    ~setRecPath = {
		// Generates the next filename for recording.
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

    ~recordAudio = { |start|
		// Records to a multichannel AIFF file set by ~recPath.
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
            format("INFO: recording started %\n", ~recPath)
        } {
            if (~recPath.isNil) {
                "WARNING: Nothing is being recorded currently"
            } {
                ~scsynth.stopRecording;
                format("INFO: recording stopped %\n", ~recPath)
            }
        };
    };

	~formatSrvTree = { |msg|
		// Creates a tree out of server message \g_queryTree.reply
		// Copied and re-formatted from Server.queryAllNodes
		var i=2, tabs=0, printControls=false, dumpFunc, result;
		if (msg[1] != 0) { printControls = true };
		result = format("ROOT %\n", msg[2]);
		if (msg[3] > 0) {
			dumpFunc = { |numChildren|
				var j;
				tabs = tabs + 1;
				numChildren.do {
					if (msg[i + 1] >=0) {
						i = i + 2
					} {
						i = i + 3 + if(printControls, {msg[i + 3] * 2 + 1}, {0});
					};
					tabs.do { result = result + "   " };
					result = result + msg[i]; // nodeID
					if (msg[i + 1] >=0) {
						result = format("% group\n", result);
						if(msg[i + 1] > 0, { dumpFunc.value(msg[i + 1]) });
					} {
						result = result + format(" %\n", msg[i + 2]); // defname
						if (printControls) {
							if (msg[i + 3] > 0) {
								result = result + " ";
								tabs.do { result = result + "   " };
							};
							j = 0;
							msg[i + 3].do {
								result = result + " ";
								if (msg[i + 4 + j].isMemberOf(Symbol)) {
									result = result + (msg[i + 4 + j] ++ ": ");
								};
								result = result + msg[i + 5 + j];
								j = j + 2;
							};
							result = format("%\n", result);
						};
					};
				};
				tabs = tabs - 1;
			};
			dumpFunc.value(msg[3]);
		};
		result
	};
};
currentEnvironment = srEnv;

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

	// Omit the first 2 items of seqPaths are [<empty>, "Load..."],
	// save paths to sequences only if there are some.
	if (seqPaths.size > 2) {
		"Saving paths to sequences...".postln;
		seqPathsFile = File.new(seqPathsFile, "w");
		seqPathsFile.write(cleanPaths.(seqPaths[2..]));
		seqPathsFile.close;
	};

    postf("OK\n\n");
});


initAudioThrough = Task({
    // Tries to init audio through synth, waits for half a second,
    // then sends g_queryTree until.
    // Repeats that for 4 times, unless the synth is loaded,
    // in which case it stops the task and frees responder.
    var done=false;
    var responder = OSCFunc({ |msg|
        done = msg.includes(("atru__" ++ ~spatial.()).asSymbol);
    }, '/g_queryTree.reply');

    4.do { |j|
        ~nodeAudioThrough = ~initSynth.(\atru);
        0.5.wait;
        ~scsynth.sendMsg("/g_queryTree", ~rootAr);
        1.5.wait;
        if (done) {
            postf("OK\n\n");
            responder.free;
            initAudioThrough.stop;
        };
        0.5.wait
    };
    if (done.not) {
        "ERROR: cannot start audio through synth, timeout 10 sec."
    }
});


// MODULES
//
loadCommonComponents = {
    "Initiating top level server groups for synths and modulators...".postln;
    ~rootAr = ~scsynth.nextNodeID;
    ~rootKr = ~scsynth.nextNodeID;
    ~scsynth.sendMsg("/g_new", ~rootAr, 0, 1);
    ~scsynth.sendMsg("/g_new", ~rootKr, 0, 1);

    "Creating default scale buffer...".postln;
    ~defaultBuff = Buffer.sendCollection(~scsynth, Scale.ahirbhairav.degrees, 1, 0.2);

    "Creating internal buffer (1 seconds 1 channel)...".postln;
    ~internalBuff = Buffer.alloc(~scsynth, ~scsynth.sampleRate, 1);

    "Loading synth definitions...".postln;
    if (this.executeFile(~currentDir +/+ "synthdef.scd").isNil.not) {
        postf("OK\n\n")
    };

    AppClock.sched(2.0, {
        "Initiating audio-through synth...".postln;
        initAudioThrough.start;
        nil // do not repeat it
    });
};

loadComponents = {
	loadCommonComponents.();

	"Loading world...".postln;
	if (this.executeFile(~currentDir +/+ "world.scd").isNil.not) {
		postf("OK\n\n")
	};
};

loadComponents__test = {
	postf("\n------------\nUnit testing\n------------\n");
	loadCommonComponents.();
	doTest.();
};


if (isTest) {
	// UNIT-TESTING
	~scsynth = s = Server.internal;
	s.boot;
	~scsynth.waitForBoot(loadComponents__test);
} {
	// ORDINARY START
	if (~scsynth == Server.internal) {
		s = ~scsynth; // default server
		s.options.numInputBusChannels = 4;
		s.options.numOutputBusChannels = 12; // 10 outputs on the interface + one aux stereo output
		s.options.memSize = 262144;
		s.options.blockSize = 512;
		s.latency = 0.05;
		s.boot;
		~scsynth.waitForBoot(loadComponents);
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
				loadComponents.()
			} { |error|
				postf("ERROR: server % at % is not running!\n", ~scsynth.name, ~scsynth.addr.ip);
				error.postln;
			}
		}.defer(1);
	};
};

doTest = {
	// Unit tests:
	// $sclang /path/to/envi.scd test
	//
	// WARNING! Start withing working dir (where envi.scd lives).
	//
	var test_initSynth = {
		// write empty output to levelsList
		a = ~initSynth.(\moog, params: [\out, 8, \amp, 0.001]);
		0.5.wait;
		l = List.new;
		o = OSCFunc({ |i| l.add(i[3..]); }, '/internalOutLevels');
		f = OSCFunc({ |msg| k = msg }, '/n_info');
		~scsynth.sendMsg("/n_query", a);
		0.5.wait;
		~scsynth.sendMsg("/n_free", a);
		o.free;
		f.free;

		UnitTest.new.assertEquals(a, k[1], "~initSynth: node id");
		UnitTest.new.assertEquals(k[2], ~rootAr, "~initSynth: node is within root group");
		UnitTest.new.assert(all {: x[0..15], x <-l }.flatten.every(_ == 0), "~initSynth: silent channels before");
		UnitTest.new.assert(all {: x[20..], x <-l }.flatten.every(_ == 0), "~initSynth: silent channels after");
		UnitTest.new.assert(all {: x[16..19], x <-l }.flatten.every(_ > 0), "~initSynth: active channels");
	};


	var test_cleanPaths = {
		var testDir = PathName(thisProcess.nowExecutingPath).pathOnly +/+ "test";
		testDir.mkdir;
		["kraut.scd", "buzz.scd", "solo.scd", "band.scd"].do { |name|
			File.new(testDir +/+ name, "w").close;
		};
		a = List[
			testDir +/+ "kraut.scd",
			"test/kraut.scd",
			"test/buzz.scd",
			"test/solo.scd",
			"test/band.scd",
			testDir +/+ "solo.scd",
			testDir +/+ "band.scd",
			testDir
		];
		c = cleanPaths.(a).split($\n);

		UnitTest.new.assertEquals(c.size, 5, "cleanPaths: size");
		UnitTest.new.assertEquals(c[4], "", "cleanPaths: last item empty");
		UnitTest.new.assert(c[..3].every(_.beginsWith("/")), "cleanPaths: absolute path");
	};

	test_initSynth.();
	test_cleanPaths.();
	0.exit; // exit after testing is done
};
)