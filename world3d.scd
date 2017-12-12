(
// GUI
var width=Window.screenBounds.width;
var height=Window.screenBounds.height;
var depth=Window.screenBounds.height;
var rate=0.005;
var item, frame, clean;
var panel, palette;
var meterView;
var transparent=Color.red(alpha:0.01);
var win = Window("entropia", Window.screenBounds.width@Window.screenBounds.height, false);
// GUI: 3d canvas
var canvas = Canvas3D(win, Rect(0, 0, width, height))
.background_(Color.black)
.scale_(200)
.perspective_(0.2)
.distance_(1);
// EZSlider(
//     view,
//     45@300,
//     " zoom  ",
//     \rate.asSpec,
//     { |ez| world.zoom = ez.value },
//     initVal: 1,
//     initAction: true,
//     unitWidth:30,
//     numberWidth:60,
//     layout:\vert
// )
// .setColors(
//     Color.grey,Color.white, Color.grey(0.7),Color.grey,
// Color.white, Color.yellow,nil,nil, Color.grey(0.7))
// .font_(Font("Helvetica", 10));

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
.background_(transparent)
.decorator_(FlowLayout(win.bounds));
var panelTop = compViewFlow.(view, scaleH: 0.01);
var panelLeft = compViewFlow.(view, Color.blue(alpha:0.1), scaleW: 0.175, scaleH: 0.98);
var panelCenter = compViewFlow.(view, scaleW: 0.6, scaleH: 0.98);
var panelRight = compViewFlow.(view,
    Color.green(alpha:0.1),
    scaleW: (1-((panelCenter.bounds.width+panelLeft.bounds.width)/view.bounds.width)).round(0.1).postln,
    scaleH: 0.98
);
var panelBottom = compViewFlow.(view, Color.yellow, scaleH: 0.01);

// WORLD
var world=(
    particles: ( ),
    zoom: 1.5,
    transX: 0,
    transY: 0,
    focus: 0,
);
var transX, transY, transZ;

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
// Pretty pint hierarchical structure.
var prettyPrintDict = { |data, output="", level=0|
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

var physics = TraerParticleSystem.new;
var mouse = physics.makeParticle(1, 0, 0, 0);
var b = physics.makeParticle(1, width.rand, height.rand, depth.rand);
var c = physics.makeParticle(1, width.rand, height.rand, depth.rand);

mouse.makeFixed;
physics.makeAttraction(mouse, b, 10000, 10);
physics.makeAttraction(mouse, c, 10000, 10);
physics.makeAttraction(b, c, -10000, 5);

// frame is The World
canvas.add(frame = Canvas3DItem.cube
    .color_(Color.white)
    .width_(0.5)
);

physics.particles.do { |particle|
    item = Canvas3DItem.cube
    .color_(
        if (particle == mouse) { Color.red } { Color.green }
    )
    .width_(0.5)
    .transform(Canvas3D.mScale(0.1));
    canvas.add(item);
    world.particles.put(particle, item);
};

canvas.animate(40) { |t|
    handleBoundaryCollisions.value(b);
    handleBoundaryCollisions.value(c);
    physics.tick;

    canvas.transforms = [ // spin the canvas
        Canvas3D.mRotateY(t*rate*1.0 % 2pi),
        Canvas3D.mRotateX(t*rate*1.5 % 2pi)
    ];
    frame.transforms = canvas.transforms ++ [
        Canvas3D.mScale(world.zoom)
    ];
    world.particles.keysValuesDo { |particle, item|
        transX = particle.position.x.linlin(0, width, -1, 1) * world.zoom;
        transY = particle.position.y.linlin(0, height, -1, 1) * world.zoom;
        transZ = particle.position.z.linlin(0, depth, -1, 1) * world.zoom;
        // if (particle == b) {transZ.postln}; // XXX
        item.transforms = frame.transforms ++ [
            Canvas3D.mRotateZ(t*rate*5 % 2pi),
            Canvas3D.mRotateX(t*rate*2 % 2pi),
            Canvas3D.mTranslate(transX, transY, transZ),
            Canvas3D.mScale(transZ)
        ];
    };
};

canvas.mouseDownAction= { |v, x, y|
    mouse.position.set(x, y, 0);
};
canvas.mouseMoveAction = canvas.mouseDownAction;

// // spin canvas on mouse move
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
canvas.animate = true;
win.front;

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
};

// GUI: draw GUI
// internal levels
panel = compViewFlow.(panelLeft, scaleH: 0.2);
palette = QPalette.dark;
palette.setColor(Color.black, \window);
panel.palette = palette;
meterView = EntroServerMeterView(~scsynth, panel, 0@0, 210);

clean = {
    // stop meter view explicitly to remove synths for internal levels
    meterView.stop;
    win.close;
};

CmdPeriod.doOnce({
    clean.();
});
)