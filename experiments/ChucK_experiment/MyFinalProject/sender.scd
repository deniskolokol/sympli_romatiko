(
var host = "127.0.0.1";
var port = 6448;
var receiver = NetAddr.new(host, port);
var currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;
var skelData = File(currentDir +/+ "joints.log", "r").readAllString.interpret;
var drawColor = Color.grey(0.5);
var space = (width: 900, height: 600, depth: 600);
var xyz = (x: space.width*0.5, y: space.height*0.5, z: space.depth*0.5);
var physics = TraerParticleSystem(gy:1, drag:0.05);
var ballLeftHand = physics.makeParticle(1, xyz.x, xyz.y, xyz.z);
var ballRightHand = physics.makeParticle(1, xyz.x, xyz.y, xyz.z);
var ballLeft = physics.makeParticle(1, xyz.x, xyz.y, xyz.z);
var ballRight = physics.makeParticle(1, xyz.x, xyz.y, xyz.z);
var ballHead = physics.makeParticle(25, xyz.x, xyz.y, xyz.z);
var skel = (
	\head: xyz, \neck: xyz, \torso: xyz,
	\l_hand: xyz, \l_elbow: xyz, \l_shoulder: xyz,
	\r_shoulder: xyz, \r_elbow: xyz, \r_hand: xyz,
	\l_foot: xyz, \l_knee: xyz, \l_hip: xyz,
	\r_hip: xyz, \r_knee: xyz, \r_foot: xyz
);
var skelSimulation = {
	var i=0, joint, x, y, z;
	inf.do { // process log
		if (i == skelData.size) {i = 0};
		joint = skelData[i][0];
		#x, y, z = skelData[i][1..];
		z = z + 0.6; // offset
		skel[joint] = (
            x: x.linlin(0.0, 1.0, 0, space.width),
            y: y.linlin(0.0, 1.0, 0, space.height),
            z: z.linlin(0.0, 5.0, 0, space.depth)
        );
		// send joint position over
		// WARNING: ballRight and ballLeft are being used for left and right hands
		// (from withing view.drawFunc)
		if ([\l_hand, \r_hand].includes(joint).not) {
			// simulate skeleton no 1 (3rd parm)
			// joints don't have velocity (last parm)
			receiver.sendMsg("/joint", joint, 1, x, y, z, 0);
			["/joint", joint, 1, x, y, z, 0].postln;
		};
		i = i + 1;
		0.002.wait;
	}
}.fork;
var xyz2plane = { arg pos, scale=1, focal=1;
    var x, y, z, ox, oy;
    z = space.depth - pos.z / (space.depth * scale);
    z = z.linlin(0, space.depth, focal, 1);
    x = pos.x * z;
    y = pos.y * z;
    ox = 1 - z * (space.width * 0.5) + x;
    oy = 1 - z * (space.height * 0.5) + y;
    [ox, oy]
};
var drawLine = { |pointA, pointB, lineColor, lineWidth=1|
    Pen.width = lineWidth;
    Pen.strokeColor = lineColor ? Color.white;
    Pen.moveTo(pointA.x@pointA.y);
    Pen.lineTo(pointB.x@pointB.y);
    Pen.stroke;
};
var drawBall = { |color, x, y, z|
	Pen.fillColor_(color);
	Pen.fillOval(Rect.aboutPoint(Point(x, y), z, z));
};
var partPlainCoords = { |p|
	var x, y, z;
	#x, y = xyz2plane.((x: p.position.x, y: p.position.y, z: p.position.z));
	z = p.position.z.linlin(0, space.depth, 1, 0);
	[x, y, z]
};
var scaleCoords = { |p|
	[
		p.position.x.linlin(0.0, space.width, 0.0, 1.0),
		p.position.y.linlin(0.0, space.height, 0.0, 1.0),
		p.position.z.linlin(0.0, space.depth, 0.0, 5.0)
	].clip(0.0, 1.0)
};
var mag3D = { |vec|
	var func = { |vector| [vector.x.pow(2), vector.y.pow(2), vector.z.pow(2)].sum.sqrt};
    var result = 0;
    try {
        result = func.(vec)
    } {
        result = List.new;
        vec.do { |vector| result.add(func.(vector)) };
        result = result.asArray;
    };
    result
};
var getVel = { |vel|
	mag3D.(vel).linlin(0.0, 10.0, 0.0, 1.0).clip(0.0, 1.0)
};
var handleBoundaryCollisions = { |p|
    if (p.position.x < 0 or:{p.position.x > space.width}) {
        p.velocity.set(-0.9 * p.velocity.x, p.velocity.y, p.velocity.z);
    };
    if(p.position.y < 0 or:{p.position.y > space.height}) {
        p.velocity.set(p.velocity.x, -0.9 * p.velocity.y, p.velocity.z);
    };
    if(p.position.z < 0 or:{p.position.z > space.depth}) {
        p.velocity.set(p.velocity.x, p.velocity.y, -0.9 * p.velocity.z);
    };
    p.position.set(
        p.position.x.clip(0, space.width),
        p.position.y.clip(0, space.height),
        p.position.z.clip(0, space.depth));
};
var win = Window("skel", Rect(700, 450, space.width, space.height));
var view = UserView(win, space.width@space.height);

// forces
physics.setDrag(0.8);
physics.makeSpring(ballLeftHand, ballLeft, 1, 0.1, 8);
physics.makeSpring(ballRightHand, ballRight, 1, 0.1, 8);

view.drawFunc = { |view|
	var xyA, xyB, xyLeft, xyRight, zPos, x, y, z;

	// draw skeleton
    [
        [\head, \neck, \torso],
		[\l_hand, \l_elbow, \l_shoulder, \r_shoulder, \r_elbow, \r_hand],
        [\l_foot, \l_knee, \l_hip, \r_hip, \r_knee, \r_foot]
    ].do { |path|
		path.do { |jo, j|
			#x, y, z = [skel[jo][\x], skel[jo][\y], skel[jo][\z]];
			if (jo == \l_hand) { ballLeftHand.position.set(x, y, z) };
			if (jo == \r_hand) { ballRightHand.position.set(x, y, z) };
			if (jo == \head) { ballHead.position.set(x, y, z) };
			xyA = xyz2plane.((x: x, y: y, z: z));
			zPos = z.linlin(0, space.depth, 1, 0);
			drawColor = Color.grey(z);
			Pen.fillColor_(drawColor);
			// Pen.fillOval(Rect.aboutPoint(Point(xyA[0], xyA[1]), zPos*10, zPos*10));
			drawBall.(drawColor, xyA[0], xyA[1], zPos*10, zPos*10);
			if (j < (path.size-1)) {
				// drawLine.(skel[jo], skel[path[j+1]]); // guide (no depth)
				xyB = xyz2plane.((
					x:skel[path[j+1]][\x],
					y:skel[path[j+1]][\y],
					z:skel[path[j+1]][\z]
				));
				drawLine.(
					pointA:(x:xyA[0], y:xyA[1]),
					pointB:(x:xyB[0], y:xyB[1]),
					lineColor:drawColor
				);
			};
		};
    };
	// visualize particles on springs
	#x, y, z = partPlainCoords.(ballLeft);
	drawBall.(Color.red, x, y, z*10, z*10);
	#x, y, z = partPlainCoords.(ballRight);
	drawBall.(Color.red, x, y, z*10, z*10);
	// visualize springs
	physics.springs.do { |sp|
		#x, y, z = [sp.a.position.x, sp.a.position.y, sp.a.position.z];
		xyA = xyz2plane.((x: x, y: y, z: z));
		#x, y, z = [sp.b.position.x, sp.b.position.y, sp.b.position.z];
		xyB = xyz2plane.((x: x, y: y, z: z));
		drawLine.(
			pointA: (x: xyA[0], y:xyA[1]),
			pointB:(x:xyB[0], y:xyB[1]),
			lineColor: Color.red
		);
	};
	// send left and right hand messages
	#x, y, z = scaleCoords.(ballLeft);
	receiver.sendMsg("/joint", \l_hand, 1, x, y, z, getVel.(ballLeft.velocity));
	["/joint", \l_hand, 1, x, y, z, getVel.(ballLeft.velocity)].postln;
	#x, y, z = scaleCoords.(ballRight);
	receiver.sendMsg("/joint", \r_hand, 1, x, y, z, getVel.(ballRight.velocity));
	["/joint", \r_hand, 1, x, y, z, getVel.(ballRight.velocity)].postln;

    physics.tick;
};
view.animate = true;
win.front;

CmdPeriod.doOnce({
	skelSimulation.stop;
	receiver.disconnect;
	win.close;
});
)