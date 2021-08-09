// Sympli Romatikó
// module: Environment
// -------------------
// connecting together World, Scheduler and SynthDefs
//

// To get it up and running
//
// start OSCeleton:
// $ ~/Documents/run/Kinect/OSCeleton/osceleton -p 57120 -oz -0.3
//
// manipulate -oz to obtain ~3m from the sensor and to stay
// in the center of a calibration layout
//
// run glview and adjust tilt
// $ /usr/local/Cellar/libfreenect/0.5.7/bin/freenect-glview
//
// start OSCeleton again
//
// RPI (192.168.1.131 for eth0, 192.168.1.106 for wlan)
// ssh to RPI:
// $ ssh pi@192.168.1.131
//
// Visual server communication (RPI)
// ~vis = Server("vis", NetAddr.new("192.168.1.106", 7110));
// ~vis.sendMsg("/run");
// ~vis.sendMsg("/stop");
// ~vis.free

(
var srEnv;
var loadComponents, loadCommonComponents;
var initAudioThrough;
var doTest, loadComponents__test;
var conf=Dictionary.new;
var confKeys = [ // keys to save to conf file
    'surround', 'depth',
    'inbus', 'outbus', 'audioThruBus', 'inbus', 'outbus',
    'receiver', 'speakers'
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
// var seqPathsFile = currentDir +/+ "conf/sequences.conf";
var seqPathsFile = "/Users/deko/Documents/dev_music/sympli_romatiko/conf/sequences.conf";

var seqPaths = ["Load..."];
var confFile = currentDir +/+ "conf/envi.conf";
var emptySequence = {
    // Default empty sequence.
    (
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
    )
};

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
    postf("! Problem loading sequences, cannot access file %\n", seqPathsFile);
};
seqPaths = seqPaths.asList;

srEnv = Environment.make {
    ~currentDir = currentDir;
    ~seqPaths = seqPaths;
    // assume the World is a cube
    ~worldSize = (Window.screenBounds.height*0.623).floor;
    // ~scsynth = Server("scsynth", NetAddr.new("192.168.1.106", 57110));
    ~scsynth = Server.internal;
    ~surround = conf.atFail(\surround, {"ambisonic"});
    ~depth = conf.atFail(\depth, {3.5});
    ~inbus = conf.atFail(\inbus, {4});
    ~outbus = conf.atFail(\outbus, {0});
    ~audioThruBus = conf.atFail(\audioThruBus, {[10, 11]}); // two buses for audio through on skeletons hands
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

    ~sequence = emptySequence.();
    ~specs = Dictionary[
        \freq -> \freq.asSpec,
        \cutoff -> \freq.asSpec,
        \dur -> \delay.asSpec,
        \delay -> \delay.asSpec,
        \detune -> \detune.asSpec,
        \rate -> \rate.asSpec,
        \controlbus -> \controlbus.asSpec,
        \azimuth -> ControlSpec(-1pi, 1pi, \lin, 0.01, 0),
        \distance -> ControlSpec(0, 2.sqrt, \lin, 0.01, 0),
        \elevation -> ControlSpec(-0.5pi, 0.5pi, \lin, 0.01, 0),
        \velocity -> \unipolar.asSpec,
        \depth -> ControlSpec(1, 10, \lin, 0.1, 5),
        \offset -> \midinote.asSpec,
        \rq -> \rq.asSpec,
        \lfreq -> ControlSpec(0.01, 100, \lin, 0.01, 0.5, units: " Hz"), // dummy, 0.01..1.000 | 1..100
        \min -> ControlSpec(-1, 0.99, \lin, 0.01, -1),
        \max -> ControlSpec(-0.99,  1, \lin, 0.01, 1),
        \amp -> ControlSpec(0, 1, \amp, 0, 0),
        \room -> ControlSpec(0.0,  1.0, \lin, 0.01, 0.5),
        \damp -> ControlSpec(0.0,  1.0, \lin, 0.01, 0.5),
        \maxdelaytime -> ControlSpec(0.001,  2.0, -3, 0.001, 0.2),
        \delaytime -> ControlSpec(0.001,  2.0, -3, 0.001, 0.2),
        \decaytime -> ControlSpec(-5,  5, \lin, 0.1, 1),
        \mul -> \unipolar.asSpec, // dummy
        \add -> \unipolar.asSpec, // dummy
        \dummy -> \bipolar.asSpec // dummy
    ];
    ~defaultParams = (
        \ar: #[
            \freq, \detune, \delay, \cutoff, \room, \rq, // knobs in GUI
            \rate, \amp // sliders in GUI
        ],
        \kr: #[
            \lfreq, \dummy, \min, \dummy, \max, \dummy,  // knobs in GUI
            \dummy, \dummy // sliders in GUI
        ],
    );

    ~synths = (
        // types are: \gen - generator; \gran - granulator
        \silent: ( \type: \gen ),
        \atru: ( \type: \gen ),
        \buzz: ( \type: \gen ),
        \pole: ( \type: \gen, \params: [\freq, \detune, \room, \cutoff, \decaytime, \rq, \lfreq, \amp] ),
        \bass: ( \type: \gen ),
        \moog: ( \type: \gen ),
        \lowe: ( \type: \gen ),
        \wind: ( \type: \gen, \params: [\freq, \detune, \delay, \cutoff, \decaytime, \rq, \rate, \amp] ),
        \glide: ( \type: \gen ),
        \komar: (\type: \gen, \params: [\freq, \maxdelaytime, \cutoff, \delaytime, \rq, \decaytime, \detune] ),
        \neural: ( \type: \gen ),
        \entro: ( \type: \gen, \params: [\freq, \detune, \min, \cutoff, \max, \rq, \dummy, \amp] ),
        \humm: ( \type: \gen ),
        \melo: ( \type: \gen, \params: [\freq, \detune, \min, \cutoff, \max, \rq, \dummy, \amp] ),
        \cmb: ( \type: \gen ),
        \probe: ( \type: \gen ),
        \pulse: ( \type: \gen ),
        \therem: ( \type: \gen ),
        \gauss: ( \type: \gen ),
        \loop: ( \type: \gran ),
        \loopdel: ( \type: \gran ),
        \drone: ( \type: \gran ),
        \greg: ( \type: \gran ),
        \scratch: ( \type: \gran ),
        \unst: ( \type: \gran ),
        \gust: ( \type: \gran ),
        \kick: ( \type: \gen ),
        \shov: ( \type: \gen ),
    );
    ~lfos = (
        \ksine: ( \type: \gen ),
        \kpulse: ( \type: \gen ),
        \ksaw: ( \type: \gen ),
        \ktri: ( \type: \gen ),
        \ksawprc: ( \type: \gen ),
        \klipnoise: ( \type: \gen ),
        \klfno0: ( \type: \gen ),
        \klfno1: ( \type: \gen ),
        \klfno2: ( \type: \gen ),
        \kstepno: ( \type: \gen ),
        \ksinmod: ( \type: \gen ),
        \ksawmod: ( \type: \gen ),
        \keyscale: ( \type: \gen ),
    );
    // fill default params if no parameters for a synth provided
    ~synths.keys.do { |name|
        if (~synths[name][\params].isNil) {~synths[name][\params] = ~defaultParams[\ar]};
    };
    ~lfos.keys.do { |name|
        if (~lfos[name][\params].isNil) {~lfos[name][\params] = ~defaultParams[\kr]}
    };

    ~clipInc = {
        // Increments `in` until `in + step` reaches `hi`, then resets to `lo`.
        arg in=0, step=1, lo=0, hi=inf;
        ((in + step).clip(lo, hi) % hi).clip(lo, hi)
    };

    // Fills params from incoming data. Uses default value,
    // if a param specified in a synthDict is missing.
    //
    //     `synth` (Dictionary) - element to which the key `params` should be added
    //     `container` (Dictionary) - `particles` or `synthsLFO` depending on the type of synth
    //     `synthDict` (Dictionary) - where to look for default params of the synth (~synths or ~lfos)
    ~fillSynthParams = { |synth, synthDict|
        var params = Dictionary.newFrom(synth[\params] ? []);
        synthDict.at(synth[\name].asSymbol)[\params].do { |parm|
            if (params.keys.includes(parm).not) {
                params[parm] = ~specs[parm].default
            }
        };
        params
    };


    // Creates an .ar synth on Server.
    // Returns ID of the Node created.
    // `synth` - short name (i.e. \moog or \buzz).
    // `params` - anything convertable to Dictionary (i.e. list of pairs).
    ~initSynth = { |synth, node, spatial, params|
        var message;
        node = node ? ~scsynth.nextNodeID;
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
        postf("-> ~initSynth \"%\" at node %\n", synth, node);
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


    // Creates a .kr synth on Server.
    // Returns nil, if outbus is not given (.kr doesn't make
    // sense without outbus).
    ~initLFO = { |synth, node, params|
        var message;
        node = node ? ~scsynth.nextNodeID;
        params = Dictionary.newFrom(params ? []);
        if (params.keys.includes(\bufnum).not) {
            params[\bufnum] = ~getDefaultBuffer.(synth).bufnum;
        };
        if (params.keys.includes(\out)) {
            // report
            postf("-> ~initLFO \"%\" at node %\n", synth, node);
            params.keysValuesDo { |k,v| postf("\t%: %\n", k, v); };
            message = ["/s_new", synth, node, 0, ~rootKr] ++ params.asKeyValuePairs;
            ~scsynth.listSendMsg(message);
        } {
            node = nil
        };
        node
    };


    // Sends bundle to server, places everything mentioned to the top level group.
    // This allows for an arbitrary number of synths and flexible structure.
    // Returns node for registration purposes.
    ~initGroup = { |data, time=0.1|
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
        // return group node id
        node
    };


    ~spatial = {
        format("%%", ~surround[0], ~speakers.items.size)
    };


    // Release all synths from group, wait until released, then remove
    // group node from server.
    ~groupFree = { |node, release|
        release = release ? 2;
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


    // Sends message to the World.
    ~sendMessage = { |msg, params, lag=0.001|
        if (msg.isNil.not) {
            ~receiver.sendBundle(lag, [msg] ++ (params ? []));
        };
    };


    // Sends particle creation message to the World:
    // [mass, x, y, z, age, spring, source, synth:node, synth:name, synth:params]
    ~sendParticle = { |particle, synth|
        var data, x, y, z, spring, source;
        #x, y, z = [\x, \y, \z].collect({ |k|
            particle.atFail(k, { -1 })
        });
        spring = particle.atFail(\spring, {0});
        if (spring.booleanValue) {
            source = particle.atFail(\source, {0});
        } {
            source = 0
            };
        data = [
            particle[\mass],
            x,
            y,
            z,
            particle.atFail(\age, {inf}), // if inf, particle will be waiting for the romoval signal
            spring, // spring:0|1
            source,
            synth.atFail(\node, {-1}), // node cannot be -1, substitute it with real node id
            synth[\name]
        ] ++ (synth[\params] ?? []);
        ~sendMessage.('/particle', data);
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


    ~getDefaultBuffer = { |synth|
        var container, buff;
        synth = synth.asSymbol;
        if (~synths.keys.includes(synth)) {
            container = ~synths
        } {
            container = ~lfos
        };
        if (container[synth][\type] == 'gen') {
            buff = ~sequence.scales[0]
        };
        if (container[synth][\type] == 'gran') {
            buff = ~sequence.samples.choose
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


    // Stops sequence and all its events.
    // Warning! Order matters!
    ~stopSequence = {
        fork {
            "-> Caught signal: <stop / reset current task>".postln;
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
            ~sequence.samples.do { |buff| buff.free};
            ~sequence.voices.do { |buff| buff.free};
            ~sequence.scales.do { |buff| buff.free};
            0.5.wait;
            "INFO: done stopping sequence".postln;
        };
    };


    // Loads sequence from file.
    ~loadSequence = { |path|
        var index = 0;
        ~sequence = emptySequence.();
        // if no path is given, load the top one
        if (path.isNil) { path = ~seqPaths[1] };
        postf("Loading sequence %...\n", PathName.new(path).fileName);
        path = path.absolutePath;
        if (this.executeFile(path).isNil.not) {
            "OK...".postln;
            if (~seqPaths.asString.contains(path).not) {
                ~seqPaths.insert(1, path); // to the top, but after ["Load.."]
            };
            index = ~getIndex.(~seqPaths, path)
        } {
            "Loading sequence has failed!".postln;
            try {
                ~seqPaths.removeAt(~getIndex.(~seqPaths, path));
            };
        };
        index;
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

    ~reportBufLoad = { |buff|
        var report;
        report = Task({
            inf.do { |j|
                if (buff.numFrames.isNil.not) {
                    postf("\nloaded %\n", buff);
                    report.stop;
                };
                if (j > 500) {
                    postf("\n! Loading buffer % failed%!",
                        buff.bufnum, buff.path ? ""
                    );
                    report.stop;
                };
                post(".");
                0.1.wait
            };
        }).play
    };

    // Creates a tree out of server message \g_queryTree.reply
    // Copied and re-formatted from Server.queryAllNodes
    ~formatSrvTree = { |msg|
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
    "-> Caught signal: <shut down>".postln;
    ~stopSequence.();

    "INFO: Freeing internal buffers".postln;
    ~defaultBuff.free;
    ~internalBuff.free;

    "INFO: Killing audio-through".postln;
    ~groupFree.(~nodeAudioThrough);

    "INFO: Disconnecting from synth server...".postln;
    ~scsynth.addr.disconnect;

    "INFO: Saving environment conf...".postln;
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

    // Save ~seqPaths to sequences file, omitting the first item ("Load...")
    if (seqPaths.size > 1) {
        "INFO: Saving paths to sequences...".postln;
        seqPathsFile = File.new(seqPathsFile, "w");
        seqPathsFile.write(cleanPaths.(~seqPaths[1..]));
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
        "! cannot start audio through synth, timeout 10 sec."
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

    "-> Loading world...".postln;
    if (this.executeFile(~currentDir +/+ "world.scd").isNil.not) {
    // if (this.executeFile(~currentDir +/+ "world3d.scd").isNil.not) {
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
        s.options.numOutputBusChannels = 10; // 8 outputs on the interface + one aux stereo output
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
                postf("! server % at % is not running!\n", ~scsynth.name, ~scsynth.addr.ip);
                error.postln;
            }
        }.defer(1);
    };
};

doTest = {
    // Unit tests:
    // $sclang /path/to/envi.scd test
    //
    // WARNING! Start within working dir (where envi.scd lives).
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