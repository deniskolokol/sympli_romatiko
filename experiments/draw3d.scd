(
// the world is a cube stretched to a screen height
var worldSize = Window.screenBounds.height;
var width=Window.screenBounds.width;
var height=Window.screenBounds.height;
var depth=Window.screenBounds.height;
var rate=0.005;
var color, canvas, item, frame, clean;

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
var world=(
    particles: ( ),
);
var transX, transY, transZ;
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

var win = Window("3d canvas demo", Window.screenBounds.width@Window.screenBounds.height, false);
var physics = TraerParticleSystem.new;
var mouse = physics.makeParticle(1, 0, 0, 0);
var b = physics.makeParticle(1, width.rand, height.rand, depth.rand);
var c = physics.makeParticle(1, width.rand, height.rand, depth.rand);
mouse.makeFixed;
physics.makeAttraction(mouse, b, 10000, 10);
physics.makeAttraction(mouse, c, 10000, 10);
physics.makeAttraction(b, c, -10000, 5);

canvas = Canvas3D(win, Rect(0, 0, width, height))
.background_(Color.black)
.scale_(200)
.perspective_(0.2)
.distance_(1);

// frame is The World
canvas.add(frame = Canvas3DItem.cube
    .color_(Color.white)
    .width_(0.5)
);

physics.particles.do { |particle|
    if (particle == mouse) { color = Color.red } { color = Color.green };
    item = Canvas3DItem.cube
    .color_(color)
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
    frame.transforms = canvas.transforms;
    world.particles.keysValuesDo { |particle, item|
        transX = particle.position.x.linlin(0, width, -1, 1);
        transY = particle.position.y.linlin(0, height, -1, 1);
        transZ = particle.position.z.linlin(0, depth, -1, 1);
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
            prettyPrintDict.(world)
        }
    }
};

clean = {
    win.close;
};

CmdPeriod.doOnce({
    clean.();
});
)