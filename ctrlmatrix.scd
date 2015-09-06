// XXX figure out and inmplement a concept of insert channels!

(
var krN, arN;
var matrix, matrixPast, initMatrix;
var synthOnOff, synthSend, synthReRoute, synthInit, synthShortName;
var paramDefs, synthsAr, synthsKr, paramsAr, paramsKr, defaultParams;
var outBus=(0..Server.default.options.numAudioBusChannels-1),
    internalBus=(10..Server.default.options.numAudioBusChannels-1),
    krBus = (0..Server.default.options.numControlBusChannels-1);
var oscResponders;

var win;
var paneMatrix, paneSettings, paneSynths, paneSynth,
    paneArSynths, paneConnections,
    paneKrSynths, paneGrid, pane;
var synthType, synthIn, synthOut;
var btPanic, master, crossfade;
var paneWidth, paneHeight;
var button, buttonCheckbox, buttonCheckboxFlow, knob, slider,
    dropdown, compView, compViewFlow, levelInd;
var valAsApec;
var colorBtUp=Color.grey(0.6), colorBtDown=Color.blue,
    colorBtLabel=Color.grey(0.2), colorPane=Color.grey(0.3),
    colorStringBg = Color.grey(alpha:0.1), colorString=Color(0.8, 0.8, 0.8);
var clean;

// constants
var s__SYNTHNAME = "sr__(e|g|p|k|r|s){1}__[a-zA-Z0-9]+";
var f__CURR_DIR = PathName(thisProcess.nowExecutingPath).pathOnly;

// synths and params
paramDefs = (
    azimuth:   ( label: "azi",    minval: -1pi,   maxval: 1pi,    step: 0.01, default: 0  ),
    distance:  ( label: "dist",   minval: 0,      maxval: 2.sqrt, step: 0.01, default: 0  ),
    elevation: ( label: "elev",   minval: -0.5pi, maxval: 0.5pi,  step: 0.01, default: 0  ),
    velocity:  ( label: "vel",    minval: 0,      maxval: 1,      step: 0.01, default: 0  ),
    depth:     ( label: "depth",  minval: 1,      maxval: 10,     step: 0.1,  default: 5  ),
    offset:    ( label: "offset", minval: 0,      maxval: 127,    step: 1,    default: 36 ),
    cutoff:    ( label: "cutoff", minval: 0,      maxval: 10000,  step: 10,   default: 0  ),
    freq:      ( label: "freq",   minval: 0,      maxval: 10000,  step: 0.1,  default: 0  ),
    mul:       ( label: "mul",    minval: 0,      maxval: 1,      step: 0.01, default: 0  ),
    add:       ( label: "mul",    minval: 0,      maxval: 10,     step: 0.01, default: 0  ),
);
// Warning! Only the first 4 parameters can be controlled via GUI.
paramsAr = #[\distance, \velocity, \offset, \cutoff];
paramsKr = #[\freq, \mul, \add, \velocity];
synthsAr = all {:(name: syn.asString, params: paramsAr), syn <- ~synths.keys};
synthsKr = all {:(name: syn.asString, params: paramsKr), syn <- #[
    "sr__k__sin", "sr__k__saw", "sr__k__tri",
    "sr__k__lfnoise0", "sr__k__lfnoise1", "sr__k__lfnoise2",
    "sr__k__clipnoise", "sr__k__stepnoise"]
};
oscResponders = [
    "",
    "l_hand",
    "r_hand",
];
synthInit = (all {: syn.name.asSymbol, syn <- synthsAr}).indexOf(\sr__e__silent);

// initialize main matrix container
#krN, arN = [8, 8];

defaultParams = { |synthname|
    // Fills up a dictionary with default params for synth name.
    var params, result, val;

    // fill list of param names
    (synthsAr ++ synthsKr).do { |def|
        if (def.name == synthname) {
            params = def.params
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

initMatrix = {
    (
        ar: Array.fill(arN, { |i|
            var synth = synthsAr[i % synthsAr.size];
            (
                synthname: "",
                inbus: ~inbus,
                outbus: ~outbus,
                node: 0,
                active: false,
                params: []
            )}
        ),
        kr: Array.fill(krN, { |i|
            var synth = synthsKr[i % synthsKr.size];
            (
                synthname: "",
                in: oscResponders[0],
                outbus: krBus[i],
                node: 0,
                active: false,
                params: []
            )}
        ),
    )
};
matrix = initMatrix.();
matrixPast = initMatrix.();

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
    // Switches synth ON, if its \node in the matrix is 1
    // (just switched on via GUI), OFF otherwise.
    // Returns Node ID.
    var def, node=0;
    def = matrix[arKr][pos];
    if (def.active) {
        params = params ? def[\params].getPairs;
        if (arKr == 'ar') {
            node = ~groupInit.(def[\synthname],
                inbus:def[\inbus],
                outbus:def[\outbus],
                params:params
            );
        } {
            node = ~modulatorInit.(outbus:pos, params:params);
        };
    } {
        ~groupFree.(def[\node], 0.5)
    };
    def[\node] = node;
};


synthSend = { |arKr, pos|
    var def = matrix[arKr][pos];
    if (def.active) {
        ~sendToSrv.([["/n_set", def[\node]] ++ def[\params].getPairs])
    };
};

synthReRoute = { |arKr, pos, route|
    var def = matrix[arKr][pos];
    if (def.active) {
        ~sendToSrv.([["/n_set", def[\node]] ++ route])
    };
};


// interface
win = Window("ctrl matrix", Window.screenBounds.width@Window.screenBounds.height);

// helper functions
valAsApec = { |spec|
    [
        spec.atFail(\minval, {0}),
        spec.atFail(\maxval, {1}),
        spec.atFail(\warp, {\lin}),
        spec.atFail(\step, {0}),
        spec.atFail(\default, {0})
    ].asSpec
};
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
buttonCheckbox = { |par, label, action, value, bounds|
    Button(par, bounds).states_([
        [label, colorBtLabel, colorBtUp],
        [label, colorString, colorBtDown]
    ])
    .value_(value)
    .action_({ |bt| action.(bt.value) })
    .font_(Font("Helvetica", 12))
    .canFocus_(false);
};
buttonCheckboxFlow = { |par, label, action, value, scaleH=1, scaleW=1|
    var bounds = paneWidth.(par, scaleW)@paneHeight.(par, scaleH);
    buttonCheckbox.(par, label, action, value, bounds);
};
knob = { |par, label, spec, action, default=0, layout='vert', scaleW=1, scaleH=1|
    var knobWidth=paneWidth.(par, scaleW), knobHeight=paneHeight.(par, scaleH);
    if (layout != 'vert') {
        knobWidth = paneWidth.(par, scaleW) - 10;
        knobHeight = paneHeight.(par, scaleH);
    };
    EZKnob(par, knobWidth@knobHeight, label, spec,
        { |ez| action.(ez.value) }, default,
        layout: layout
    ).font_(Font("Helvetica", 12));
};
slider = { |par, label, spec, action, default=0, layout='horz', scale=1|
    var labelWidth=0, numberWidth=45;
    var bounds=paneWidth.(par)@20;
    if (label.isNil.not) { labelWidth = label.size * 5 };
    if (layout == 'horz') {
        bounds = (paneWidth.(par, scale))@20;
        numberWidth = 30;
    } {
        bounds = 30@(paneHeight.(par, scale))
    };
    EZSlider(par, bounds, label, spec, { |ez| action.(ez.value) }, default,
        labelWidth: labelWidth, numberWidth: numberWidth, layout: layout)
    .font_(Font("Helvetica", 12))
    .setColors(stringColor: Color.white)
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
    if (color.isNil) { color = colorPane };
    CompositeView(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH)
    ).background_(color);
};
compViewFlow = { |par, color, scaleW=1, scaleH=1|
    var vw;
    vw = compView.(par, color, scaleW, scaleH);
    vw.decorator = FlowLayout(vw.bounds);
    vw
};
levelInd = { |par, default=0, scaleW=1, scaleH=1|
    LevelIndicator(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .background_(Color.clear)
    .value_(default).warning_(0.7).critical_(0.9)
};

// panels
paneMatrix = CompositeView(win,
    win.bounds.width@win.bounds.height
).background_(Color.grey(0.7));
paneMatrix.decorator = FlowLayout(paneMatrix.bounds);

paneSettings = compViewFlow.(paneMatrix, scaleW: 0.2, scaleH: 0.4);
master = slider.(paneSettings, "Master", \db.asSpec,
    { |sl| s.volume.volume = sl.value }, scale:0.75
);
crossfade = slider.(paneSettings, "X-Fade",
    [0.5, 5, \lin, 0.5, 2].asSpec, ControlSpec
    { |sl| s.volume.volume = sl.value }, scale:0.75
);
btPanic = button.(paneSettings, "PANIC",
    { |val| val.postln},
    0.07, 0.25, Color.white, Color.red
);

paneArSynths = compViewFlow.(paneMatrix, scaleW: 0.8, scaleH: 0.4);
paneConnections = compViewFlow.(paneArSynths, scaleH: 0.15, color: Color.grey(0.7));
// .ar synth panel and controls
paneSynths = compViewFlow.(paneArSynths, scaleH: 0.85);
8.do { |i|
    var paneKnobs, paneSlid;
    paneSynth = compViewFlow.(paneSynths, scaleW: 0.125);
    // synth
    pane = compViewFlow.(paneSynth, scaleW: 0.9);

    // .ar synth
    synthType = dropdown.(pane,
        items: all {:synthShortName.(n[\name]), n <- synthsAr },
        initVal: synthInit,
        action: { |dd|
            matrix.ar[i][\synthname] = synthsAr[dd.value][\name];
            matrix.ar[i][\params] = defaultParams.(matrix.ar[i][\synthname]);
        },
    );
    synthIn = dropdown.(pane, "In",
        items: internalBus,
        action: { |dd| matrix[\ar][i][\inbus] = dd.value },
        scale: 0.5);
    synthOut = dropdown.(pane, "O",
        items: outBus,
        action: { |dd| matrix[\ar][i][\outbus] = dd.value },
        scale: 0.5);
    buttonCheckboxFlow.(pane, "ON",
        { |btn|
            matrix[\ar][i][\active] = btn.value.booleanValue;
        },
        scaleW: 0.5, scaleH: 0.1
    );
    button.(pane, "RESET", { |val| val.postln }, scaleW: 0.5, scaleH: 0.1);
    paneKnobs = compViewFlow.(pane, scaleW: 0.6, scaleH: 0.7);
    [\none, \none, \none].do { |key| // Dummies
        // XXX dynamic labels depending on the synth type
        knob.(paneKnobs, action: { |k| k.postln }, scaleH: 0.33);
    };
    paneSlid = compViewFlow.(pane, scaleW: 0.4, scaleH: 0.7);
    slider.(paneSlid, "mul", \unipolar.asSpec,
        { |sl| sl.postln }, 0, \vert);
    // level meter
    pane = compViewFlow.(paneSynth, scaleW: 0.11);
    levelInd.(pane, 0.5);
};

paneKrSynths = compViewFlow.(paneMatrix, scaleW: 0.2, scaleH: 0.6);
// .kr synth panel and controls
8.do { |i|
    paneSynth = compViewFlow.(paneKrSynths, scaleH: 0.125);
    pane = compViewFlow.(paneSynth, scaleW: 0.95);

    // .kr synth
    synthType = dropdown.(pane,
        items: all {: synthShortName.(n[\name]), n <- synthsKr },
        initVal: synthsKr.indexOf(matrix.kr[i][\synthname]),
        action: { |dd| matrix.kr[i][\synthname] = synthsKr[dd.value] },
        scale: 0.25
    );

    synthIn = dropdown.(pane, "in", items:oscResponders, scale: 0.3);
    slider.(pane, "", \unipolar.asSpec,
        { |sl| sl.postln }, 0, scale: 0.45);
    [\none, \none, \none].do { |key| // Dummies
        // XXX dynamic labels depending on the synth type
        knob.(pane, action: { |k| k.postln }, layout: \line2, scaleW: 0.3, scaleH: 0.5);
    };
    buttonCheckboxFlow.(pane, "ON",
        { |btn| matrix[\kr][i][\active] = btn.value.booleanValue },
        scaleW:0.11, scaleH:0.5
    );
    button.(pane, "RES", { |val| val.postln }, scaleW:0.11, scaleH:0.5);
    levelInd.(paneSynth, 0.5, scaleW:0.05);
};

paneGrid = compViewFlow.(paneMatrix, color: Color.white, scaleW: 0.8, scaleH: 0.6);
8.do { |x|
    8.do { |y|
        pane = compView.(paneGrid, scaleW: 0.126, scaleH: 0.127);
        4.do { |ctl|
            buttonCheckbox.(pane, "_",
                // XXX - re-write to change param in matrix
                // { |val| synthSet.(y, ctl, "c" ++ x.asString) },
                bounds:Rect(
                    (ctl * 25) + (ctl * pane.bounds.width * 0.1) + 6,
                    (pane.bounds.height * 0.35), 25, 25
                )
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

{ // global app clock with resolution 100 milliseconds (0.1 of a second)
    var defPast, synthName;
    while { win.isClosed.not } {
        matrix.keys.do { |arKr|
          matrix[arKr].do { |def, pos|
                defPast = matrixPast[arKr][pos];

                if (def.active != defPast.active) {
                    synthOnOff.(arKr, pos);
                    defPast.active = def.active;
                };
                if (def.synthname != defPast.synthname) {
                    if (def.active) {
                        ~groupFree.(def.node, crossfade.value); // switch OFF old synth
                        synthOnOff.(arKr, pos, [\att, crossfade.value]); // then turn ON a new one
                    };
                    defPast.synthname = def.synthname;
                };
                if (def.params != defPast.params) {
                    synthSend.(arKr, pos);
                    defPast.params = def.params;
                };
                if (arKr == \ar) {
                    [\inbus, \outbus].do { |bus|
                        if (def[bus] != defPast[bus]) {
                            synthReRoute.(arKr, pos, [bus, def[bus].asInteger]);
                            defPast[bus] = def[bus]
                        };
                    }
                }
            };
        };
        // matrixPast = Dictionary.newFrom(matrix); // bookmark

        0.1.wait;
    }
}.fork(AppClock);

win.front;

// clean everything on exit
clean = {
    win.close;
};

CmdPeriod.doOnce({
    clean.();
});
)