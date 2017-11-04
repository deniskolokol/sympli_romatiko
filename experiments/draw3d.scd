(
var width=500, height=500, depth=500, rate=0.005;
var win, color, canvas, item, frame;
var physics, mouse, b, c, world=( );
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

win = Window("3d canvas demo", Rect(128, 64, width, height), false);
physics = TraerParticleSystem.new;
mouse = physics.makeParticle(1, 0, 0, 0);
mouse.makeFixed;
b = physics.makeParticle(1, width.rand, height.rand, depth.rand);
c = physics.makeParticle(1, width.rand, height.rand, depth.rand);
physics.makeAttraction(mouse, b, 10000, 10);
physics.makeAttraction(mouse, c, 10000, 10);
physics.makeAttraction(b, c, -10000, 5);

canvas = Canvas3D(win, Rect(0, 0, width, height))
.background_(Color.black)
.scale_(200)
.perspective_(0.2)
.distance_(1);

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
    world.put(particle, item);
};

world.postln;

canvas.animate(40) { |t|
	handleBoundaryCollisions.value(b);
	handleBoundaryCollisions.value(c);
	physics.tick;

    canvas.transforms = [ // spin the canvas
        Canvas3D.mRotateY(t*rate*1.0 % 2pi),
        Canvas3D.mRotateX(t*rate*1.5 % 2pi)
    ];
    frame.transforms = canvas.transforms;
    world.keysValuesDo { |particle, item|
        transX = particle.position.x.linlin(0, width, -1, 1);
        transY = particle.position.y.linlin(0, height, -1, 1);
        transZ = particle.position.z.linlin(0, depth, -1, 1);
        if (particle == b) {transZ.postln};
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

CmdPeriod.doOnce({
    world.keysValuesDo { |k, v|
        postf("% (%): % (%)\n", k, k.class, v, v.class)
    };
    win.close
});
)