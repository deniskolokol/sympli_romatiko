// Sympli Romatikó
// module: World
//
// TEST it: world_traer_parts_n_synths.scd

// TO-DO:
// - when the sceleton is present, a star becomes an object,
//   -- attracted to skeleton's hands
//   -- guiding particles (and occasionally synths)
// - add to synths last example from TermanWang, but build on its example sthn original
// - clean attractions after particles die!
// - limit number of skeletons simultaneously processed

(
//PARAMETERS
//
var world = (
    width: 700,
    height: 700,
    depth: 700,
    starMass: 1,
    particleDefaultMass: 0.5,
    particleDefaultAge: inf,
    particleOnSpring: 0.6,
    mutualAttraction: true,
    repulsion: 100,
    gravity: (x: 0, y: 0, z: 0),
    drag: 0.5,
    maxVel: 70,

    // springs behavior
    springRestLen: 5,
    springStrength: 2,
    springDamp: 2,

    // to what joints a particle can be attached by spring
    springSrcSkel: [\r_hand, \l_hand],

    // particles
    particles:         0, // run particles
    partSigmoidRatio:  0.7, // steepness of sigmoid function determiming probability of particle being born
    partFreq:          0.8, // generate a new particle \partFreq times per second
    partAgeThresh:     0.84, // maximum particle age in cycles (sec)
    partInitAccel:     5, // particle initial acceleration
    partSynth:         \sr__e__analog
);

var audio = (
    surround: "ambisonic2",
    fountainSynth: \sr__e__analog,
    depth: 5,
    in: 20,
    out: 0
);

var skel = (
    waitBeforeRemove: 5
);

// COMMUNICATION
//
var oscParticle, oscPhysics, oscAudio, oscAction,
    oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost,
    oscRemoveFunc;

// PHYSICS
var star;
var physics, particles, springs, pos, repulsion;
var initParticle, removeParticle, removeAll,
    registerParticle, unregisterParticle, particleSystem,
    applyAttractions, removeAttraction, handleBoundaryCollisions,
    registerSpring, registerSprings, applySpring, removeSpring,
    translateSpringEnd;
var paramsChanged;

// AUDIO
var removeGroup, initGroup;

// SKELETON
var skeleton = Dictionary.new,
    skeletonParticles, skeletonRemove,
    getGuide, getSource, chooseSource;

// INTERFACE
//
var win = Window("Sympli Romatikó :: WORLD", Rect(0, 500, world.width, world.height), false);
var view = UserView(win, Rect(0, 0, world.width, world.height)).background = Color.black;
var frame = 0, fps = 30;

var winMonitor = Window("Sympli Romatikó :: MONITOR", Rect(705, 1000, 360, world.height + 100));
var textParticles, textAttractions, textForces, textSprings, textSkeleton, textTest;
var monitor, message, spacer = "\n--------------------\n";

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

// Increments integers with a limit: resets to `lo` every time in + step reaches `hi`.
var clipInc = { |in=0, step=1, lo=0, hi=inf| ((in + step).clip(lo, hi) % hi).clip(lo, hi)};


// INTERFACE
//
var drawMonitorView = { |parent, width=350, height=130|
    var uv = UserView(winMonitor, width@height);
    uv.background = Color.new255(0, 0, 0, alpha:180);
    uv
};
var drawMonitorArea = { |parent, width, height|
    var st;
    width = width ?? parent.bounds.width;
    height = height ?? parent.bounds.height;
    st = StaticText(parent, width@height).focus(false);
    st.align = \topLeft;
    st.font = Font("Monaco", 12);
    st.stringColor = Color.white;
    st
};

winMonitor.addFlowLayout;
textParticles = drawMonitorArea.(drawMonitorView.(winMonitor, height:200));
textSprings = drawMonitorArea.(drawMonitorView.(winMonitor, height:200));
textAttractions = drawMonitorArea.(drawMonitorView.(winMonitor));
textForces = drawMonitorArea.(drawMonitorView.(winMonitor, height:65));
textSkeleton = drawMonitorArea.(drawMonitorView.(winMonitor, height:80));
textTest = drawMonitorArea.(drawMonitorView.(winMonitor, height:95));

view.mouseDownAction = { |v, x, y|
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
            ["/s_new", \sr__e__analog, s.nextNodeID, 0, g, // add synth to new group's head
                \outbus, 4, // feeding into spatilizer
                \depth, audio.depth,
                \bufnum, k.bufnum
            ]
        );
        b.sendMsg('/particle', 1, g, 1, rrand(0.8, 2.0), 600.rand, 600.rand, 600.rand, inf);
    }
};

// Monitoring.
monitor = {
    // TO-DO:
    // it should be possible to delete any particle (small [x] button near each nodeID)
    // and tear up any string (the same in strings)
    var springEnds = Array.fill(2, { nil });

    message = "Particles" ++ spacer;
    message = message ++ format(" %\t(star)\n", star.identityHash);
    particles.keysValuesDo { |k, v|
        message = message ++ format(" %\t%\n", k.identityHash, v.asString)
    };
    textParticles.string = message;

    message = "Springs" ++ spacer;
    springs.keysValuesDo { |k, v|
        springEnds = [v[0].identityHash, v[1].identityHash];
        if (v[0].class != TraerParticle) { springEnds[0] = v[0] };
        if (v[1].class != TraerParticle) { springEnds[1] = v[1] };
        message = message ++ format("% \t(%, %)\n", k, springEnds[0], springEnds[1])
    };
    message = message ++ (spacer ++ "Physics springs" ++ spacer);
    physics.springs.do { |g|
        message = message ++ format("% \t(%, %)\n", g.identityHash, g.a.identityHash, g.b.identityHash)
    };
    textSprings.string = message;

    message = "Skeletons" ++ spacer;
    skeleton.keysValuesDo { |k, v|
        message = message ++ format(" %:\t", k);
        v.keysValuesDo { |j, p|
            if (world.springSrcSkel.includes(j)) {
                message = message ++ format("% \t %\t", j, p.identityHash)
            }
        }
    };
    textSkeleton.string = message;

    message = "Attractions" ++ spacer;
    physics.attractions.do { |k|
        message = message ++ format("%\t%\n", k.a.identityHash, k.b.identityHash)
    };
    textAttractions.string = message;

    message = "Forces" ++ spacer;
    textForces.string = message ++ format("Gravity: %, %, %\nDrag: %\n",
        physics.gravity.x, physics.gravity.y, physics.gravity.z,
        physics.drag.round(0.00001));
};

view.drawFunc = {
    paramsChanged = false;
    frame = frame + 1;

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

    // Control skeletons.
    skeleton.keys.do { |id|
        if ((Date.getDate.secStamp.asInteger - skeleton[id][\update].asInteger) >= skel.waitBeforeRemove) {
            skeletonRemove.(id);
            paramsChanged = true;
        }
    };

    // Particle system.
    if (world.particles.booleanValue) {
        if (frame % (fps * world.partFreq + (world.partFreq * 0.5).rand2).round == 0) {
            particleSystem.(getGuide.())
        }
    };

    // Springs can get lost, when skeleton momentarily disappear,
    // global dictionary is used for checking their presence.
    springs.keysValuesDo { |springId, particles|
        if ((all {: g.identityHash, g <- physics.springs} ? []).includes(springId).not) {
            applySpring.(particle:particles[0], source:particles[1])
        }
    };
    // After re-applying.
    registerSprings.(physics.springs);

    // Manage particles.
    physics.particles.do { |particle|
        // Re-apply world forces, if there was any change in its parameters
        if (paramsChanged) {
            // and if a particle isn't on spring
            if ((all {: [g.a, g.b], g <- physics.springs} ? []).includes(particle).not) {
                applyAttractions.(particle, world.mutualAttraction);
            }
        };
        handleBoundaryCollisions.value(particle);
        // Visualize particles.
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
    physics.springs.do { |spring, i|
        Pen.color = Color.white;
        Pen.moveTo(Point(spring.a.position.x, spring.a.position.y));
        Pen.lineTo(Point(spring.b.position.x, spring.b.position.y));
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
            \amp, mag3D.(particle.velocity).distort * particle.mass,
            \ax, particle.position.x / world.width,
            \ay, particle.position.y / world.height,
            \az, particle.position.z.linlin(0, world.depth, 1, 0),
            \velocity, mag3D.(particle.velocity).distort.pow(10), // scale by sigmoid (distort), smooth by .pow
            \master, 1,
            \depth, audio.depth
        )
    };

    monitor.();

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


// Register individual spring in the global dictionary.
registerSpring = { |spring|
    var endA, endB;
    if (spring.isNil.not) {
        #endA, endB = [spring.a, spring.b];
        skeleton.keysValuesDo { |skel, joints|
            world.springSrcSkel.do { |jt|
                if (joints[jt] == endA) { endA = jt };
                if (joints[jt] == endB) { endB = jt };
            };
        };
        springs[spring.identityHash] = [endA, endB];
    }
};


// Register springs from List in the global dictionary.
registerSprings = { |springsList|
    springsList.do { |spring|
        registerSpring.(spring)
    }
};


// Translates spring end from joint name to particle.
translateSpringEnd = { |end|
    if (world.springSrcSkel.includes(end)) {
        try {
            end = skeleton[skeleton.keys.asArray[0]][end]
        } {
            end = nil
        }
    };
    end
};


// Apply spring: choose a source and connect particle to it.
applySpring = { |particle, source, ks, d, r|
    if (source.isNil) { source = getSource.() };
    particle = translateSpringEnd.(particle);
    source = translateSpringEnd.(source);
    if (particle.isNil.not && source.isNil.not) {
        physics.makeSpring(source, particle,
            ks ? world.springStrength, d ? world.springDamp, r ? world.springRestLen);
    }
};


// Apply forces.
applyAttractions = { |particle, mutual=false|

    // bookmark!
    // Fix attractions that survive particle's death

    // Attraction of the Star.
    if (particle != star) {
        physics.removeAttraction(particle);
        physics.makeAttraction(star, particle, star.mass * 1000, 50)
    };

    // Mututal attraction / repulsion.
    if (mutual.booleanValue) {
        physics.particles.do { |part|
            if ((particle != part) && (particle != star)) {
                physics.removeAttraction(part);
                physics.makeAttraction(particle, part, (particle.mass * world.repulsion).neg, 10);
            }
        }
    }
};


// Choose a source (skeleton with the "lightest" hand).
chooseSource = {
    var mass, sources = IdentityDictionary.new;
    skeleton.keysValuesDo { |skel, joints|
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


// Select source of force depending on the presence of skeleton.
getSource = { |starAllowed=false|
    if (skeleton.keys.size > 0) {
        chooseSource.()
    } {
        if (starAllowed) { star } { nil }
    }
};


// Select guide (where obj appears) depending on objects velocity.
getGuide = {
    var guides = IdentityDictionary[star -> mag3D.(star.velocity)];
    skeleton.keysValuesDo { |skel, joints|
        joints.keysValuesDo { |joint, p|
            if (p.class == "TraerParticle") {
                guides[joint] = mag3D.(p.velocity);
            };
        }
    };
    // the faster the object, the bigger a chance to become a guide
    guides.findKeysForValue(guides.values.wchoose(guides.values.exp.normalizeSum))[0]
};


// Init new particle.
initParticle = { |mass, x, y, z, age, vel|
    var particle, guide;
    if ([x, y, z].any({ |i| i < 0 })) { // negative coordinates ask for guide
        guide = getGuide.();
        #x, y, z = [guide.position.x, guide.position.y, guide.position.z];
    } {
        #x, y, z = [x ? world.width.rand, y ? world.height.rand, z ? world.depth.rand]
    };
    particle = physics.makeParticle(mass ? world.particleDefaultMass, x, y, z);
    try {
        particle.velocity.set(vel[0], vel[1], vel[2])
    };
    // Particles age "backwards": age == 0 is death, age >= 0 is afterlife.
    try {
        particle.age = (age * fps).abs.neg;
    } {
        particle.age = inf.neg;
    };
    particle
};


// Particle system.
particleSystem = { |guide|
    var pos, vel, prob;

    // probability of the birth of particle depends on the guide's velocity
    prob = sigmoid.(
        ratio:world.partSigmoidRatio,
        value:mag3D.(guide.velocity).linlin(0, world.maxVel, world.maxVel.neg, world.maxVel));

    if (prob.coin.booleanValue) {
        pos = guide.position;
        vel = guide.velocity;
        registerParticle.(
            initParticle.(0.2, pos.x, pos.y, pos.z,
                world.partAgeThresh.logistic,
                [vel.x, vel.y, vel.z].neg * world.partInitAccel.max(0.01)),
            initGroup.(
                world.partSynth, audio.surround, params:[\att, 2.0.rand]
            )
        );
    }
};


// Remove spring.
removeSpring = { |spring|
    springs.removeAt(spring.identityHash);
    physics.removeSpring(spring);
};


// Remove attraction.
removeAttraction = { |attraction|
    physics.removeAttraction(attraction);
};


// Remove a particle.
removeParticle = { |particle|
    // remove springs
    physics.springs.do { |spring|
        if ([spring.a, spring.b].includes(particle)) {
            removeSpring.(spring)
        }
    };
    // remove attractions
    physics.attractions.do { |attr|
        if ([attr.getOneEnd, attr.getTheOtherEnd].includes(particle)) {
            removeAttraction.(attr)
        }
    };
    physics.removeParticle(particle);
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


initGroup = { |synth, spatial, bufnum, busnum, params|
    // WARNING - TEST ONLY!
    //
    // Physics engine should send a msg with a node number to audio engine.
    // It is audio engine's job to create group on server.
    //
    var node, l=30, h=53;
    spatial = spatial.asString;
    if (spatial.beginsWith("sr__s__").not) {
        spatial = "sr__s__" ++ spatial.toLower
    };
    node = s.nextNodeID;
    if (busnum.isNil) {
        busnum = clipInc.(~route ?? l, lo:l, hi:h);
        ~route = busnum;
    };
    s.sendBundle(0.01,
        ["/error", 1], // turn errors off (locally)
        ["/g_new", node],
        ["/s_new", spatial, s.nextNodeID, 1, node, // add spatializer to new group's tail
            \inbus, busnum, // getting signal from synth
        \outbus, audio.out], // to main output
        ["/s_new", synth, s.nextNodeID, 0, node, // add synth to new group's head
            \inbus, audio.in, // getting signal from external input
            \outbus, busnum, // feeding into spatilizer
        \bufnum, bufnum] ++ (params ? [])
    );
    node // return ID of the Group created
};


// SKELETON
//
// Creates a particle for each joint of the skeleton.
skeletonParticles = { |id, joint, x, y, z|
    var part;
    if (skeleton.keys.includes(id).not) {
        skeleton[id] = (complete: false);
    };
    if (joint.isNil.not) {
        if (skeleton[id].keys.includes(joint).not) {
            part = initParticle.(world.starMass, x, y, z);
            part.makeFixed;
            skeleton[id][joint] = part;
        };
        skeleton[id][joint].position.set(x, y, z);
    };
    skeleton[id][\update] = Date.getDate.secStamp;
};


// Removes skeleton particles.
skeletonRemove = { |id|
    skeleton[id].do { |p|
        // removeParticle.(p)

        // TO-DO:
        // don't just remove particles, but better remove all springs,
        // update particles' age and let them die slowly
        // something like p.age = -3;

        physics.springs.do { |spring|
            if ([spring.a, spring.b].includes(p)) {
                physics.removeSpring(spring);
            }
        };
        physics.removeParticle(p);
    };
    skeleton.removeAt(id)
};


// OSC
//
// Catch messages related to particles.
oscParticle = OSCFunc({ |msg, time, addr, recvPort|
    var particle, node, age, mass, x, y, z, spring, registered;
    postf("from % received %\n", addr, msg);
    node = msg[2];
    msg[1].switch(
        1, { // create particle
            mass = msg[4];
            try {
                #x, y, z, age = msg[5..]
            } {
                #x, y, z, age = nil ! 4
            };
            particle = initParticle.(mass, x, y, z, age);
            registerParticle.(particle, node);
            if (msg[3].booleanValue) {
                spring = applySpring.(particle);
                registered = registerSpring.(spring);
            };
            if (msg[3].booleanValue.not || registered.isNil) {
                // "spring" can be specified, but failed
                // in this case apply attractions
                applyAttractions.(particle)
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
        \gravX, {
            world.gravity = (x: msg[2].asFloat, y: world.gravity.y, z: world.gravity.z)
        },
        \gravY, {
            world.gravity = (x: world.gravity.x, y: msg[2].asFloat, z: world.gravity.z)
        },
        \gravZ, {
            world.gravity = (x: world.gravity.x, y: world.gravity.y, z: msg[2].asFloat)
        },
        \drag, { world.drag = msg[2].asFloat },
        \repulsion, { world.repulsion = msg[2].asFloat },
        \star, {
            msg[2].switch(
                \fixed, { star.makeFixed },
                \free, { star.makeFree },
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
        },
        { // default action
            try { world[msg[1]] = msg[2]};
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
springs = IdentityDictionary.new;

// Star is in the center.
star = initParticle.(world.starMass, world.width/2, world.height/2, world.depth/2);
applyAttractions.(star, world.mutualAttraction);

// Animate!
view.animate = true;
win.front;
winMonitor.front;

// Load synthDefs.
"Loading synth definitions...".postln;
~currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;
if (this.executeFile(~currentDir +/+ "synthdef.scd").isNil.not) {
    postf("OK\n\n")
};

CmdPeriod.doOnce({
    oscRemoveFunc.();
    win.close;
    winMonitor.close;
});
)