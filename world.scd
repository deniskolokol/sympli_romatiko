// Sympli Romatikó
// module: World
//
// TEST it: world_traer_parts_n_synths.scd

// TO-DO:
// - when the sceleton is present, a star becomes an object,
//   -- attracted to skeleton's hands
//   -- guiding particles (and occasionally synths)
// - add to synths last example from TermanWang, but build on its example sthn original

(
//PARAMETERS
//
var world = (
    width: 700,
    height: 700,
    depth: 700,
    starMass: 1,
    starSize: 10,
    particleDefaultMass: 5,
    particleDefaultAge: inf,
    mutualAttraction: true,
    repulsion: 100,
    gravity: (x: 0, y: 0, z: 0),
    drag: 0.5,

    // springs behavior
    springRestLen: 5,
    springStrength: 2,
    springDamp: 2,

    // to what joints a particle can be attached by spring
    springSrcSkel: [\r_hand, \l_hand]
);

var audio = (
    surround: "ambisonic2",
    fountainSynth: \sr__e__analog,
);

// COMMUNICATION
//
var oscParticle, oscPhysics, oscAudio, oscAction,
    oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost,
    oscRemoveFunc;

// PHYSICS
var star;
var physics, particles, pos, repulsion;
var initParticle, removeParticle, removeAll,
    registerParticle, unregisterParticle,
    handleBoundaryCollisions, applyAttractions, applySpring,
    removeSpring;

// AUDIO
var removeGroup;

// SKELETON
var skeleton = Dictionary.new,
    skeletonParticles, skeletonRemove,
    chooseSource;

// INTERFACE
//
var win = Window("Sympli Romatikó :: WORLD", Rect(0, 500, world.width, world.height), false);
var view = UserView(win, Rect(0, 0, world.width, world.height)).background = Color.black;
var fps = 60;

// HELPER FUNCTIONS
//
// 3-d vector(s) magnitude.
// `vec` can be either dictionary-like object (x:x, y:y, z:z), in which case
// a siggle float value of the magnitude is returned, or a collection of such
// objects, which result in a collection of magnitudes.
var mag3D = { |vec|
    var func = { |vector| (vector.x.sumsqr(vector.y) + vector.z.pow(2)).sqrt};
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

// Simple sigmoid function.
var sigmoid = { |ratio, value| 1 / (1 + exp((ratio * value).neg))};


view.mouseDownAction = {|v, x, y|
    star.position.set(x, y, 0);
};
view.mouseMoveAction = view.mouseDownAction;

win.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
    case
    // X - remove all particles and synths
    { keycode == 7 && [0, 256].includes(modifiers) } { removeAll.() }

    // Q - new object
    { keycode == 12 && [0, 256].includes(modifiers) } {
        // WARNING - TEST ONLY!
        b = NetAddr.new("127.0.0.1", 57120);
        k.free;
        k = Buffer.loadCollection(s, FloatArray[0, 3, 7, 10]); // default Scale buffer
        g = s.nextNodeID;

        s.sendBundle(0.001,
            ["/g_new", g],
            ["/s_new", \sr__s__ambisonic2, s.nextNodeID, 1, g, // add spatializer to new group's tail
                \inbus, 4, // getting signal from synth
                \outbus, 0], // to main output
            ["/s_new", \sr__e__melo, s.nextNodeID, 0, g, // add synth to new group's head
                \outbus, 4, // feeding into spatilizer
                \depth, 3,
                \bufnum, k.bufnum
            ]
        );
        b.sendMsg('/particle', 1, g, 1, rrand(0.8, 2.0), 600.rand, 600.rand, 600.rand, inf);
    }

    // Z - info
    { keycode == 6 && [0, 256].includes(modifiers) } {
        postf("\n---\nparticles: %\ngravity: %, %, %\ndrag: %\nattractions: %",
            particles, physics.gravity.x, physics.gravity.y, physics.gravity.z,
            physics.drag, physics.attractions);
        if (physics.springs.size > 0) {
            "\nsprings:".postln;
            physics.springs.do { |spring|
                postf("\t%: rest length %, strength %, damping %\n",
                    spring, spring.restLength, spring.strength, spring.damping)
            }
        };
        if (skeleton.size > 0) {
            "\nSkeleton:".postln;
            skeleton.keysValuesDo { |id, val| postf("%: %\n", id, val) }
        };
    }
};

view.drawFunc = {
    var paramsChanged = false;
    var particlesOnSprings = [];

    // world: gravity
    if (physics.gravity != TraerVector3D.newFromDict(world.gravity)) {
        physics.setGravity(world.gravity.x, world.gravity.y, world.gravity.z);
    };
    // world: drag
    if (world.drag != physics.drag) {
        physics.setDrag(world.drag);
    };
    // world: repulsion
    if (world.repulsion != repulsion) {
        repulsion = world.repulsion;
        paramsChanged = true;
    };
    // world: star mass
    if (star.mass != world.starMass) {
        star.mass = world.starMass;
        paramsChanged = true;
    };

    // Manage and visualize particles.
    physics.particles.do { |particle|
        // Re-apply world forces, if there was any change in its parameters
        if (paramsChanged) {
            // and if a particle isn't on spring
            physics.springs.do { |spring|
                particlesOnSprings = particlesOnSprings.addAll([spring.a, spring.b])
            };
            if (particlesOnSprings.includes(particle).not) {
                applyAttractions.(particle, world.mutualAttraction)
            }
        };

        handleBoundaryCollisions.value(particle);

        if (particle == star) {
            Pen.color = Color.red;
            Pen.fillOval(Rect.aboutPoint(Point(particle.position.x, particle.position.y),
                10 * particle.position.z.linlin(0, world.depth, 1, 0.1),
                10 * particle.position.z.linlin(0, world.depth, 1, 0.1)));
        } { // the heavier the object, the redder it appears
            Pen.color = Color(particle.mass.linlin(0, 1, 0.2, 1),
                particle.mass.linlin(0, 1, 0.7, 1), 1 - particle.mass);
            Pen.fillOval(Rect.aboutPoint(
                Point(particle.position.x, particle.position.y),
                5 * particle.position.z.linlin(0, world.depth, 1, 0.1),
                5 * particle.position.z.linlin(0, world.depth, 1, 0.1)));
        };

        // Age control: particles age "backwards",
        // i.e. age = 0 is a death and positive age is afterlife.
        if (particle.age >= 0) { particle.dead = true };
        if (particle.dead) {
            unregisterParticle.(particles[particle]);
            removeParticle.(particle)
        };
    };

    // Manage and visualize springs.
    physics.springs.do{ |spring, i|
        Pen.color = Color.white;
        Pen.moveTo(Point(spring.getOneEnd.position.x, spring.getOneEnd.position.y));
        Pen.lineTo(Point(spring.getTheOtherEnd.position.x, spring.getTheOtherEnd.position.y));
        Pen.stroke;
    };

    // send parameters to the group on Server
    particles.keysValuesDo { |particle, node|
        pos = Complex(
            particle.position.x.linlin(0, world.width, 1, -1), // y
            particle.position.y.linlin(0, world.height, -1, 1) // x
        );

        s.sendMsg("/n_set", node,
            \azimuth, pos.theta,
            \distance, pos.rho, // distance from the center
            \elevation, particle.position.z.linlin(0, world.depth, 0.5pi, -0.5pi), // how high the object is (inverse)
            \amp, mag3D.(particle.velocity).distort.pow(10) * particle.mass,
            \ax, particle.position.x / world.width,
            \ay, particle.position.y / world.height,
            \az, particle.position.z.linlin(0, world.depth, 1, 0),
            \velocity, mag3D.(particle.velocity).distort.pow(10), // scale by sigmoid (distort), smooth by .pow
            \master, 1,
            \depth, 3
        )
    };

    physics.tick;
};

// Handle collisions with World boundaries.
handleBoundaryCollisions = { |p|
    if (p.position.x < 0 or:{p.position.x > world.width}) {
        p.velocity.set(-0.9 * p.velocity.x, p.velocity.y, p.velocity.z);
    };
    if(p.position.y < 0 or:{p.position.y > world.height}) {
        p.velocity.set(p.velocity.x, -0.9 * p.velocity.y, p.velocity.z);
    };
    if(p.position.z < 0 or:{p.position.z > world.depth}) {
        p.velocity.set(p.velocity.x, p.velocity.y, -0.9 * p.velocity.z);
    };
    p.position.set(
        p.position.x.clip(0, world.width),
        p.position.y.clip(0, world.height),
        p.position.z.clip(0, world.depth));
};

// Apply forces.
applyAttractions = { |particle, mutual=false|
    // Attraction of the Star.
    if (particle != star) {
        physics.removeAttraction(star);
        physics.makeAttraction(star, particle, star.mass * 1000, 50)
    };

    // Mututal attraction / repulsion.
    if (mutual) {
        physics.particles.do { |part|
            if ((particle != part) && (particle != star) && (part != star)) {
                physics.removeAttraction(particle);
                physics.makeAttraction(particle, part, (particle.mass * world.repulsion).neg, 10);
            }
        }
    }
};

// Choose a source (skeleton with the "lightest" hand).
chooseSource = {
    var mass, sources = IdentityDictionary.new;
    skeleton.keysValuesDo { |skeleton, joints|
        joints.keysValuesDo { |joint, particle|
            if (world.springSrcSkel.includes(joint)) {

                // Calculate total mass connected to the current particle on springs.
                mass = 0;
                physics.springs.do { |spring|
                    // A joint is always a source.
                    if (spring.a == particle) { mass = mass + spring.b.mass };
                };
                sources[particle] = mass;
            };
        };
    };

    // choose among those with the minimum load
    sources.findKeysForValue(sources.values.minItem).choose
    ??
    // if there are none, the probabilities of picking any of them are equal
    skeleton.choose[world.springSrcSkel.choose]
};

// Apply spring: choose a source and connect particle to it.
applySpring = { |particle, ks, d, r|
    var source;
    // Decide upon source depending on the presence of skeleton.
    if (skeleton.keys.size > 0) {
        source = chooseSource.();
    } {
        source = star;
    };
    physics.makeSpring(source, particle,
        ks ? world.springStrength, d ? world.springDamp, r ? world.springRestLen);
};

// Init new particle.
initParticle = { |mass, x, y, z, age|
    var particle, guides, guide;
    if ([x, y, z].any({ |i| i < 0 })) { // negative coordinates ask for guide
        // TO-DO: add skeleton's hands here
        guides = [star];
        guides = all{: g.position, g <- guides};
        guide = guides.wchoose(mag3D.(guides).exp.normalizeSum); // the fastest one is a guide
        #x, y, z = [guide.x, guide.y, guide.z];
    } {
        #x, y, z = [x ? world.width.rand, y ? world.height.rand, z ? world.depth.rand]
    };
    particle = physics.makeParticle(mass ? world.particleDefaultMass, x, y, z);

    // Particles age "backwards": age == 0 is death, age >= 0 is afterlife.
    try {
        particle.age = (age * fps).abs.neg;
    } {
        particle.age = inf.neg;
    };
    particle
};

// Remove spring.
removeSpring = { |spring|
    physics.removeSpring(spring);
};

// Remove a particle.
removeParticle = { |particle|
    physics.removeParticle(particle);

    // control springs
    physics.springs.do { |spring|
        if ([spring.getOneEnd, spring.getTheOtherEnd].includes(particle)) {
            removeSpring.(spring)
        }
    }
};

// Remove all particles from the world and stop all synths.
removeAll = { |cleanSynths=true|
    particles.keysValuesDo { |particle, node|
        unregisterParticle.(node);
        removeParticle.(particle);
    }
};

// Register and unregister particle are separate functions
// from init and remove to support the case when an existing
// particle is being re-attached to a different node on the server.
//
// Register particle in the dictionary along with Server nodeId.
registerParticle = { |particle, nodeId|
    particles.put(particle, nodeId)
};

// Removes particle record from the dictionary.
unregisterParticle = { |nodeId|
    var particle;
    particle = particles.findKeyForValue(nodeId);
    particles.removeAt(particle);
    removeGroup.(nodeId);
    particle
};

// SYNTHS
//
// Release all synths from group, wait until released,
// then remove group node from server.
removeGroup = { |groupID, release=2|
    // WARNING - TEST ONLY!
    //
    // Physics engine should send a msg with a node number to audio engine.
    // It is audio engine's job to remove group from server.
    //
    Routine({
        [
            ["/n_set", groupID, \rel, release, \gate, 0],
            ["/n_free", groupID]
        ].do { |l|
            s.listSendMsg(l);
            release.wait;
        }
    }).play;
};

// SKELETON
//
// Creates a particle for each joint of the skeleton.
skeletonParticles = { |id, joint, x, y, z|
    if (skeleton.keys.includes(id).not) {
        skeleton[id] = (complete: false);
    };

    if (joint.isNil.not) {
        if (skeleton[id].keys.includes(joint).not) {
            skeleton[id][joint] = initParticle.(world.starMass, x, y, z);
            skeleton[id][joint].makeFixed;
        };
        skeleton[id][joint].position.set(x, y, z);
    };
};

// Removes skeleton particles.
skeletonRemove = { |id|
    skeleton[id].do { |p|
        removeParticle.(p)

        // TO-DO:
        // don't just remove particles, but better remove all springs,
        // update particles' age and let them die slowly
    }
};


// OSC
//
// Catch messages related to particles.
oscParticle = OSCFunc({ |msg, time, addr, recvPort|
    var particle, node, age, mass, x, y, z;
    postf("from % received %\n", addr, msg);
    node = msg[2];
    msg[1].switch(
        1, { // create particle
            mass = msg[4];
            try {
                #x, y, z, age = msg[5..]
            } {
                #x, y, z, age = nil ! 5
            };
            particle = initParticle.(mass, x, y, z, age);
            registerParticle.(particle, node);
            if (msg[3].booleanValue) { // springs
                applySpring.(particle);
            } { // attractions
                applyAttractions.(particle);
            };
        },
        0, { // remove particle
            particle = unregisterParticle.(node);
            removeParticle.(particle);
        }
    );
}, '/particle');

// Catch messages related to physics.
oscPhysics = OSCFunc({ |msg, time, addr, recvPort|
    var x, y, z;
    postf("from % received %\n", addr, msg);
    msg[1].switch(
        \gravity, {
            try {
                #x, y, z = msg[2..].asFloat
            } {
                #x, y, z = world.gravity.atAll([\x, \y, \z])
            };
            world.gravity = (x: x, y: y, z: z)
        },
        \drag, {
            world.drag = msg[2].asFloat
        },
        \repulsion, {
            world.repulsion = msg[2].asFloat
        },
        \star, {
            msg[2].switch(
                \fixed, {
                    star.makeFixed
                },
                \free, {
                    star.makeFree
                },
                \mass, {
                    try {
                        world.starMass = msg[3].asFloat
                    }
                },
                \pos, {
                    try {
                        #x, y, z = msg[3..].asFloat
                    } {
                        #x, y, z = [world.width.rand, world.height.rand, world.depth.rand]
                    };
                    star.position.set(x, y, z);
                }
            );
        }
    );
}, '/physics');

// Catch action messages.
oscAction = OSCFunc({ |msg, time, addr, recvPort|
    postf("from % received %\n", addr, msg);
    msg[1].switch(
        \remove, {
            if (msg[2] == \all) {
                removeAll.()
            } {
                removeParticle.(unregisterParticle.(msg[2].asInteger));
            }
        },
        \add, {
            // What other acts can be sent to the World?
        }
    );
}, '/action');

// Catch messages related to audio setup.
oscAudio= OSCFunc({ |msg, time, addr, recvPort|
    postf("from % received %\n", addr, msg);
    audio.putPairs(msg[1..]);
}, '/audio');

// Catch messages related to skeleton.
oscSkeletonLost = OSCFunc({ |msg, time, addr, recvPort|
    postf("from % received %\n", addr, msg);
    skeletonRemove.(msg[1]);
}, '/lost_skel');

oscSkeletonNew = OSCFunc({ |msg, time, addr, recvPort|
    postf("from % received %\n", addr, msg);
    skeletonParticles.(msg[1]);
}, '/new_skel');

oscSkeletonJoint = OSCFunc({ |msg, time, addr, recvPort|
    var id, joint, x, y, z;
    // postf("from % received %\n", addr, msg);
    id = msg[2].asInteger;
    joint = msg[1];
    #x, y, z = [
        msg[3].linlin(-0.1, 1.1, 0, world.width),
        msg[5].linlin(0.3, 3.4, 0, world.height),
        msg[4].linlin(-0.15, 0.99, 0, world.depth)
    ];
    skeletonParticles.(id, joint, x, y, z);
}, '/joint');

// Remove all OSC functions.
oscRemoveFunc = {
    oscParticle.free;
    oscSkeletonNew.free;
    oscSkeletonLost.free;
    oscSkeletonJoint.free;
};

// PHYSICS
//
physics = TraerParticleSystem.new;
particles = IdentityDictionary.new;

// Star is in the center.
star = initParticle.(world.starMass, world.width/2, world.height/2, world.depth/2);
applyAttractions.(star, world.mutualAttraction);

// Animate!
view.animate = true;
win.front;

// Load synthDefs.
"Loading synth definitions...".postln;
~currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;
if (this.executeFile(~currentDir +/+ "synthdef.scd").isNil.not) {
    postf("OK\n\n")
};

CmdPeriod.doOnce({
    oscRemoveFunc.();
    win.close
});
)