(
// GUI
var width=Window.screenBounds.width;
var height=Window.screenBounds.height;
var depth=Window.screenBounds.height;
var rate=0.005;
var item, frame, clean;
var panel, palette;
var meterView;
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
            val: false
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
        //     message: \physics,
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
var sText = { |par, string, stringColor, stringFont, scaleH, scaleW=0.5|
    var st, height;
    if (scaleH.isNil) {
        // height = st.sizeHint.height.max(20); // XXX - how to do that before creation of StaticText?
        height = 20;
    } {
        height = paneHeight.(par, scaleH);
    };
    st = StaticText(par, paneWidth.(par, scaleW)@height);
    st.string = string;
    st.font = stringFont ? font;
    st.stringColor = stringColor ? fontColor;
    st
};

// WORLD
var world = (
    particles: ( ),
    params: (
        drag: (
            spec: ControlSpec(0.000, 0.500, \lin, 0.001, 0.001),
            midicc: 24,
        ),
        repulsion: (
            spec: ControlSpec(1, 100, \lin, 5, 100),
            midicc: 25,
        ),
        maxVel: (
            label: "max vel",
            spec: ControlSpec(0.5, 10, \lin, 0.1, 5)
        ),
        starMass: (
            label: "star mass",
            spec: ControlSpec(0.1, 5, \lin, 0.1, 1),
            midicc: 26,
        ),
        gravX: (
            label: "grav X",
            spec: ControlSpec(-2.1, 2.0, \lin, 0.01, 0),
            midicc: 27,
        ),
        gravY: (
            label: "grav Y",
            spec: ControlSpec(-2.1, 2.0, \lin, 0.01, 0),
            midicc: 28,
        ),
        gravZ: (
            label: "grav Z",
            spec: ControlSpec(-2.1, 2.0, \lin, 0.01, 0),
            midicc: 29,
        ),
        // springs
        springDamp: (
            label: "spr damp",
            spec: ControlSpec(0.1, 2, \lin, 0.1, 2),
            midicc: 33,
        ),
        springRestLen: (
            label: "rest len",
            spec: ControlSpec(1, 15, \lin, 1, 2),
            midicc: 31,
        ),
        springStrength: (
            label: "strength",
            spec: ControlSpec(0.1, 2, \lin,  0.1, 1),
            midicc: 32,
        ),
        // particle system
        particleSystem: (
            label: "particl",
            default: false,
            midinote: 45,
            hint: "run particle system",
        ),
        partSigmoidRatio: (
            label: "sigmoid",
            spec: ControlSpec(0.3, 0.9, \lin, 0.1, 0.7),
            midicc: 34,
            hint: "steepness of sigmoid function determiming probability of particle being born",
        ),
        partAgeThresh: (
            label: "part age",
            spec: ControlSpec(0.1, 2, \lin, 0.01, 0.84),
            midicc: 36,
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
            midicc: 35,
            hint: "generate new particle \partFreq times per second",
        ),
        partSynth: (
            label: "part synth",
            default: "pulse",
        ),
        mutualAttraction: (
            label: "mutual",
            default: true,
            midinote: 44,
        ),
    )
);
var globalParams = (
    serverVolume: (
        label: "MASTER",
        midicc: 12,
        spec: \db.asSpec
    ),
    maxDist: (
        midicc: 14,
        spec: ControlSpec(0.5, 30.0, \lin, 0.1, ~speakers.maxDist),
        ),
    depth: (
        midicc: 15,
        spec: ControlSpec(1, 10, \lin, 0.1, ~depth),
        ),
    skelSimulSpeed: ( // XXX - rename it to sthn like skelSimulInertia OR
                      //       change processing algo reversing this value to get `.wait`
        label: "simul vel",
        spec: ControlSpec(0.001, 0.005, \lin, 0.001, 0.002),
        midicc: 34,
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


var physics = TraerParticleSystem.new;
var mouse = physics.makeParticle(1, 0, 0, 0);
var b = physics.makeParticle(1, width.rand, height.rand, depth.rand);
var c = physics.makeParticle(1, width.rand, height.rand, depth.rand);

mouse.makeFixed;
physics.makeAttraction(mouse, b, 10000, 10);
physics.makeAttraction(mouse, c, 10000, 10);
physics.makeAttraction(b, c, -10000, 5);

// The World is the frame.
canvas.canvas.add(frame = Canvas3DItem.cube
    .color_(Color.white)
    .width_(0.5)
);

// Add particles to canvas.
physics.particles.do { |particle|
    item = Canvas3DItem.cube
    .color_(if (particle == mouse) { Color.red } { Color.green })
    .width_(1)
    .transform(Canvas3D.mScale(0.05));
    canvas.canvas.add(item);
    world.particles.put(particle, item);
};

// Add speakers to canvas.
~speakers.items.do { |speaker, i|
    // speaker cube
    item = Canvas3DItem.cube
    .color_(Color.blue)
    .width_(0.5)
    .transform(Canvas3D.mScale(0.1));
    canvas.canvas.add(item);
    speaker.put(\cube, item);

    // XXX - speaker stand
    #x, y, z = ade2xyz.(speaker, ~speakers.maxDist);
    postf("==> speaker %: %, %, %\n", i, x, y, z);
    item = Canvas3DItem()
    .color_(Color.blue)
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

canvas.canvas.mouseDownAction= { |v, x, y|
    mouse.position.set(x, y, 0);
};
canvas.canvas.mouseMoveAction = canvas.canvas.mouseDownAction;

// XXX
// // add slider for canvas spin (instead of mouse move)
// canvas.mouseMoveAction = { |v, x, y|
//     mouse.position.set(x, y, 0);
//     canvas.transforms = [
//         Canvas3D.mRotateY(x / -200 % 2pi),
//         Canvas3D.mRotateX(y / 200 % 2pi)
//     ];
//     canvas.refresh;
// };
// canvas.mouseMoveAction = canvas.mouseDownAction;
// canvas.mouseMoveAction.value(nil, 50, 50); // initial rotation

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

// GUI: slider controllers for physics and global params
panel = compViewFlow.(panelLeft, scaleH:0.56);
globalParams[\serverVolume][\gui] = slider.(panel, "s.vol", globalParams[\serverVolume])
    .action_({ |sl| ~scsynth.volume.volume = sl.value})
    .value_(1);
compViewFlow.(panel, scaleH:0.02); // gap
[
    \drag, \repulsion, \starMass,
    \gravX, \gravY, \gravZ,
    \springDamp, \springRestLen, \springStrength,
    \maxVel, \partInitAccel, \partFreq,
    \partDefaultMass, \partAgeThresh,
].do { |key, n|
    world.params[key][\gui] = sliderWorld.(panel, key, world.params[key]);
    // make a gap after every 3rd slider
    if ((n+1) % 3 == 0) {
        compViewFlow.(panel, scaleH:0.02)
    }
};

// GUI: slider controllers for global params
compViewFlow.(panel, scaleH:0.02); // gap
globalParams[\skelSimulSpeed][\gui] = slider.(panel, "skel simul",
    globalParams[\skelSimulSpeed])
    .action_({ |sl| globalParams[\skelSimulSpeed] = sl.value})
    .value_(1);
globalParams[\maxDist][\gui] = slider.(panel, "maxDist",
    globalParams[\maxDist])
    .action_({ |sl| ~speakers.maxDist = sl.value })
    .value_(~speakers.maxDist);
globalParams[\depth][\gui] = slider.(panel, "maxDist",
    globalParams[\depth])
    .action_({ |ez|
        ~depth = ez.value;
        ~sendMessage.('/audio', [\depth, ~depth])
    })
    .value_(~depth);

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

// Animate and display
canvas.canvas.animate = true;
win.front;

clean = {
    // stop meter view explicitly to remove synths for internal levels
    meterView.stop;
    win.close;
};

CmdPeriod.doOnce({
    clean.();
});
)