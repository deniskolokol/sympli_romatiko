(
var win, clean, run=true;
var skelData, taskSkeletonJoint;
var count=0, next=100, tick=0.003, redraw=0.08, hold=0;
var unit=40;
var index=0;
var space;
var focalStream, scaleStream, focalPoint=3, scaleDepth=1, isGrid=false;
var numUnitsX, numUnitsY;
var x, y, z;
var skel=(), joint;
var pointFrom, pointTo, xyz2plane, drawLine, lineColor;
var xyA, xyB, xyDevA, xyDevB, deviation, randomize;
var paths, currPath;

space = (
    width: Window.screenBounds.width,
    height: Window.screenBounds.height,
    depth: 1000
);

postf("Reading skeleton simulation data\n");
skelData = File(
    PathName(thisProcess.nowExecutingPath).pathOnly +/+ "joints.log", "r"
).readAllString.interpret;

taskSkeletonJoint = Task({ |msg, time, addr, recvPort|
    var joint, x, y, z;
    inf.do {
        if (index == skelData.size) { index = 0 };
        joint = skelData[index][0];
        #x, y, z = skelData[index][1..];
        skel[joint] = (
            x: x.linlin(-0.1, 1.1, 0, space.width),
            y: y.linlin(-0.15, 0.99, 0, space.height),
            z: z.linlin(0.3, 3.4, 0, space.depth)
        );
        index = index + 1;
        tick.wait;
    };
}).start;

xyz2plane = { arg pos, scale=1, focal=0.5;
    var x, y, z, ox, oy;
    z = space.depth - pos.z / (space.depth * scale);
    z = z.linlin(0, space.depth, focal, 1);
    x = pos.x * z;
    y = pos.y * z;
    ox = 1 - z * (space.width * 0.5) + x;
    oy = 1 - z * (space.height * 0.5) + y;
    [ox, oy]
};

drawLine = { |pointA, pointB, lineColor, lineWidth=1|
    Pen.width = lineWidth;
    Pen.strokeColor = lineColor ? Color.white;
    Pen.moveTo(pointA.x@pointA.y);
    Pen.lineTo(pointB.x@pointB.y);
    Pen.stroke;
};

randomize = { |n, dev, factor=0.25|
    n + (1.rand2 * rrand(dev, dev * factor))
};

focalStream = Pbrown(0.3, Pwrand([0.7, 1, 3], #[10, 2, 1].normalizeSum, inf), 0.1, inf).asStream;
scaleStream = Pgbrown(0.3, Pwrand([0.7, 1, 1.5], #[5, 2, 1].normalizeSum, inf), 0.1, inf).asStream;

paths = [
    [
        [\head, \neck],
        [\l_hand, \l_elbow, \l_shoulder, \l_hip, \l_knee, \l_foot],
        [\r_hand, \r_elbow, \r_shoulder, \r_hip, \r_knee, \r_foot],
        [\r_shoulder, \l_shoulder],
        [\r_hip, \l_hip],
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \neck, \r_shoulder, \r_elbow, \r_hand],
        [\l_shoulder, \torso, \r_shoulder],
        [\l_foot, \l_knee, \l_hip, \torso, \r_hip, \r_knee, \r_foot]
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \r_hip, \r_knee, \r_foot],
        [\r_hand, \r_elbow, \r_shoulder, \l_hip, \l_knee, \l_foot],
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \l_hip, \l_knee, \l_foot],
        [\r_hand, \r_elbow, \r_shoulder, \r_hip, \r_knee, \r_foot],
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \r_shoulder, \r_elbow, \r_hand],
        [\l_foot, \l_knee, \l_hip, \r_hip, \r_knee, \r_foot],
    ],
    [
        [\head, \neck, \torso],
        [\l_hand, \l_elbow, \l_shoulder, \l_hip, \l_knee, \l_foot],
        [\r_hand, \r_elbow, \r_shoulder, \r_hip, \r_knee, \r_foot],
        [\l_hand, \r_hand],
        [\l_elbow, \r_elbow],
        [\l_shoulder, \r_shoulder],
        [\l_hip, \r_hip],
        [\l_knee, \r_knee],
        [\l_foot, \r_foot],
    ]
];
currPath = paths.choose;

win = Window("sipsik", Rect(128, 64, space.width, space.height));
win.view.background = Color.black;
win.onClose = { run = false };
win.front;

win.drawFunc = {
    count = count + 1;

    // variable space depth for "jumping picture" effect
    if (count % 30.rand == 0) {
        focalPoint = focalStream.next;
        scaleDepth = scaleStream.next;
        unit = focalPoint.linlin(0, 3, 30, 5);
    };

    // variable background
    if (count % next == 0) {
        win.view.background = [
            Color.black,
            Color.grey(1.0.rand),
            Color.red(1.0.rand),
            Color.white,
        ].choose;
        isGrid = 0.5.coin;
        next = rrand(10, 100);

        currPath = paths.choose;
        hold = [0, 18.rand].choose;

        if (count >= 1e+6) {count = 0};
    };

    if (hold > 0) {
        hold = hold - 1;
        Pen.translate(
            scaleDepth*(hold.linlin(0, 9, 500, 50)),
            focalPoint*(hold.linlin(0, 9, 200, 10))
        );
        Pen.scale(scaleDepth, scaleDepth);
        Pen.skew(scaleDepth.rand2, scaleDepth.rand2);
    };

    // draw skeleton
    currPath.do { |path|
        path.do { |jo, j|
            if (j < (path.size-1)) {
                // drawLine.(skel[jo], skel[path[j+1]]); // guide (no depth)

                lineColor = Color.grey(skel[jo][\z].linlin(0, space.depth, 1, 0));
                deviation = skel[jo][\z].lincurve(0, space.depth, 1, 20, -4);

                xyA = xyz2plane.(
                    (
                        x:skel[jo][\x].round(unit),
                        y:skel[jo][\y].round(unit),
                        z:skel[jo][\z]
                    ),
                    scale:scaleDepth,
                    focal:focalPoint
                );
                xyB = xyz2plane.(
                    (
                        x:skel[path[j+1]][\x].round(unit),
                        y:skel[path[j+1]][\y].round(unit),
                        z:skel[path[j+1]][\z]
                    ),
                    scale:scaleDepth,
                    focal:focalPoint
                );
                drawLine.(
                    pointA:(x:xyA[0], y:xyA[1]),
                    pointB:(x:xyB[0], y:xyB[1]),
                    lineColor:lineColor
                );

                // intenionally messy lines around each "bone"
                10.do {
                    xyDevA = (
                        x: randomize.(xyA[0], deviation),
                        y: randomize.(xyA[1], deviation)
                    );
                    xyDevB = (
                        x: randomize.(xyB[0], deviation),
                        y: randomize.(xyB[1], deviation),
                    );
                    drawLine.(xyDevA, xyDevB, lineColor);

                    // additional lines for the head
                    if (jo == \head) {
                        xyDevA = (
                            x: randomize.(xyA[0]-unit, deviation),
                            y: randomize.(xyA[1]+unit, deviation)
                        );
                        xyDevB = (
                            x: randomize.(xyA[0]+unit, deviation),
                            y: randomize.(xyA[1]+unit, deviation),
                        );
                        drawLine.(xyDevA, xyDevB, lineColor);
                    };
                };
            };
        };
    };

    // draw grid
    Pen.strokeColor = Color.grey(0.3);
    Pen.width = 0.5;
    Pen.use {
        if (isGrid) {
            rrand(600, 1000).do {
                Pen.beginPath;
                Pen.moveTo(Point(21.rand * 80 + 40, 13.rand * 80 + 40));
                Pen.lineTo(Point(21.rand * 80 + 40, 13.rand * 80 + 40));
                Pen.stroke;
            };
        } {
            numUnitsX = (space.width / unit).ceil;
            numUnitsY = (space.height / unit).ceil;
            rrand(600, 1000).do {
                Pen.beginPath;
                pointFrom = Point(numUnitsX.rand*unit, numUnitsY.rand*unit);
                pointTo = Point(numUnitsX.rand*unit, numUnitsY.rand*unit);
                Pen.moveTo(pointFrom);
                Pen.lineTo(pointTo);
                Pen.stroke;
            };
        }
    };
};

{ while { run } { win.refresh; rrand(redraw, redraw*0.25).wait } }.fork(AppClock);

win.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
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
};

clean = {
    taskSkeletonJoint.stop;
    win.close;
};

CmdPeriod.doOnce({
    clean.()
});
)