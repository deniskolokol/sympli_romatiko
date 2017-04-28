(
var krN, arN;
var matrix, matrixPast, initMatrix;
var synthOnOff, synthSend, synthReRoute, synthShortName;
var paramDefs, lfoScope, minMax2mulAdd,
    paramsAr, paramsKr, controlsAr, controlsKr,
    synthParams, defaultEnvelope, levelsAr,
    synthsAr, synthsKr, synthNamesAr, synthNamesKr,
    synthConfig;
var outBus=(0..Server.default.options.numAudioBusChannels-1),
    internalBus=(10..Server.default.options.numAudioBusChannels-1),
    krBus = (0..Server.default.options.numControlBusChannels-1);
var oscSynthVal, trigID;
var internalInLevels, internalOutLevels,
    oscInternalInLevels, oscInternalOutLevels;
var midiGui, midiSet, midiOnOff, midiNextSynth, arKrMidi;
var doubleClick, clickElement, clickBootSec=Date.getDate.rawSeconds;

var win;
var paneMatrix, paneSettings, paneIndicators, paneSynths, paneSynth,
    paneArSynths, paneKrSynths, paneGrid, panel, matrixButtons;
var synthType, synthIn, synthOut;
var master, crossfade;
var paneWidth, paneHeight;
var button, buttonCheckbox, buttonCheckboxFlow, knob, slider,
    dropdown, compView, compViewFlow, levelInd, sText;
var colorBtUp=Color.grey(0.6),
    colorBtDown=Color.blue,
    colorBtLabel=Color.grey(0.2),
    colorStringBg=Color.grey(alpha:0.1),
    colorString=Color(0.8, 0.8, 0.8);
var color=Color.grey(0.2),
    highlighted=Color.grey(0.8), // Color.white
    transparent=Color.grey(alpha:0.01),
    font=Font("Monaco", 14),
    fontSmall=Font("Monaco", 10),
    fontLarge=Font("Monaco", 14),
    fontGiant=Font("Monaco", 24),
    fontColor=Color.grey(0.9);

var parmName, parmVal;
var krSetParam;
var clean;
var failures, errors, tests, testReport;

// constants
var s__SYNTHNAME = "sr__(e|g|p|k|r|s){1}__[a-zA-Z0-9]+";
var f__CURR_DIR = PathName(thisProcess.nowExecutingPath).pathOnly;

// synths and params
paramDefs = (
    azimuth:   ( label: "azi",    minval: -1pi,   maxval: 1pi,    step: 0.01,  default: 0   ),
    distance:  ( label: "dist",   minval: 0,      maxval: 2.sqrt, step: 0.01,  default: 0   ),
    elevation: ( label: "elev",   minval: -0.5pi, maxval: 0.5pi,  step: 0.01,  default: 0   ),
    velocity:  ( label: "vel",    minval: 0,      maxval: 1,      step: 0.01,  default: 0   ),
    depth:     ( label: "depth",  minval: 1,      maxval: 10,     step: 0.1,   default: 5   ),
    offset:    ( label: "offset", minval: 0,      maxval: 127,    step: 1,     default: 36  ),
    cutoff:    ( label: "cutoff", minval: 50,     maxval: 10000,  step: 1,     default: 1000),
    rq:        ( label: "RQ",     minval: 0.01,   maxval: 0.9,    step: 0.01,  default: 0.5 ),
    lfo:       ( label: "lfo",    minval: 0.01,   maxval: 100,    step: 0.01,  default: 0.5 ), // 0.001..1.000 | 1..100
    min:       ( label: "min",    minval: -1,     maxval: 0.99,   step: 0.01,  default: -1  ),
    max:       ( label: "max",    minval: -0.99,  maxval: 1,      step: 0.01,  default: 1   ),
    mul:       ( label: "mul",    minval: 0,      maxval: 1,      step: 0.01,  default: 1   ),
    amp:       ( label: "amp",    minval: 0,      maxval: 1,      step: 0.01,  default: 1   ),
    add:       ( label: "add",    minval: 0,      maxval: 1,      step: 0.001, default: 0   ),
);
// modulatable
paramsKr = #[\mul, \add];
paramsAr = #[\azimuth, \distance, \elevation, \velocity];
// paramsAr = #[\cutoff, \distance, \elevation, \velocity]; // TEST!!
// controllable via GUI
// XXX - \amp is controlled by ambisonic or on mixing board. substitute with compression(?)
controlsAr = #[\offset, \cutoff, \rq, \amp];
controlsKr = #[\lfo, \min, \max, \depth];

//synthNamesAr = ~synths.keys.asArray;
synthNamesAr = #[
    "sr__e__tbl", "sr__e__sawy", "sr__e__dust", "sr__e__wind", "sr__e__dempad"
];
synthNamesKr = #[
    "sr__k__sine", "sr__k__saw", "sr__k__tri",
    "sr__k__lfnoise0", "sr__k__lfnoise1", "sr__k__lfnoise2",
    "sr__k__clipnoise", "sr__k__stepnoise",
    "sr__k__sinmod", "sr__k__sawmod"
];
synthsAr = all {:
    (
        name: syn.asString,
        params: controlsAr ++ paramsAr
    ),
    syn <- synthNamesAr
};
synthsKr = all {:
    (
        name: syn.asString,
        params: controlsKr + paramsKr
    ),
    syn <- synthNamesKr
};

// initialize main matrix container
#krN, arN = [8, 8];

levelsAr = Array.fill(arN, { nil });
defaultEnvelope = Env.adsr(0.2, 0.5, 0.5, 1);

//
// bookmark
// define synth config (synth names, their params and envelopes)
// synthConfig = (
//     set: { |self, synthname, num, param|
//         self[synthname][num] = param
//     },
//     get: { |self, synthname, num|
//         self[synthname][num]
//     },
//     getByName: { |self, synthname, paramName|
//         var result;
//         self[synthname].do { |param|
//             if (paramName == param) {
//                 result = param
//             }
//         };
//         result
//     }
// );
// (synthNamesAr+synthNamesKr).do { |name|
//     synthConfig[name] = Array.fill(8, {nil});
//     #[
//         \offset, \cutoff, \rq, \amp, // default controllable params
//         \azimuth, \distance, \elevation, \velocity // default modulatable params
//     ].do { |parm, num|
//         synthConfig.set(name, num, parm);
//     };
// };

synthParams = { |synthname|
    // Fills up a dictionary with default params for synth name.
    var params, result, val, buff;

    // fill list of param names
    (synthsAr ++ synthsKr).do { |def|
        if (def.name.asSymbol == synthname.asSymbol) {
            params = def.params;
        }
    };

    // find and fill initial values of params
    if (params.isNil.not) {
        result = ();
        params.do { |parm, i|
            val = paramDefs.atFail(parm, {(default: 0)})[\default];
            result[parm] = val
        }
    };

    result
};

// initializes matrix with default values
initMatrix = {
    var arSynthName = { |ind|
        // XXX - to do:
        //       return this for i = 0..3, the rest should be effects
        synthNamesAr[ind % synthNamesAr.size]
    };

    // TODO: load it from config file

    // return
    (
        setParam: { |self, arKr, pos, param|
            self[arKr][pos].params = param
        },
        fillDefaultParams: { |self, pos, synthName|
            var arKr;
            var paramConf = (
                ar: #[
                    \offset, \cutoff, \rq, \amp, // 1..4 - controllable
                    \azimuth, \distance, \elevation, \velocity // 5..8 - modulatable
                ],
                kr: #[\lfo, \min, \max, \depth, \mul, \add]
            );
            arKr = if (synthNamesAr.includes(synthName)) {\ar} {\kr};
            self[arKr][pos].params = paramConf[arKr]
        },
        ar: Array.fill(arN, { |i|
            (
                synthname: arSynthName.(i),
                inbus: ~inbus,
                outbus: outBus.select(_.even)[i], // prepared to stereo by default
                node: 0,
                active: false,
                params: synthParams.(arSynthName.(i)),
                // paramsNew: fillDefaultParams(i, arSynthName.(i)), // bookmark
                envelope: defaultEnvelope,
                val: 0,
            )}
        ),
        kr: Array.fill(krN, { |i|
            (
                synthname: synthNamesKr[i],
                inbus: nil,
                outbus: krBus[i],
                node: 0,
                active: true,
                params: synthParams.(synthNamesKr[i]),
                val: 0,
            )}
        ),
    );
};
matrix = initMatrix.();
matrixPast = initMatrix.();

// first trigger ids for .ar and .kr synths
trigID = (kr: 60, ar: 80);

// default control stripes for MIDI control
arKrMidi = (\ar: [0, 1], \kr: [0, 1]);
midiGui = (
    ar: Array.fill(arN, { Array.fill(controlsAr.size + 1, { nil }) }), // +1 for synth on/off
    kr: Array.fill(krN, { Array.fill(controlsKr.size, { nil }) }),
);
paneSynth = (
    ar: Array.fill(arN, { nil }),
    kr: Array.fill(krN, { nil }),
);
synthType = (
    ar: Array.fill(arN, { nil }),
    kr: Array.fill(krN, { nil }),
);

// level indicator
oscSynthVal = OSCFunc({ |msg, time, addr, recvPort|
    var arKr, ind;
    if ((msg[2] >= trigID[\kr]) && (msg[2] < (trigID[\kr] + krN))) {
        arKr = 'kr';
    };
    if ((msg[2] >= trigID[\ar]) && (msg[2] < (trigID[\ar] + arN))) {
        arKr = 'ar';
    };
    if (arKr.isNil.not) {
        ind = msg[2] - trigID[arKr];
        matrix[arKr][ind][\val] = if (msg[3].isNaN) {0} {msg[3].asFloat}
    };
}, '/tr');

// internal levels
internalInLevels = Array.fill(s.options.numInputBusChannels, {nil});
internalOutLevels = Array.fill(s.options.numOutputBusChannels, {nil});
oscInternalInLevels = OSCFunc({ |msg, time, addr, recvPort|
    {
        internalInLevels.do { |elem, j|
            elem.peakLevel = msg[3+(j*2)].ampdb.linlin(-80, 0, 0, 1);
            elem.value = msg[3+(j*2+1)].ampdb.linlin(-80, 0, 0, 1);
        }
    }.defer;
}, '/internalInLevels');
oscInternalOutLevels = OSCFunc({ |msg, time, addr, recvPort|
    {
        internalOutLevels.do { |elem, j|
            elem.peakLevel = msg[3+(j*2)].ampdb.linlin(-80, 0, 0, 1);
            elem.value = msg[3+(j*2+1)].ampdb.linlin(-80, 0, 0, 1);
        }
    }.defer;
}, '/internalOutLevels');

// 0.01..1.00 | 1..1000
lfoScope = { |n|
    case
    {n <= 0.5} { n.linexp(0.01, 0.5, 0.01, 1) }
    {n > 0.5 && n <= 0.75} {n.lincurve(0.5, 0.75, 1, 10, 3)}
    {n > 0.75} {n.lincurve(0.75, 1, 10, 100, -3)}
};

// calculates \mul and \add based on \min and \max
minMax2mulAdd = { |min, max|
    var mul, add;
    mul = max.absdif(min) * 0.5;
    add = min + mul;
    [mul, add];
};


// updates .kr param
// if updated param is \min or \max, updates \mul and \add, too
krSetParam = { |i, minVal, maxVal|
    var mul, add;
    var defPar = matrix.kr[i][\params];
    #mul, add = minMax2mulAdd.(minVal, maxVal);
    defPar[\min] = minVal;
    defPar[\max] = maxVal;
    defPar[\mul] = mul;
    defPar[\add] = add;
};


// synth functions
synthShortName = { |name|
    // Short synth name starts from 7th symbol (after "\sr__?__").
    if (s__SYNTHNAME.matchRegexp(name.asString)) {
        name[7..]
    } {
        name
    };
};


synthOnOff = { |arKr, pos, params|
    // Switches synth ON, if its \active in the matrix, OFF otherwise.
    // Returns Node ID.
    var def, parm, rel, node=0;
    def = matrix[arKr][pos];
    params = params ? Dictionary[];
    if (def.active) {
        parm = merge( // update default params by params from matrix
            synthParams.(def[\synthname]), def[\params] ? Dictionary[], { |a, b| b }
        );
        parm = merge( // update parm by `params`
            parm, params, { |a, b| b }
        );
        def[\params] = parm; // save updated params to matrix
        parm = merge( // update parm by `trigID`
            parm, (trigID: trigID[arKr]+pos), { |a, b| b }
        );
        if (arKr == 'ar') {
            parm.keysValuesDo { |k, v|
                if (v.asString.beginsWith("kr_")) {
                    parm[k] = v.asString.replace("kr_", "c").asSymbol
                }
            };
            node = ~initSynth.(def[\synthname],
                inbus:def[\inbus],
                outbus:def[\outbus],
                params:parm.getPairs
            );
        } {
            node = ~modulatorInit.(def[\synthname],
                inbus:def[\inbus],
                outbus:pos,
                params:parm.getPairs
            );
        };
    } {
        rel = params.atFail(\rel, {crossfade.value});
        ~groupFree.(def[\node], rel)
    };
    def[\node] = node;
};


synthSend = { |arKr, pos, params|
    // Sends params to the given node, specified in matrix.
    // Param's value can either be set directly or "mapped" to a .kr bus.
    // If param is mapped, its value is String formatted as follows:
    // "kr_<x>", where "x" is a .kr bus number.
    var def, paramsSend, paramsMap;

    def = matrix[arKr][pos];
    params = params ? def.params;
    if (def.active) {
        paramsSend = params.reject { |item| item.asString.beginsWith("kr_") };
        if (paramsSend.size > 0) {
            ~sendToSrv.([["/n_set", def[\node]] ++ paramsSend.getPairs]);
        };
        paramsMap = params.select { |item| item.asString.beginsWith("kr_") };
        if (paramsMap.size > 0) {
            paramsMap = paramsMap.collect { |item| item.asString[3..] };
            paramsMap = all {: [k, paramsMap[k].asInteger], k <- paramsMap.keys }.flatten;
            ~sendToSrv.([["/n_map", def[\node]] ++ paramsMap]);
        };
    };
};

synthReRoute = { |arKr, pos, route|
    var def = matrix[arKr][pos];
    if (def.active) {
        ~sendToSrv.([["/n_set", def[\node]] ++ route])
    };
};


// GUI
win = Window("ctrl matrix", Window.screenBounds.width@Window.screenBounds.height);

paneWidth = { |par, scale=1| (par.bounds.width * scale - 6).floor };
paneHeight = { |par, scale=1| (par.bounds.height * scale - 6).floor };
button = { |par, label, action, scaleH=1, scaleW=1, colorLabel, colorBg|
    colorLabel = colorLabel ? colorBtLabel;
    colorBg = colorBg ? colorBtUp;
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH)).states_([
        [label, colorLabel, colorBg]
    ])
    .font_(Font("Helvetica", 12))
    .action_({ |bt| action.(bt.value) })
    .canFocus_(false);
};
buttonCheckbox = { |par, label, action, value, bounds, colorUpLb, colorUpBg, colorDwLb, colorDwBg|
    var labelUp, labelDw;

    colorUpLb = colorUpLb ? colorBtLabel;
    colorUpBg = colorUpBg ? colorBtUp;
    colorDwLb = colorDwLb ? colorString;
    colorDwBg = colorDwBg ? colorBtDown;
    if (label.class == Array) {
        #labelUp, labelDw = label;
    } {
        #labelUp, labelDw = [label, label];
    };
    Button(par, bounds).states_([
        [labelUp, colorUpLb, colorUpBg],
        [labelDw, colorDwLb, colorDwBg]
    ])
    .value_(value)
    .action_({ |bt| action.(bt.value) })
    .font_(Font("Helvetica", (bounds.asSize.height*0.5).trunc))
    .canFocus_(false);
};
buttonCheckboxFlow = { |par, label, action, value, scaleH=1.02, scaleW=1.02, colorUpLb, colorUpBg, colorDwLb, colorDwBg|
    var bounds = paneWidth.(par, scaleW)@paneHeight.(par, scaleH);
    buttonCheckbox.(par, label, action, value, bounds, colorUpLb, colorUpBg, colorDwLb, colorDwBg);
};
knob = { |par, label, spec, action, initVal=0, layout='vert', scaleW=1, scaleH=1|
    EZKnob(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH),
        label, spec,
        { |ez| action.(ez.value) }, initVal,
        layout: layout
    )
    .font_(Font("Helvetica", 10))
    .setColors(subtract(par.background, par.background.alpha));
};
slider = { |par, label, spec, action, initVal, layout='horz', scale=1|
    var labelWidth=0, numberWidth=45;
    var bounds=paneWidth.(par)@20;
    if (label.isNil.not) { labelWidth = label.size * 5 };
    if (layout == 'horz') {
        bounds = (paneWidth.(par, scale))@20;
        numberWidth = 30;
    } {
        bounds = 30@(paneHeight.(par, scale))
    };
    if (initVal.isNil) { initVal = spec.default };
    EZSlider(par, bounds, label, spec, { |ez| action.(ez.value) }, initVal,
        labelWidth: labelWidth, numberWidth: numberWidth, layout: layout)
    .font_(Font("Helvetica", 10))
    //.setColors(subtract(par.background, par.background.alpha))
    .setColors(subtract(par.background, par.background.alpha), fontColor)
};
dropdown = { |par, label, items, action, initVal=0, scale=1|
    var labelWidth=0;
    if (label.isNil.not) { labelWidth = label.size * 9};
    EZPopUpMenu(par,
        bounds: paneWidth.(par, scale)@20,
        label: label,
        items: items,
        globalAction: action,
        initVal: initVal,
        labelWidth: labelWidth
    )
    .font_(Font("Helvetica", 11))
    .setColors(colorStringBg, colorString)
};
compView = { |par, color, scaleW=1, scaleH=1|
    if (color.isNil) { color = transparent };
    CompositeView(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH)
    ).background_(color);
};
compViewFlow = { |par, color, margin, gap, scaleW=1, scaleH=1|
    var vw;
    vw = compView.(par, color, scaleW, scaleH);
    vw.decorator = FlowLayout(vw.bounds, margin ? 1@1, gap ? 1@1);
    vw
};
levelInd = { |par, default=0, scaleW=1, scaleH=1|
    LevelIndicator(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .background_(Color.clear)
    .value_(default)
    .warning_(0.7)
    .critical_(0.9)
    .drawsPeak_(true)
};
sText = { |par, string, stringColor, stringFont, scaleH, scaleW=0.5|
    var st, height;
    height = if (scaleH.isNil) { 20 } { paneHeight.(par, scaleH) };
    st = StaticText(par, paneWidth.(par, scaleW)@height);
    st.string = string;
    st.font = stringFont ? font;
    st.stringColor = stringColor ? fontColor;
    st
};

// panels
paneMatrix = CompositeView(win,
    win.bounds.width@win.bounds.height
).background_(color);
paneMatrix.decorator = FlowLayout(paneMatrix.bounds);

paneSettings = compViewFlow.(paneMatrix, scaleW: 0.2, scaleH: 0.6, gap:5@5);

// internal levels (dBFS)
paneIndicators = compViewFlow.(paneSettings, margin:10@10, scaleH:0.25);
panel = compViewFlow.(paneIndicators, scaleW:0.1);
sText.(panel, "0", stringFont:fontSmall, scaleH:0.15, scaleW:0.8).align_(\right);
sText.(panel, "", stringFont:fontSmall, scaleH:0.65, scaleW:1); // gap
sText.(panel, "-80", stringFont:fontSmall, scaleH:0.2, scaleW:0.8).align_(\right);

panel = compViewFlow.(
    paneIndicators,
    scaleW:(s.options.numInputBusChannels / (
        s.options.numInputBusChannels + s.options.numOutputBusChannels
    ))
);
s.options.numInputBusChannels.do { |j|
    internalInLevels[j] = levelInd.(
        panel,
        scaleH:0.85,
        scaleW:s.options.numInputBusChannels.reciprocal
    ).numTicks_(11).numMajorTicks_(3);
};
sText.(panel, "inputs", stringFont:fontSmall, scaleH:0.15);
panel = compViewFlow.(
    paneIndicators,
    scaleW: 0.85 * (s.options.numOutputBusChannels / (
        s.options.numInputBusChannels + s.options.numOutputBusChannels
    ))
);
s.options.numOutputBusChannels.do { |j|
    internalOutLevels[j] = levelInd.(
        panel,
        scaleH:0.85,
        scaleW:s.options.numOutputBusChannels.reciprocal + 0.02
    ).numTicks_(11).numMajorTicks_(3);
};
sText.(panel, "outputs", stringFont:fontSmall, scaleH:0.15);

master = slider.(paneSettings, "Master", \db.asSpec,
    { |sl| s.volume.volume = sl.value },
);
crossfade = slider.(paneSettings, "X-Fade",
    [0.5, 5, \lin, 0.1, 2].asSpec,
);
buttonCheckboxFlow.(paneSettings, ["PANIC", "UP!"],
    { |val|
        if (val.booleanValue) {
            // switch everything OFF
            matrix.keys.do { |arKr|
                // clean stop via GUI
                midiGui[arKr].flatten.do { |elem|
                    if (elem.class == QButton) {
                        if (elem.states.size == 2) { elem.valueAction_(0) };
                    };
                };
                // check nodes, just to be sure
                matrix[arKr].do { |def| ~groupFree.(def[\node], 0.1)};
            };
        } {
            // start all .kr synths
            matrix[\kr].size.do { |pos|
                synthOnOff.(\kr, pos);
            };
        };
    },
    scaleH: 0.07, scaleW: 0.98,
    colorUpLb:Color.white,
    colorUpBg:Color.red,
);

// .ar synth panel and controls
paneArSynths = compViewFlow.(paneMatrix, scaleW: 0.8, scaleH: 0.6);
paneSynths = compViewFlow.(paneArSynths);
arN.do { |i|
    var paneKnobs, paneSlid, envelope, level;

    paneSynth[\ar][i] = compViewFlow.(paneSynths, scaleW: (1/arN)+0.004);
    panel = compViewFlow.(paneSynth[\ar][i], scaleW: 0.92, scaleH: 0.87);

    // .ar synth
    synthIn = dropdown.(panel, "In",
        items: internalBus,
        action: { |dd| matrix[\ar][i][\inbus] = dd.value },
        scale: 0.5);
    synthOut = dropdown.(panel, "O",
        items: outBus,
        initVal: matrix[\ar][i][\outbus],
        action: { |dd| matrix[\ar][i][\outbus] = dd.value },
        scale: 0.5);
    synthType[\ar][i] = dropdown.(panel,
        items: all {:synthShortName.(n[\name]), n <- synthsAr },
        initVal: synthNamesAr.indexOf(matrix.ar[i][\synthname]),
        action: { |dd|
            matrix.ar[i][\synthname] = synthsAr[dd.value][\name];
        },
    );
    midiGui[\ar][i][4] = buttonCheckboxFlow.(panel, (i+1).asString,
        { |btn| matrix[\ar][i][\active] = btn.value.booleanValue },
        scaleH: 0.1
    );
    // inserts
    4.do { |i|
        buttonCheckboxFlow.(panel, (i+1).asString,
            { |bt, nt| bt.postln },
            scaleW: (1/paramsAr.size)+0.03, scaleH: 0.1,
            colorUpLb: Color.white, colorUpBg: color,
            colorDwLb: color, colorDwBg: Color.grey(0.8)
        );
    };
    // envelope
    envelope = EnvelopeView(panel, panel.bounds.width@(panel.bounds.height*0.15))
        .drawLines_(true)
        .selectionColor_(Color.red)
        .drawRects_(true)
        .resize_(5)
        .step_(0.05)
        .strokeColor_(Color.white)
        .background_(color)
        .action_({arg b; [b.index, b.value].postln})
        .thumbSize_(5);
    envelope.setEnv(defaultEnvelope);

    // params available for manual control
    paneKnobs = compViewFlow.(panel, scaleW: 0.8, scaleH: 0.4);
    controlsAr[0..2].do { |key, j|
        // GUI elements for MIDI-controllable params
        midiGui[\ar][i][j] = knob.(
            paneKnobs,
            paramDefs[key][\label],
            spec: ~valAsApec.(paramDefs[key]),
            action: { |kn| try { matrix.ar[i][\params][key] = kn.value }},
            layout: \line2, scaleH: 0.33
        )
    };
    paneSlid = compViewFlow.(panel, scaleW: 0.25, scaleH: 0.4);
    // GUI elements for MIDI-controllable params
    midiGui[\ar][i][3] = slider.(
        paneSlid,
        paramDefs[controlsAr[3]][\label],
        spec: ~valAsApec.(paramDefs[controlsAr[3]]),
        action: { |kn| try { matrix.ar[i][\params][controlsAr[3]] = kn.value }},
        layout: 'vert'
    );
    // level meter
    panel = compViewFlow.(paneSynth[\ar][i], scaleW: 0.1, scaleH: 0.87);
    levelsAr[i] = levelInd.(panel, 0);

    // params controllable by matrix
    paneSynth[\ar][i].decorator.nextLine;
    panel = compViewFlow.(paneSynth[\ar][i], scaleH: 0.1);

    // replace params controllable by matrix with params for manual control
    buttonCheckboxFlow.(panel, "==",
        { |bt, nt| bt.postln }, // XXX - When ON, it affects coresponding [manually controlled param]!
        scaleH: 0.4,
        colorUpLb: Color.white, colorUpBg: color,
        colorDwLb: color, colorDwBg: Color.grey(0.8)
    );

    // link matrix controllable params with manually controled ones
    paramsAr.do { |parm, i|
        buttonCheckboxFlow.(panel, parm.asString[..5],
            // buttonCheckboxFlow.(panel, parm.asString,
            { |bt, nt| bt.postln },
            scaleW: (1/paramsAr.size)+0.03, scaleH: 0.6,
            colorUpLb: Color.white, colorUpBg: color,
            colorDwLb: color, colorDwBg: Color.grey(0.8)
        );
    };
};

// .kr synth panel and controls
paneKrSynths = compViewFlow.(paneMatrix, scaleW: 0.2, scaleH: 0.4);
krN.do { |i|
    var knobVacant, knobMin, knobMax, knobLFO;

    paneSynth[\kr][i] = compViewFlow.(paneKrSynths, scaleH: (1/krN)+0.01);
    panel = compViewFlow.(paneSynth[\kr][i]);

    // .kr synth
    synthType[\kr][i] = dropdown.(panel,
        items: all {:synthShortName.(n[\name]), n <- synthsKr },
        initVal: synthNamesKr.indexOf(matrix.kr[i][\synthname]),
        action: { |dd|
            matrix.kr[i][\synthname] = synthsKr[dd.value][\name];
        },
        scale: 0.2
    );

    // lfo
    knobLFO = knob.(panel, paramDefs[\lfo][\label],
        initVal: paramDefs[\lfo][\default],
        action: { |kn|
            matrix.kr[i][\params][\lfo] = lfoScope.(kn.value);
            knobLFO.numberView.value = lfoScope.(kn.value).round(0.001);
        },
        layout: \line2, scaleW: 0.22, scaleH: 0.8
    );

    // min (default label and param)
    knobMin = knob.(panel, "min",
        spec: ~valAsApec.(paramDefs[\min]),
        initVal: paramDefs[\min][\default],
        action: { |kn|
            knobMax.value = knobMax.value
                .max(kn.value+0.01) // max > min
                .min(\bipolar.asSpec.maxval); // max <= maxval
            krSetParam.(i, kn.value, knobMax.value)
        },
        layout: \line2, scaleW: 0.22, scaleH: 0.8
    );

    // max (default label and param)
    knobMax = knob.(panel, "max",
        spec: ~valAsApec.(paramDefs[\max]),
        initVal: paramDefs[\max][\default],
        action: { |kn|
            knobMin.value = knobMin.value
                .min(kn.value-0.01) // min < max
                .max(\bipolar.asSpec.minval); // min >= minval
            krSetParam.(i, knobMin.value, kn.value)
        },
        layout: \line2, scaleW: 0.22, scaleH: 0.8
    );

    knobVacant = knob.(panel, "", // vacant
        spec: \bipolar.asSpec,
        action: { |kn| },
        layout: \line2, scaleW: 0.22, scaleH: 0.8
    );

    // GUI elements for MIDI-controllable params
    midiGui[\kr][i] = [knobLFO, knobMin, knobMax, knobVacant];

    paneSynth[\kr][i].decorator.nextLine;
    panel = UserView(
        paneSynth[\kr][i],
        paneSynth[\kr][i].bounds.width@paneSynth[\kr][i].bounds.height
    );
    panel.drawFunc = { |view|
        var half, val, width, left, scope, warning=0.7, critical=0.9;
        scope = \unipolar.asSpec;
        // display is calculated on the min-max values of the current scope
        val = matrix.kr[i][\val];
        half = view.bounds.width * 0.5;
        width = val.abs.linlin(0, 1, 0, half);
        left = if (val >=0 ) { half } { half-width };
        // the bigger scope, the redder level appears
        Pen.color = case
        { (val.abs >= warning) && (val.abs <= critical) } { Color.yellow }
        { val.abs >= critical } { Color.red }
        { Color.green };
        Pen.fillRect(Rect(left, 0, width, view.bounds.height));
    };
    panel.animate = true;
};

// matrix
paneGrid = compViewFlow.(paneMatrix, scaleW: 0.8, scaleH: 0.4);
matrixButtons = List.new;
krN.do { |krInd|
    // launch all .kr synths from start
    synthOnOff.(\kr, krInd);

    // draw matrix buttorns
    arN.do { |arInd|
        panel = compViewFlow.(paneGrid, scaleW: (1/arN)+0.004, scaleH: (1/krN)+0.01);
        paramsAr.size.do { |arParamInd|
            matrixButtons.add(
                buttonCheckboxFlow.(panel, ["-", "|"],
                    { |bt, nt|
                        parmName = paramsAr[arParamInd];
                        if (bt.value.booleanValue) {
                            // ON
                            parmVal = "kr_" ++ krInd.asString; // modulate

                            // XXX - Re-factor!
                            krN.collect { |j| // other .kr modulations of the current .ar synth - OFF
                                (j * (arN * paramsAr.size)) + (paramsAr.size * arInd + arParamInd)
                            }.do { |krI|
                                if (
                                    matrixButtons[
                                        (paramsAr.size * arInd + arParamInd) + (krInd * paramsAr.size * arN) // current index
                                    ] != matrixButtons[krI]
                                ) {
                                    matrixButtons[krI].value = 0;
                                }
                            };
                        } {
                            // OFF
                            try { // leave it at the current value
                                parmVal = matrix[\kr][krInd][\val];
                            } { // any problem - back to default
                                parmVal = paramDefs[parmName][\default];
                            }
                        };
                        try { // to set value param
                            matrix.ar[arInd][\params][parmName] = parmVal;
                        };
                    },
                    scaleW: (1/paramsAr.size)+0.03,
                    // colorUpBg: color, colorDwBg: Color.white, colorDwLb: Color.red,
                );
            );
        };
    }
};


win.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    [char, modifiers, unicode, keycode].postln;
    case
    { keycode == 8 } { // C
        if (modifiers == 262144) { // Ctrl + C
            clean.();
        }
    }
    { keycode == 3 } { // F
        if (modifiers == 262144) { // Ctrl + F
            if (win.bounds == Window.screenBounds) {
                win.endFullScreen
            } {
                win.fullScreen
            }
        }
    }
    { keycode == 53 } { // ESC
        if (win.bounds == Window.screenBounds) {
            win.endFullScreen
        }
    }
    { keycode == 34 } { // I
        if (modifiers == 262144) { // Ctrl + I
            matrix.keysValuesDo { |arKr, synths, i|
                postf("\n%:\n", arKr);
                synths.do { |syn, j| syn.postln };
            }
        }
    }
};


// MIDI
MIDIIn.connectAll;
midiSet = { |arKr, stripeInd, ind, val|
    var element, stripe;
    {
        stripe = arKrMidi[arKr][stripeInd];
        element = midiGui[arKr][stripe][ind];
        element.valueAction = element.controlSpec.map(\midinote.asSpec.unmap(val))
    }.defer
};
midiNextSynth = { |arKr, stripeInd|
    var element, stripe;
    {
        stripe = arKrMidi[arKr][stripeInd];
        element = synthType[arKr][stripe];
        element.valueAction = ~clipInc.(element.value ? 0, lo:0, hi:element.items.size);
    }.defer
};
doubleClick = { |elt|
    var dblClick=false, dateStamp=Date.getDate.rawSeconds;

    // double-click should stay within 0.3s
    if ((dateStamp-clickBootSec <= 0.3) && (clickElement == elt)) {
        dblClick = true;
    };
    clickBootSec = dateStamp;
    clickElement = elt;
    dblClick
};
midiOnOff = { |arKr, stripeInd, ind, switchOn=false|
    var element, stripe, dbl=false;
    {
        stripe = arKrMidi[arKr][stripeInd];
        element = midiGui[arKr][stripe][ind];

        // measure double click on NoteOff, because it is the last event.
        if (switchOn.not) { dbl = doubleClick.(element) };
        if (dbl) {
            element.valueAction = 1 // always switch on on double click
        } {
            element.valueAction = switchOn // single click can switch On or Off
        };
    }.defer
};

MIDIIn.control = { |scr, chan, num, val|
    // [chan, num, val, \midinote.asSpec.unmap(val)].postln;
    num.switch(
        // stripe 1 - .kr 0
        24, { midiSet.(\ar, 0, 0, val) }, // Knob 1 Left
        25, { midiSet.(\ar, 0, 1, val) }, // Knob 2 Left
        26, { midiSet.(\ar, 0, 2, val) }, // Knob 3 Left
        12, { midiSet.(\ar, 0, 3, val) }, // Pitch fader Left

        // stripe 2 - .kr 1
        27, { midiSet.(\ar, 1, 0, val) }, // Knob Hi Left
        28, { midiSet.(\ar, 1, 1, val) }, // Knob Mid Left
        29, { midiSet.(\ar, 1, 2, val) }, // Knob Low Left
        11, { midiSet.(\ar, 1, 3, val) }, // vol fader Left

        // stripe 3 - .ar 0
        34, { midiSet.(\kr, 0, 0, val) }, // Knob Hi Right
        35, { midiSet.(\kr, 0, 1, val) }, // Knob Mid Right
        36, { midiSet.(\kr, 0, 2, val) }, // Knob Low Right
        14, { midiSet.(\kr, 0, 3, val) }, // vol fader Right

        // stripe 4 - .ar 1
        31, { midiSet.(\kr, 1, 0, val) }, // Knob 1 Right
        32, { midiSet.(\kr, 1, 1, val) }, // Knob 2 Right
        33, { midiSet.(\kr, 1, 2, val) }, // Knob 3 Right
        15, { midiSet.(\kr, 1, 3, val) } // pitch fader Right
    )
};
MIDIIn.noteOn = { |scr, chan, num, val|
    // [chan, num, val].postln;
    num.switch(
        70, { midiOnOff.(\ar, 0, 4, true) }, // Start/Pause Left
        // 69, { midiOnOff.(\kr, 0, 4, true) }, // Start/Pause Right
        58, { midiOnOff.(\ar, 1, 4, true) }, // Queue Left
        // 59, { midiOnOff.(\kr, 1, 4, true) }, // Queue Right
        46, { midiNextSynth.(\ar, 0) }, // Prev Left
        43, { midiNextSynth.(\ar, 1) }, // Next Left
        56, { midiNextSynth.(\kr, 0) }, // Prev Right
        57, { midiNextSynth.(\kr, 1) }, // Next Right
        44, { // Headphones Left
            arKrMidi[\ar] = arKrMidi[\ar] + 2;
            if (arKrMidi[\ar][1] >= krN) {arKrMidi[\ar] = [0, 1]}
        },
        45, { // Headphones Right
            arKrMidi[\kr] = arKrMidi[\kr] + 2;
            if (arKrMidi[\kr][1] >= arN) {arKrMidi[\kr] = [0, 1]}
        },
    )
};
MIDIIn.noteOff = { |scr, chan, num, val|
    // [chan, num, val].postln;
    num.switch(
        70, { midiOnOff.(\ar, 0, 4, false) }, // Start/Pause Right
        58, { midiOnOff.(\ar, 1, 4, false) }, // Queue Right
    )
};


{ // global app clock with resolution 100 milliseconds (0.1 of a second)
    var defPast, synthName;
    while { win.isClosed.not } {
        matrix.keys.do { |arKr|
            matrix[arKr].do { |def, pos|
                defPast = matrixPast[arKr][pos];

                if (def.active != defPast.active) {
                    synthOnOff.(arKr, pos, (att: 0.2, rel: 0.2));
                    defPast.active = def.active;
                };
                if (def.synthname != defPast.synthname) {
                    if (def.active) {
                        ~groupFree.(def.node, crossfade.value); // switch OFF old synth
                        synthOnOff.(arKr, pos, (att: crossfade.value)); // then turn ON a new one
                    };
                    defPast.synthname = def.synthname;
                };
                def.params.keysValuesDo { |key, val|
                    if (defPast.params[key] != val) {
                        synthSend.(arKr, pos, Dictionary[key -> val]);
                        defPast.params[key] = val;
                    }
                };
                if (arKr == \ar) {
                    levelsAr[pos].value = def[\val];
                    [\inbus, \outbus].do { |bus|
                        if (def[bus] != defPast[bus]) {
                            synthReRoute.(arKr, pos, [bus, def[bus].asInteger]);
                            defPast[bus] = def[bus]
                        };
                    };
                };

                // highlight current stripes
                paneSynth[arKr][pos].background = if (arKrMidi[arKr].includes(pos)) { highlighted } { color }
            };
        };
        0.1.wait;
    }
}.fork(AppClock);

win.front;

// clean everything on exit
clean = {
    win.close;
    MIDIIn.disconnect;
};

CmdPeriod.doOnce({
    clean.();
});

// //
// // "\n=======================================\nTESTING\n".postln;
// UnitTest.new.assertEquals(minMax2mulAdd.(10, 100), [45, 55], "minMax2mulAdd.(15, 100)");
// UnitTest.new.assertEquals(minMax2mulAdd.(-1, 1), [1, 0], "minMax2mulAdd.(-1, 1)");
// UnitTest.new.assertEquals(minMax2mulAdd.(-100, 1), [50.5, -49.5], "minMax2mulAdd.(-100, 1)");
// UnitTest.new.assertEquals(minMax2mulAdd.(-100, 0), [50, -50], "minMax2mulAdd.(-100, 0)");
// UnitTest.new.assertEquals(minMax2mulAdd.(50, 10000), [4975, 5025], "minMax2mulAdd.(50, 10000)");
// UnitTest.new.assertEquals(minMax2mulAdd.(0, 2pi), [1pi, 1pi], "minMax2mulAdd.(0, 2pi)");
// UnitTest.new.assertEquals(minMax2mulAdd.(-0.5pi, 0.5pi), [0.5pi, 0], "minMax2mulAdd.(-0.5pi, 0.5pi)");
// UnitTest.new.assertEquals(minMax2mulAdd.(-1pi, 1pi), [1pi, 0], "minMax2mulAdd.(-1pi, 1pi)");
// UnitTest.new.assertEquals(minMax2mulAdd.(0.1, 0.9), [0.4, 0.5], "minMax2mulAdd.(0.1, 0.9)");
\
)