(
// CONSTANTS
//
var c_JOINTS = [ \head, \neck, \torso,
    \l_elbow, \l_foot, \l_hand, \l_hip, \l_knee, \l_shoulder,
    \r_elbow, \r_foot, \r_hand, \r_hip, \r_knee, \r_shoulder ];

// GLOBAL PARAMETERS
//
var params = (
    initMass: 5,
);

// OSC COMMUNICATION
var oscObjScheduler, oscParmScheduler, oscActScheduler,
oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost,
oscRemoveFunc;

// OBJECTS MANAGEMENT
var initObject = {}, removeObject = {};

// GROUPS AND SYNTHS MANAGEMENT
var startSynth, initGroup, removeGroup, mixerNode;

// SKELETON
var skeleton = Dictionary.new,
    skeletonParticles, skeletonConnections, skeletonRemove;
var configurations;

// PHYSICS
var width = Window.availableBounds.width,
    height = Window.availableBounds.height,
    depth = 600;
var num = 3, swarm = 30;
var physics, springs, particle, over;
var makeParticle;

// INTERFACE
var win = Window("traer skeleton", Rect(0, 0, width, height));
var usr = UserView(win, Rect(0, 0, width, height));
var fullscreen = false;

// SYSTEM
var shutDown;

// HELPER FUNCTIONS
var distance = { |x1, y1, x2, y2|
    var dx = x2 - x1;
    var dy = y2 - y1;
    (dx.pow(2) + dy.pow(2)).sqrt
};

// OSC COMMUNICATION
//
oscSkeletonLost = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from % received %\n", addr, msg);
    skeletonRemove.(msg[1]);
}, '/lost_skel');

oscSkeletonNew = OSCFunc({ arg msg, time, addr, recvPort;
    postf("from % received %\n", addr, msg);
    skeletonParticles.(msg[1]);
}, '/new_skel');

oscSkeletonJoint = OSCFunc({ arg msg, time, addr, recvPort;
    var id, joint, x, y, z;
    // postf("from % received %\n", addr, msg);
    id = msg[2].asInteger;
    joint = msg[1];
    #x, y, z = [
        msg[3].linlin(0, 1, width, 0),
        msg[4].linlin(0, 1, 0, height),
        msg[5].linlin(0, 7, 0, depth)
    ];
    skeletonParticles.(id, joint, x, y, z);
    skeletonConnections.(id);
}, '/joint');

// Remove all OSC functions.
oscRemoveFunc = {
    oscSkeletonNew.free;
    oscSkeletonLost.free;
    oscSkeletonJoint.free;
};

// PHYSICS
physics = TraerParticleSystem(gz:-0.3, drag:0.1);

makeParticle = { |mass, x, y, z|
    physics.makeParticle(mass ?? params[\initMass],
        x ?? width.rand, y ?? height.rand, z ?? depth.rand)
};

// Creates a particle for each joint of the skeleton.
skeletonParticles = { |id, joint, x, y, z|
    if (skeleton.keys.includes(id).not) {
        skeleton[id] = (complete: false);
    };

    if (joint.isNil.not) {
        if (skeleton[id].keys.includes(joint).not) {
            skeleton[id][joint] = makeParticle.(x:x, y:y, z:z);
            skeleton[id][joint].makeFixed;
        };
        skeleton[id][joint].position.set(x, y, z);
    };
};

// Creates connections between joints of the skeleton.
skeletonConnections = { |id, confID=0, ks=(1.0.rand), d=(0.3.rand), r=(30.rand+1)|
    var connections, jointTo;

    if (
        skeleton[id].keys.asArray.includesAll(c_JOINTS)
        && skeleton[id].atFail(\complete, {false}).not
    ) {
        // create connections
        connections = configurations.(confID);
        connections.keysValuesDo { |joint, conf|
            conf[\swarm].do {

                // connect joint and particle in the swarm
                particle = physics.makeParticle(1.0.rand + 0.5);
                physics.makeSpring(particle, skeleton[id][joint], ks, d, r);

                // connect particle in swarm and choosen joint
                jointTo = conf[\joint].wchoose(conf[\prob]);
                if (jointTo.isNil.not) {
                    physics.makeSpring(skeleton[id][jointTo], particle, ks, d, r)
                };
            };

            // fix connections
            skeleton[id][\complete] = true;
        }
    };
};

skeletonRemove = { |id|
    skeleton[id].do { |p|
        physics.removeParticle(p)

        // TO-DO:
        // don't just remove particles, but better remove all springs
        // and let particles slowly die
    }
};

usr.background = Color.black;
usr.drawFunc = {
    physics.tick;

    Pen.strokeColor = Color.white;
    physics.springs.do{ |s, i|
        Pen.moveTo(Point(s.getOneEnd.position.x, s.getOneEnd.position.y));
        Pen.lineTo(Point(s.getTheOtherEnd.position.x, s.getTheOtherEnd.position.y));
    };
    Pen.stroke;

    physics.particles.do { |p|
        if (p == over) {
            Pen.fillColor = Color.black;
        } {
            p.makeFree;
            Pen.fillColor = Color.white;
        };
        Pen.addOval(Rect.aboutPoint(
            Point(p.position.x, p.position.y),
            p.mass * (p.position.z / depth),
            p.mass * (p.position.z / depth)));
    };
    Pen.fill;
};

usr.animate = true;
win.front;

// connections configurations
configurations = { |id|
    (
        head: ( // "master" joint
            swarm: 5, // number or particles connecting to other joints
            joint: [\neck, \torso, \l_shoulder, \r_shoulder], // possible joins to be connected to
            prob: [5, 3, 0.5, 0.5].normalizeSum // probability of being connected to a particlar joint
        ),
        neck: (
            swarm: 5,
            joint: [\torso, \l_shoulder, \r_shoulder, \head, \l_elbow, \r_elbow],
            prob: [10, 6, 6, 3, 1, 1].normalizeSum
        ),
        l_shoulder: (
            swarm: 5,
            joint: [\l_elbow, \torso],
            prob: [10, 3].normalizeSum
        ),
        r_shoulder: (
            swarm: 5,
            joint: [\r_elbow, \torso],
            prob: [10, 3].normalizeSum
        ),
        l_elbow: (
            swarm: 5,
            joint: [\l_hand, \l_shoulder, \neck],
            prob: [10, 3, 0.5].normalizeSum
        ),
        l_hand: (
            swarm: 5,
            joint: [\l_elbow, nil], // nil means particles are connected to a joint only
            prob: [1, 3].normalizeSum
        ),
        r_elbow: (
            swarm: 5,
            joint: [\r_hand, \r_shoulder, \neck],
            prob: [10, 3, 0.5].normalizeSum
        ),
        r_hand: (
            swarm: 5,
            joint: [\r_elbow, nil], // nil means particles are connected to a joint only
            prob: [1, 3].normalizeSum
        ),
        torso: (
            swarm: 5,
            joint: [\l_hip, \r_hip, \neck, \l_shoulder, \r_shoulder],
            prob: [10, 10, 6, 4, 4].normalizeSum
        ),
        l_hip: (
            swarm: 5,
            joint: [\l_knee, \torso, \l_foot],
            prob: [10, 2, 0.5].normalizeSum
        ),
        l_knee: (
            swarm: 5,
            joint: [\l_foot, \l_hip],
            prob: [10, 2].normalizeSum
        ),
        l_foot: (
            swarm: 5,
            joint: [\l_knee, nil],
            prob: [1, 3].normalizeSum
        ),
        r_hip: (
            swarm: 5,
            joint: [\r_knee, \torso, \r_foot],
            prob: [10, 2, 0.5].normalizeSum
        ),
        r_knee: (
            swarm: 5,
            joint: [\r_foot, \r_hip],
            prob: [10, 2].normalizeSum
        ),
        r_foot: (
            swarm: 5,
            joint: [\r_knee, nil],
            prob: [1, 3].normalizeSum
        ),
    )
};

win.view.keyDownAction = { arg view, char, modifiers, unicode, keycode;
//    [char, modifiers, unicode, keycode].postln;
    case
    {keycode == 3} { // F - toggle fullscreen
        if ([0, 256].includes(modifiers)) {
            if (fullscreen) { win.endFullScreen } { win.fullScreen };
            fullscreen = fullscreen.not;
        }
    }
};

// Shutting down.
shutDown = {
    // Clean OSP responders.
    oscRemoveFunc.value();
    "Good bye...".postln;
};
CmdPeriod.doOnce({
    shutDown.();
    win.close;
});
)