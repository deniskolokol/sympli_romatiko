(
// GUI
var width=Window.screenBounds.width;
var height=Window.screenBounds.height;
var depth=Window.screenBounds.height;
var rate=0.005;
var tick=0;
var item, frame, clean;
var panel, palette;
var oscGroupTree;
var meterView, logLeft, logRight;
var logMsg, postColors=List.new;
var fileContent; // XXX - temp?
var fontFace = "Andale Mono"; // "Monaco"
var transparent=Color.red(alpha:0.01),
    techColor=Color.green(0.5),
    font=Font(fontFace, 14),
    fontSmall=Font(fontFace, 12),
    fontMedium=Font(fontFace, 14),
    fontLarge=Font(fontFace, 16),
    fontLarge1=Font(fontFace, 20),
    fontGiant=Font(fontFace, 26),
    fontColor=Color.gray(0.7),
    colorStar=Color.red,
    colorJoint=Color.new255(173, 58, 0),
    colorParticle=Color.white;
var win = Window("entropia", width@height, false);
var canvas = (
    canvas: Canvas3D(win, Rect(0, 0, width, height))
        .scale_(200)
        .perspective_(0.2)
        .distance_(0.75)
        .background_(Color.black),
    params: (
        distance: (
            label: "dist",
            spec: ControlSpec(0.05, 2, 'linear', 0.0, 1, 0.05),
            val: 0.75
        ),
        perspective: (
            label: "prs",
            spec: \unipolar.asSpec,
            val: 0.2
        ),
        rotate: (
            label: "R",
            val: true
        ),
    ),
    setter: { |self, parm, key, val| self.params[parm][key] = val },
    getter: { |self, parm, key| self.params[parm][key] },
    apply: { |self, parm, val| self.setter(parm, \val, val) },
    applyGui: { |self, parm, val| self.setter(parm, \gui, val) },
    val: { |self, parm| self.params[parm][\val] },
);

// GUI: elements
var paneWidth = { |par, scale=1| par.bounds.width * scale };
var paneHeight = { |par, scale=1| par.bounds.height * scale };
var compView = { |par, color, scaleW=1, scaleH=1|
    CompositeView(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH)
    ).background_(color ? transparent);
};
var compViewFlow = { |par, color, margin, gap, scaleW=1, scaleH=1|
    var vw;
    vw = compView.(par, color, scaleW, scaleH);
    vw.decorator = FlowLayout(vw.bounds, margin ? 1@1, gap ? 1@1);
    vw
};

// GUI: view over 3d canvas for control elements
var view = UserView(win, Window.screenBounds.width@Window.screenBounds.height)
    .decorator_(FlowLayout(win.bounds));
var panelTop = compViewFlow.(view, scaleH: 0.02);
var panelLeft = compViewFlow.(view, scaleW: 0.2, scaleH: 0.94);
var panelCenter = compViewFlow.(view, scaleW: 0.59, scaleH: 0.94);
var panelRight = compViewFlow.(view, scaleW: 0.2, scaleH: 0.94);
var panelBottom = compViewFlow.(view, scaleH: 0.02);

// ctrl elements
var sText = { |par, string, stringColor, stringFont, align, scaleH, scaleW=0.5|
    var st, height;
    if (scaleH.isNil) {
        // height = st.sizeHint.height.max(20); // XXX - how to do that before creation of StaticText?
        height = 20;
    } {
        height = paneHeight.(par, scaleH);
    };
    StaticText(par, paneWidth.(par, scaleW)@height)
    .string_(string)
    .font_(stringFont ? font)
    .stringColor_(stringColor ? fontColor)
    .align_(align ? \left)
};

var lvMeter = { |par, data, layout=\horz, scale=1|
    var unit, flow, num, text, indicator, scaleW, scaleH;
    if (layout == \horz) {
        scaleW = scale;
        scaleH = 20/par.bounds.height;
    } {
        scaleW = 20/par.bounds.width;
        scaleH = scale;
    };
    flow = compViewFlow.(
        par,
        Color.clear,
        gap:5,
        scaleW:scaleW,
        scaleH:scaleH
    );
    text = sText.(
        flow,
        data[\label],
        fontColor,
        fontSmall,
        align:\right,
        scaleH:0.8,
        scaleW:0.25
    );
    indicator = LevelIndicator(
        flow,
        (flow.bounds.width*0.55)@(flow.bounds.height*0.8)
    )
    .value_(data.spec.unmap(data.spec.default))
    .style_(\led)
    .warning_(1)
    .critical_(1)
    .numSteps_(80)
    .meterColor_(Color.grey())
    .background_(Color.clear);
    num = NumberBox(
        flow,
        (flow.bounds.width*0.15)@(flow.bounds.height*0.8)
    )
    .value_(data.spec.default)
    .font_(fontSmall)
    .normalColor_(fontColor)
    .stringColor_(fontColor)
    .background_(Color.clear);
    (
        val: data.spec.default,
        num: num,
        text: text,
        indicator: indicator,
        setVal: { |self, val|
            self.val = val;
            self.updateElements;
        },
        updateElements: { |self|
            self.num.value = self.val;
            self.indicator.value = data.spec.map(self.val);
        }
    );
};

var slider = { |par, name, val, layout=\horz, scale=1|
    var ezs, bounds;
    bounds = paneWidth.(par, min(scale, 0.98))@20;
    if (layout != \horz) {
        bounds = 30@(paneHeight.(par) * min(scale, 0.9))
    };
    ezs = EZSlider(
        par,
        bounds,
        format(" % ", val.atFail(\label, {name}).asString),
        val[\spec],
        layout:layout, labelWidth:80, numberWidth:40)
    .font_(fontSmall);
    ezs.numberView.canFocus = false;
    ezs.sliderView.canFocus = false;
    ezs.setColors(
        stringColor:fontColor,
        sliderBackground:Color.black,
        numBackground:Color.grey(alpha:0.5),
        numNormalColor:fontColor,
        background:transparent
    );
};
var sliderWorld = { |par, name, val, layout=\horz, scale=1|
    var ezs;
    ezs = slider.(par, name, val, layout=\horz, scale=1);
    ezs.action = { |ez|
        ez.value.postln;
        // XXX - finish it!
        // eventPool.append((
        //     message: \~physics,
        //     params: [name, updateWorldParm.(name, ez.value)]
        // ));
    };
};
var button = { |par, label, labelColor, bgColor, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .states_([[label, labelColor ? fontColor, bgColor ? transparent]])
    .font_(fontMedium)
    .canFocus_(false)
};
var buttonCheckbox = { |par, label, labelColor, bgColor, scaleH=1, scaleW=1|
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH))
    .states_([
        [label, labelColor ? fontColor, bgColor ? transparent],
        [label, bgColor ? transparent, labelColor ? fontColor]
    ])
    .font_(fontMedium)
    .canFocus_(false)
};

// WORLD
var world = (
    particles: ( ),
    params: (
        drag: (
            label: "drag",
            spec: ControlSpec(0.000, 0.500, \lin, 0.001, 0.001),
        ),
        repulsion: (
            label: "repulsion",
            spec: ControlSpec(1, 100, \lin, 5, 100),
        ),
        maxVel: (
            label: "max vel",
            spec: ControlSpec(0.5, 10, \lin, 0.1, 5)
        ),
        starMass: (
            label: "star mass",
            spec: ControlSpec(0.1, 5, \lin, 0.1, 1),
        ),
        gravX: (
            label: "grav X",
            spec: ControlSpec(-2.1, 2.0, \lin, 0.01, 0),
        ),
        gravY: (
            label: "grav Y",
            spec: ControlSpec(-2.1, 2.0, \lin, 0.01, 0),
        ),
        gravZ: (
            label: "grav Z",
            spec: ControlSpec(-2.1, 2.0, \lin, 0.01, 0),
        ),
        // springs
        springDamp: (
            label: "spr damp",
            spec: ControlSpec(0.1, 2, \lin, 0.1, 2),
        ),
        springRestLen: (
            label: "rest len",
            spec: ControlSpec(1, 15, \lin, 1, 2),
        ),
        springStrength: (
            label: "strength",
            spec: ControlSpec(0.1, 2, \lin,  0.1, 1),
        ),
        // particle system
        particleSystem: (
            label: "particl",
            default: false,
            hint: "run particle system",
        ),
        partSigmoidRatio: (
            label: "sigmoid",
            spec: ControlSpec(0.3, 0.9, \lin, 0.1, 0.7),
            hint: "steepness of sigmoid function determiming probability of particle being born",
        ),
        partAgeThresh: (
            label: "part age",
            spec: ControlSpec(0.1, 2, \lin, 0.01, 0.84),
            hint: "maximum particle age in cycles (sec)",
        ),
        partInitAccel: (
            label: "part accel",
            spec: ControlSpec(0.5, 30, \exp, 0.5, 5),
            hint: "particle initial acceleration",
        ),
        partDefaultMass: (
            label: "part mass",
            spec: ControlSpec(0.1, 1, \lin, 0.1, 0.5),
        ),
        partFreq: (
            label: "part freq",
            spec: ControlSpec(0.02, 0.9, \lin, 0.01, 0.8),
            hint: "generate new particle \partFreq times per second",
        ),
        partSynth: (
            label: "part synth",
            default: "pulse",
        ),
        mutualAttraction: (
            label: "mutual",
            default: true,
        ),
    )
);
var globalParams = (
    serverVolume: (
        label: "MASTER",
        spec: ControlSpec(-inf, 0.0, 'db', 0.0, 0.0, " dB")
    ),
    maxDist: (
        label: "max dist",
        spec: ControlSpec(0.5, 30.0, \lin, 0.1, ~speakers.maxDist),
        ),
    depth: (
        label: "depth",
        spec: ControlSpec(1, 10, \lin, 0.1, ~depth),
        ),
    skelSimulSpeed: ( // XXX - rename it to sthn like skelSimulInertia OR
                      //       change processing algo reversing this value to get `.wait`
        label: "simul vel",
        spec: ControlSpec(0.001, 0.005, \lin, 0.001, 0.002),
        hint: "speed of skeleton simulation",
    ),
    internalBuf: (
        label: "internal buf",
        default: false,
        hint: "granular synths use internal buffer instead of samples",
    ),
    draw: (
        label: "drawing mode",
        default: \calibration,
        hint: "drawing mode description",
    ),
    removeall: (midinote: 70),
    reset: (midinote: 58),
    skelsimul: ( ),
);
var x, y, z, beat=0;

// PHYSICS
var handleBoundaryCollisions = { |p|
    if(p.position.x<0 or:{p.position.x>width}, {
        p.velocity.set(-0.9*p.velocity.x, p.velocity.y, p.velocity.z);
    });
    if(p.position.y<0 or:{p.position.y>height}, {
        p.velocity.set(p.velocity.x, -0.9*p.velocity.y, p.velocity.z);
    });
    if(p.position.z<0 or:{p.position.z>depth}, {
        p.velocity.set(p.velocity.x, p.velocity.y, -0.9*p.velocity.z);
    });
    p.position.set(
        p.position.x.clip(0, width),
        p.position.y.clip(0, height),
        p.position.y.clip(0, depth),
    );
};

// HELPER FUNCTIONS
var prettyPrintDict = { |data, output="", level=0|
    // Pretty print hierarchical structure.
    var report = { |k, v|
        format("%%: %\n", "".catList(Array.fill(level, "    ")), k, v ? '');
    };
    data.keysValuesDo { |key, val|
        if ([Dictionary, Event].includes(val.class)) {
            output = prettyPrintDict.(val, output ++ report.(key), level+1)
        } {
            output = output ++ report.(key, val);
        }
    };
    output
};

var ade2xyz = { |position, maxDist|
    // Converts (position.azim, position.dist, position.elev) to [x, y, z]
    var pos, distAdj;
    var mC = 2.sqrt; // max in Cartesian plane (from center to wall)
    distAdj = position.dist.linlin(0, maxDist, 0, mC); // adjust distance on [0, maxDist]
    pos = Polar(distAdj, position.azim).asCartesian;
    [
        pos.x.linlin(mC.neg, mC, 1, -1),
        pos.y.linlin(mC.neg, mC, -1, 1),
        position.elev.linlin(-0.5pi, 0.5pi, 1, -1) // inverse
    ]
};


var physics = ~physics; // TraerParticleSystem.new;


// The World is the frame.
canvas.canvas.add(frame = Canvas3DItem.cube
    .color_(Color.white)
    .width_(0.5)
);

// Add particles to canvas.
physics.particles.do { |particle|
    item = Canvas3DItem.cube
    .color_(
        case
        {particle == ~star} {colorStar}
        {{: ~skel[joint], joint <- ~skel.keys}.contains(particle)} {colorJoint} // XXX check it!
        {colorParticle}
    )
    .width_(1)
    .transform(Canvas3D.mScale(0.05));
    canvas.canvas.add(item);
    world.particles.put(particle, item);
};

// Add speakers to canvas.
~speakers.items.do { |speaker, i|
    // speaker cube
    item = Canvas3DItem.cube
    .color_(Color.cyan)
    .width_(0.5)
    .transform(Canvas3D.mScale(0.1));
    canvas.canvas.add(item);
    speaker.put(\cube, item);

    // Speaker stand
    #x, y, z = ade2xyz.(speaker, ~speakers.maxDist);
    item = Canvas3DItem()
    .color_(Color.cyan)
    .width_(0.5)
    .transform(Canvas3D.mScale(0.1));
    item.paths = [
        [ [ x, y, z], [x, 1, 0] ]
    ];
    // item.paths = #[ [ [ -1, -1, -1], [x, y, z] ] ];
    canvas.canvas.add(item);
    speaker.put(\stand, item);
};

canvas.canvas.animate(40) { |t|
    if (canvas.val(\rotate)) {
        beat = beat + 1;
    };
    canvas.canvas.distance = canvas.val(\distance);
    canvas.canvas.perspective = canvas.val(\perspective);
    canvas.canvas.transforms = [ // spin the canvas
        Canvas3D.mRotateY(beat*rate*1.0 % 2pi),
        Canvas3D.mRotateX(beat*rate*1.5 % 2pi),
        Canvas3D.mRotateZ(beat*rate*1.5 % 2pi),
    ];
    world.particles.keysValuesDo { |particle, item|
        handleBoundaryCollisions.value(particle);

        x = particle.position.x.linlin(0, width, -1, 1);
        y = particle.position.y.linlin(0, height, -1, 1);
        z = particle.position.z.linlin(0, depth, -1, 1);
        item.transforms = canvas.canvas.transforms ++ [
            Canvas3D.mTranslate(x, y, z),
        ];
    };
    ~speakers.items.do { |speaker, i|
        #x, y, z = ade2xyz.(speaker, ~speakers.maxDist);
        // postf("... speaker %: %, %, %\n", i, x, y, z);
        speaker.cube.transforms = [Canvas3D.mTranslate(x, y, z)];
        // speaker.stand.transforms = [Canvas3D.mTranslate(x, y, z)];
    };

    physics.tick;
};


win.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
    [char, modifiers, unicode, keycode].postln;
    case
    { keycode == 8 } { // C
        // ^C - exit
        if (modifiers == 262144) {
            clean.();
        }
    }
    { keycode == 3 } { // F
        // ^F - toggle full screen
        if (modifiers == 262144) {
            if (win.bounds == Window.screenBounds) {
                win.endFullScreen
            } {
                win.fullScreen
            }
        }
    }
    { keycode == 53 } { // ESC
        // ESC - end full screen
        if ([0, 256].includes(modifiers)) {
            if (win.bounds == Window.screenBounds) {
                win.endFullScreen
            }
        }
    }
    { keycode == 34 } { // I
        // ^I - info
        if (modifiers == 262144) {
            prettyPrintDict.(world).postln
        }
    }
    { keycode == 9 } { // V
        // V - toggle panels visibility
        if ([0, 256].includes(modifiers)) {
            [panelLeft, panelTop, panelCenter, panelRight, panelBottom]. do { |elt|
                elt.visible = (1 - elt.visible.asInteger).booleanValue
            }
        }
    }
};

// GUI: draw GUI
// internal levels
panel = compViewFlow.(panelLeft, scaleH: 0.2);
palette = QPalette.dark;
palette.setColor(Color.black, \window);
panel.palette = palette;
meterView = EntroServerMeterView(~scsynth, panel, 0@0, 210);
// GUI: log left side
panel = compViewFlow.(panelLeft, scaleH: 0.8);
logLeft = TextView(panel, (panel.bounds.width*0.99)@(panel.bounds.height*0.97))
    .editable_(false)
    .font_(fontSmall)
    .stringColor_(Color.new255(11, 96, 224))
    .background_(transparent)
    .hasVerticalScroller_(false)
    .canFocus_(false);

// GUI: slider controllers for physics and global params
panel = compViewFlow.(panelRight, scaleH:0.5);
globalParams[\serverVolume][\gui] = lvMeter.value(panel, globalParams[\serverVolume]);
compViewFlow.(panel, scaleH:0.02); // gap
[
    \drag, \repulsion, \starMass,
    \gravX, \gravY, \gravZ,
    \springDamp, \springRestLen, \springStrength,
    \maxVel, \partInitAccel, \partFreq,
    \partDefaultMass, \partAgeThresh,
].do { |key, n|
    world.params[key][\gui] = lvMeter.value(panel, world.params[key]);
    // make a gap after every 3rd slider
    if ((n+1) % 3 == 0) {
        compViewFlow.(panel, scaleH:0.02)
    }
};

// GUI: slider controllers for global params
compViewFlow.(panel, scaleH:0.02); // gap
globalParams[\skelSimulSpeed][\gui] = lvMeter.value(panel, globalParams[\skelSimulSpeed]);
globalParams[\maxDist][\gui] = lvMeter.value(panel, globalParams[\maxDist]);
globalParams[\depth][\gui] = lvMeter.value(panel, globalParams[\depth]);

// GUI: button based misc params
compViewFlow.(panel, scaleH:0.02); // gap
globalParams[\removeall][\gui] = button.(panel, "X",
    bgColor:Color.black, scaleW:0.19, scaleH:0.05
).action_({ |bt|
    bt.value.postln;
    // XXX - make removeAll a method of `world`
    // removeAll.()
});
// reset physics params to defaults
globalParams[\reset][\gui] = button.(panel, "RESET",
    bgColor:Color.black, scaleW:0.19, scaleH:0.05
).action_({ |bt|
    world.params.values.do { |element|
        if (element[\spec].isNil.not && element[\gui].isNil.not) {
            element[\gui].valueAction_(element[\spec].default)
        };
    }
});
globalParams[\skelsimul][\gui] = buttonCheckbox.(panel, "skel",
    bgColor:Color.black, scaleW:0.19, scaleH:0.05
).action_({ |bt|
    bt.value.postln;

    // bookmark
    // XXX finish it!
    // if (bt.value.booleanValue) {
    //     if (skelData.isNil) {loadSkelData.()};
    //     skelSimul.start
    // } {
    //     skelSimul.stop
    // }
});
sText.(panel, " ", stringFont:fontSmall, scaleH:0.5, scaleW:0.05); // gap

// GUI: button based physics params
[\particleSystem, \mutualAttraction].do { |key|
    world.params[key][\gui] = buttonCheckbox.(
        panel,
        world.params[key][\label],
        bgColor:Color.black, scaleW:0.18, scaleH:0.05
    )
    .value_(world.params[key][\default])
    .action_({ |bt|
        bt.value.postln;
        // XXX finish it!
        // eventPool.append((
        //     message: \physics,
        //     params: [key, updateWorldParm.(key, bt.value)]
        // ))
    })
};
// GUI log right
panel = compViewFlow.(panelRight, scaleH: 0.5);
logRight = TextView(panel, (panel.bounds.width*0.99)@(panel.bounds.height*0.96))
    .editable_(false)
    .font_(fontSmall)
    .stringColor_(Color.new255(11, 96, 224))
    .background_(transparent)
    .hasVerticalScroller_(false)
    .canFocus_(false);


// GUI: canvas sliders
panel = compViewFlow.(panelCenter, scaleW:0.95); // gap
panel = compViewFlow.(panelCenter, scaleW:0.04);
[\distance, \perspective].do { |key|
    canvas.applyGui(key,
        slider.(panel, key, canvas.params[key], \vert, 0.15)
            .action_({ |sl| canvas.apply(key, sl.value) })
            .value_(canvas.val(key))
    );
};
// GUI: auto-rotate button
sText.(panel, " ", stringFont:fontSmall, scaleH:0.01); // gap
canvas.applyGui(\rotate,
    buttonCheckbox.(
        panel, canvas.params[\rotate].label,
        bgColor: Color.black, scaleW: 0.8, scaleH: 0.03
    )
    .action_({ |bt| canvas.apply(\rotate, bt.value.booleanValue) })
    .value_(canvas.val(\rotate))
);


// Post messages to a given GUI element (must be TextView)
logMsg = { |msg, txtView|
    var start, color, line, logMaxSize=5000;
    // Updates post colors when postView size shrinks.
    var updatePostColors = { |colors, start|
        colors.size.do { |i|
            colors[i][\start] = colors[i][\start] - start
        };
        all {: k, k <-colors, k[\start] > 0 };
    };

    msg = msg.asString;
    line = msg.split($\n)[0];
    if (msg.endsWith("\n").not) { msg = msg ++ "\n" };

    // XXX - less colors! more highlights..
    color = case
    { line.beginsWith("INFO") || line.beginsWith("->") } { techColor }
    { line.beginsWith("DEBUG") || line.beginsWith("$>") } { techColor }
    { line.beginsWith("WARNING") } { Color.white }
    { line.beginsWith("ERROR") } { Color.new255(158, 33, 33) }
    { fontColor };

    {
        // do not grow too long
        if (txtView.string.size > logMaxSize) {
            start = txtView.string.size - logMaxSize;
            txtView.string = txtView.string[start..];
            postColors = updatePostColors.(postColors, start);
        };
        postColors.add((start: txtView.string.size, num: line.size, color: color));
        postColors.add((start: txtView.string.size+line.size, num: msg.size-line.size, color: fontColor));
        txtView.string = txtView.string ++ msg;
        postColors.do { |c|
            txtView.setStringColor(c[\color], c[\start], c[\num]);
        };
        txtView.select(txtView.string.size, 1); // autoscroll
    }.defer;
};



// Parses /g_queryTree.reply:
// [ /g_queryTree.reply, 0, 1008, 2, 1014, -1, bass__a2, 1010, 2, 1012, -1, atru__a2, ... ]
// and fills out synth name for a particle as well as formats server tree
oscGroupTree = OSCFunc({ |msg, time, addr, recvPort|
    var name, part;
    logMsg.(
        format("%:%: %\n", addr.ip, addr.port, msg),
        logLeft
    );
    // fill out srv tree
    if (msg[2] == 0) {
        logMsg.(
            format("-> /g_queryTree.reply (%:%)\n%\n", addr.ip, addr.port, ~formatSrvTree.(msg)),
            logLeft
        );
    };
}, '/g_queryTree.reply');


// Animate and display
canvas.canvas.animate = true;
{ // GLOBAL APP CLOCK. Resolution: 100 milliseconds (0.1 of a second)
    while {win.isClosed.not} {
        // report nodes every now and then
        tick = tick + 1;
        if (tick % 20 == 0) {
            ~scsynth.sendMsg("/g_queryTree", 0);
        };

        if (tick % [3, 5, 10, 20, 50].choose == 0) {
            logMsg.(
                msg: File(
                    ~currentDir +/+ "experiments/" +/+
                    [
                        "transparent_window.scd",
                        "skel_simulation.scd",
                        "remote_srv__.scd",
                        "skelsimulator_pseudoclass.scd"
                    ].choose, "r"
                ).readAllString,
                txtView: [logLeft, logRight].choose
            );
        };

        if (tick >= 20000) {
            tick = 0;
        };
        0.1.wait;
    }
}.fork(AppClock);

win.front;

clean = {
    // stop meter view explicitly to remove synths for internal levels
    meterView.stop;
    oscGroupTree.free;
    win.close;
};

CmdPeriod.doOnce({
    clean.();
});
)