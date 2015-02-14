// Sympli Romatikó
// module: World

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
    drag: 0.001,
    maxVel: 5,

    // springs behavior
    springRestLen: 2,
    springStrength: 1,
    springDamp: 2,

    // to what joints a particle can be attached by spring
    springSrcSkel: [\r_hand, \l_hand],

    // particles
    particles:         0, // run particles
    partSigmoidRatio:  0.7, // steepness of sigmoid function determiming probability of particle being born
    partFreq:          0.8, // generate a new particle \partFreq times per second
    partAgeThresh:     0.84, // maximum particle age in cycles (sec)
    partInitAccel:     5, // particle initial acceleration
    partSynth:         \sr__e__pulse
);
var worldParams = Dictionary.newFrom(world); // tracing changes of the world

var audio = (
    surround: "ambisonic2",
    fountainSynth: \sr__e__analog,
    in: 20,
    out: 0
);

var skel = (
    waitBeforeRemove: 5,
    limit: 1
);

// COMMUNICATION
//
var oscParticle, oscPhysics, oscAudio, oscAction,
    oscSkeletonJoint, oscSkeletonNew, oscSkeletonLost,
    oscRemoveFunc, oscGroupTree;

// PHYSICS
var star;
var physics, particles, springs, position;
var initParticle, removeParticle, removeAll,
    registerParticle, unregisterParticle, particleSystem,
    applyAttractions, removeAttraction, handleBoundaryCollisions,
    registerSpring, registerSprings, applySpring, removeSpring, setSpringProp;
var resolveSpringEnd, decodeParticle;
var paramsChanged;

// SKELETON
var skeleton = Dictionary.new,
    skeletonParticles, skeletonRemove,
    getGuide, getSource, chooseSource,
    jointVisible = #[\l_hand, \l_elbow, \neck, \r_elbow, \r_hand];

// INTERFACE
//
var win = Window("Sympli Romatikó :: WORLD", Rect(0, 500, world.width, world.height), false);
var view = UserView(win, Rect(0, 0, world.width, world.height)).background = Color.black;

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
view.mouseDownAction = { |view, x, y, modifiers, buttonNumber, clickCount|
    var processed = false;
    if (clickCount == 2) {
        physics.particles.do { |particle|
            if (
                ((x - particle.position.x).abs <= 20) &&
                ((y - particle.position.y).abs <= 20)
            ) {
                processed = true;
                if (particle != star) {
                    unregisterParticle.(particles[particle][\node]);
                    removeParticle.(particle);
                };
            };
        };
    } {
        if (processed.not) { star.position.set(x, y, 0) }
    };
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
                \depth, ~depth,
                \bufnum, k.bufnum
            ]
        );
        b.sendMsg('/particle', 1, g, 1, rrand(0.8, 2.0), 600.rand, 600.rand, 600.rand, inf);
    }
};

view.drawFunc = { |worldView|
    var springsPhysical, springMissed;
    var particlesOnSprings, particlesSkelVis, particlesHidden;
    var attractionsPhysical;
    var partColor, partSize;

    // depth
    Pen.color = Color.new255(212, 156, 152, 50);
    Pen.fillOval(Rect.aboutPoint(Point(world.width * 0.5, world.height * 0.5),
        ~depth.linlin(1, 10, 20, world.height * 0.5),
        ~depth.linlin(1, 10, 20, world.height * 0.5)));

    // calibration marks
    Pen.color = Color.grey(0.7);
    Pen.stringAtPoint("-0.25", [5, 5].asPoint);
    Pen.stringAtPoint("0", [5, (world.height - 15) * 0.5].asPoint);
    Pen.stringAtPoint("0.25", [5, world.height - 20].asPoint);
    Pen.stringAtPoint("0.5", [(world.width - 25) * 0.5, world.height - 20].asPoint);
    Pen.stringAtPoint("0.75", [world.width - 35, world.height - 20].asPoint);
    Pen.stringAtPoint("1", [world.width - 15, (world.height - 15) * 0.5].asPoint);
    Pen.stringAtPoint("-0.75", [world.width - 45, 5].asPoint);
    Pen.stringAtPoint("-0.5", [(world.width - 35) * 0.5, 5].asPoint);
    Pen.line([world.width * 0.5, 25].asPoint, [world.width * 0.5, world.height - 25].asPoint);
    Pen.line([25, world.height * 0.5].asPoint, [world.width - 25, world.height * 0.5].asPoint);
    Pen.stroke;

    paramsChanged = false;
    if (worldParams != world) {
        paramsChanged = true;
        worldParams = Dictionary.newFrom(world);
        // some should be updated directly
        star.mass = world.starMass;
        physics.setGravity(world.gravity.x, world.gravity.y, world.gravity.z);
        physics.setDrag(world.drag);
    };

    // Control skeletons.
    skeleton.keys.do { |id|
        try {
            if ((Date.getDate.secStamp.asInteger - skeleton[id][\update].asInteger) >= skel.waitBeforeRemove) {
                skeletonRemove.(id);
                paramsChanged = true;
            }
        }
    };

    // Particle system.
    if (world.particles.booleanValue) {
        if (worldView.frame % (worldView.frameRate * world.partFreq).round == 0) {
            particleSystem.(getGuide.())
        }
    };

    // Springs should stick to hands even after skeleton is lost and then appears again.
    // Track connections of springs in a global dictionary.
    springsPhysical = all {: g.identityHash, g <- physics.springs} ? [];
    springs.keysValuesDo { |springId, end|
        if (springsPhysical.includes(springId).not) {
            springMissed = applySpring.(end[0], end[1]);
        }
    };
    // Update global dictionary of springs.
    if (springMissed.isNil.not) { // only if new springs created
        springs = IdentityDictionary.new;
        registerSprings.(physics.springs);
    };

    // Remove attractions that stuck after a particle's death.
    attractionsPhysical = Array.newFrom(physics.attractions);
    attractionsPhysical.do { |attr|
        if (
            physics.particles.includes(attr.getOneEnd).not ||
            physics.particles.includes(attr.getTheOtherEnd).not
        ) { removeAttraction.(attr) }
    };

    // Manage particles.
    particlesSkelVis = all {: v[k], v <- skeleton.values, k <- v.keys, jointVisible.includes(k) } ? [];
    particlesHidden = all {: v[k], v <- skeleton.values, k <- v.keys, jointVisible.includes(k).not } ? [];
    particlesOnSprings = (all {: [g.a, g.b], g <- physics.springs} ? []).flatten;
    Array.newFrom(physics.particles).do { |particle|
        // Re-apply world forces, if there was any change in its parameters
        if (paramsChanged) {
            if (particlesOnSprings.includes(particle)) {
                // if particle is on spring, change spring's properties
                setSpringProp.(particle:particle);
            } {
                // if particle isn't on spring, re-apply attractions
                if (particlesHidden.includes(particle).not) { // exclude hidden particles
                    applyAttractions.(particle, world.mutualAttraction);
                }
            };
        };
        handleBoundaryCollisions.value(particle);

        // send parameters to the group on Server
        if (particles.keys.includes(particle)) {
            position = Complex(
                particle.position.x.linlin(0, world.width, 1, -1), // y
                particle.position.y.linlin(0, world.height, -1, 1) // x
            );
            s.sendMsg("/n_set", particles[particle][\node],
                \ax, particle.position.x / world.width,
                \ay, particle.position.y / world.height,
                \az, particle.position.z.linlin(0, world.depth, 1, 0),
                \azimuth, position.theta,
                \distance, position.rho, // distance from the center
                \elevation, particle.position.z.linlin(0, world.depth, 0.5pi, -0.5pi), // how high the object is (inverse)
                \velocity, mag3D.(particle.velocity).distort.pow(10), // scale by sigmoid func (distort), smooth by .pow
                \amp, (
                    particle.mass.clip(0.01, 0.8) // the main contributor to object's loudness is its mass
                    + (mag3D.(particle.velocity) * 0.01) // subtle "colors" due to velocity
                ).clip(0, 1),
                \master, 1,
                \depth, ~depth
            );
        };

        // Visualize particles.
        if (particlesHidden.includes(particle).not) {
            case
            {particle == star} {
                partColor = Color.red;
                partSize = 15
            }
            { particlesSkelVis.includes(particle) } {
                partColor = Color.white;
                partSize = 10
            }
            {
                partColor = Color(particle.mass.linlin(0, 1, 0.2, 1), // the heavier the object, the redder it appears
                    particle.mass.linlin(0, 1, 0.7, 1), particle.mass.linlin(0, 1, 1, 0.1));
                partSize = 5;
                Pen.color = Color.grey(particle.position.z.linlin(0, world.depth, 1, 0.5));
                Pen.stringAtPoint(particles[particle][\synth].asString.stripWhiteSpace,
                    [
                        (particle.position.x+10).clip(10, world.width-45),
                        (particle.position.y+10).clip(10, world.height-15),
                    ].asPoint,
                    Font("Helvetica", 14));
            };
            Pen.color = partColor;
            z = partSize * particle.position.z.linlin(0, world.depth, 1, 0.1);
            Pen.fillOval(Rect.aboutPoint(Point(particle.position.x, particle.position.y), z, z));
        };

        // Age control: particles age "backwards",
        // i.e. age = 0 is a death and positive age is afterlife.
        if (particle.age >= 0) { particle.dead = true };
        if (particle.dead) {
            unregisterParticle.(particles[particle][\node]);
            removeParticle.(particle)
        };
    };

    // Visualize springs.
    physics.springs.do { |spring, i|
        Pen.color = Color.white;
        Pen.moveTo(Point(spring.a.position.x, spring.a.position.y));
        Pen.lineTo(Point(spring.b.position.x, spring.b.position.y));
        Pen.stroke;
    };
    // Visualize attractions.
    physics.attractions.do { |attr, i|
        Pen.color = Color.yellow(alpha:0.3);
        Pen.moveTo(Point(attr.a.position.x, attr.a.position.y));
        Pen.lineTo(Point(attr.b.position.x, attr.b.position.y));
        Pen.stroke;
    };
    // Visualize joins connections.
    Pen.color = Color.grey(0.5);
    Pen.width = 4;
    skeleton.values.do { |sk|
        jointVisible.size.do { |j|
            try {
                Pen.moveTo(Point(sk[jointVisible[j]].position.x, sk[jointVisible[j]].position.y));
                Pen.lineTo(Point(sk[jointVisible[j+1]].position.x, sk[jointVisible[j+1]].position.y));
                Pen.stroke;
            }
        }
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


// Returns display of a particle "role" (a Star, a skeleton's joint or an ordinary particle).
decodeParticle = { |particle|
    var result;
    if (particle == star) {
        result = "Star"
    } {
        skeleton.keysValuesDo { |skel, joints|
            world.springSrcSkel.do { |jt|
                if (joints[jt] == particle) {
                    result = format("% - %", skel, jt)
                };
            };
        };
    };
    if (result.isNil) { try { result = particle.identityHash } };
    result
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
resolveSpringEnd = { |end|
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
setSpringProp = { |spring, particle|
    if (spring.isNil) {
        physics.springs.do { |sp|
            if ([sp.a, sp.b].includes(particle)) { spring = sp }
        }
    };
    spring.setDamping(world.springDamp);
    spring.setRestLength(world.springRestLen);
    spring.setStrength(world.springStrength);
};


// Apply spring: choose a source and connect particle to it.
applySpring = { |particle, source, ks, d, r|
    var spring;
    if (source.isNil) { source = getSource.() };
    source = resolveSpringEnd.(source);
    particle = resolveSpringEnd.(particle);
    if (particle.isNil.not && source.isNil.not) {
        spring = physics.makeSpring(source, particle,
            ks ? world.springStrength, d ? world.springDamp, r ? world.springRestLen);
    };
    spring
};


// Apply forces:
// - skeleton's hands ALWAYS attracts all particles, including Star, regardless of the `mutual` state
// - Star ALWAYS attract all objects, excluding skeleton's hands
// - ordinary objects attract each other only if `mutual` is true
applyAttractions = { |particle, mutual=false|
    var skeletonParticles=List.new, excludeParticles=List.new;
    List.newFrom(physics.attractions).do { |attr|
        if ((attr.a == particle) || (attr.b == particle)) {
            physics.removeAttraction(attr);
        }
    };
    // Attraction of the Star.
    if (particle != star) {
        physics.makeAttraction(star, particle, star.mass * 1000, 50);
    };
    // Gather lists of skeleton joints, that should /should not attract particles.
    skeleton.values.do { |skel|
        // exclude skeleton's particles that are not in world.springSrcSkel
        excludeParticles = all {: skel[joint], joint <- skel.keys,
            world.springSrcSkel.includes(joint).not
        } ? [];
        world.springSrcSkel.do { |joint|
            skeletonParticles.add(skel[joint])
        }
    };
    // Attraction to hands (different from mutual).
    if (skeletonParticles.isNil.not) {
        skeletonParticles.do { |skeletonParticle|
            if (excludeParticles.includes(particle).not) { // particle can be a skeleton's joint
                physics.makeAttraction(skeletonParticle, particle,
                    (particle.mass * (world.repulsion * 0.1)).neg, world.depth * 0.01
                );
            }
        };
    };
    // Exclude the Star, too.
    excludeParticles.add(star);
    // Mututal attraction / repulsion.
    if (mutual.booleanValue) {
        physics.particles.do { |part|
            if (
                (particle != part)
                && excludeParticles.includes(particle).not
                && excludeParticles.includes(part).not
                && skeletonParticles.includes(particle).not
                && skeletonParticles.includes(part).not
            ) {
                physics.makeAttraction(particle, part, (particle.mass * world.repulsion).neg, 10);
            }
        }
    };
};


// Choose a source (skeleton with the "lightest" hand).
chooseSource = {
    var mass, sources = IdentityDictionary.new;
    skeleton.keysValuesDo { |num, skel|
        world.springSrcSkel.do { |joint|
            mass = 0;
            physics.springs.do { |spring|
                // joint is always a source
                if (spring.a == skel[joint]) {
                    mass = mass + spring.b.mass
                };
            };
            sources.put(skel[joint], mass);
        };
    };
    // choose the one with minimum load
    sources.findKeyForValue(sources.values.minItem)
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
        world.springSrcSkel.do { |jt|
            // WARNING! Skeleton joints do not possess velocity,
            // the following doesn't work:
            //guides[joints[jt]] = mag3D.(joints[jt].velocity);

            // but always prefer skeleton joints to the Star
            guides[joints[jt]] = guides[star] * ([2, 5].choose);
        };
    };
    // the faster the object, the bigger a chance to become a guide
    guides.findKeyForValue(guides.values.wchoose(guides.values.exp.normalizeSum))
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
        particle.age = (age * 60).abs.neg;
    } {
        particle.age = inf.neg;
    };
    particle
};


// Particle system.
particleSystem = { |guide|
    var vel, prob;
    // probability of the birth of particle depends on the guide's velocity
    vel = guide.velocity;
    if (vel == 0) { vel = world.maxVel };
    prob = sigmoid.(
        ratio:world.partSigmoidRatio,
        value:mag3D.(vel).linlin(0, world.maxVel, world.maxVel.neg, world.maxVel));
    if (prob.coin.booleanValue) {
        registerParticle.(
            initParticle.(0.2, guide.position.x, guide.position.y, guide.position.z,
                world.partAgeThresh.logistic,
                [vel.x, vel.y, vel.z].neg * world.partInitAccel.max(0.01)),
            ~groupInit.(
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
    // remove registered springs, if any
    springs.keysValuesDo { |key, val|
        if (val.includes(particle)) {
            springs.removeAt(key);
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
removeAll = {
    particles.keys.do { |p, i|
        unregisterParticle.(particles[p][\node]);
        removeParticle.(p);
    }
};


// Register and unregister particle are separate functions
// from init and remove to support the case when an existing
// particle is being re-attached to a different node on the server.
//
// Register particle in the dictionary along with Server nodeId.
registerParticle = { |particle, nodeId|
    var taskSendMsg, keys=[];
    particles.put(particle, (node: nodeId));
    taskSendMsg = Task({
        inf.do { |j|
            try { keys = particles[particle].keys } { keys = [] };
            if ((keys.includes("synth")) || (j >= 20)) { // wait 2sec
                taskSendMsg.stop;
            };
            s.sendMsg("/g_queryTree", nodeId); // to fill out synth name
            0.1.wait;
        };
    }).start;
};


// Removes particle record from the dictionary.
unregisterParticle = { |nodeId|
    var particle;
    particles.keysValuesDo { |part, dict|
        if (dict[\node] == nodeId) { particle = part }
    };
    particles.removeAt(particle);
    ~groupFree.(nodeId);
    particle
};


// SKELETON
//
// Creates a particle for each joint of the skeleton.
skeletonParticles = { |id, joint, x, y, z|
    var part;
    if (skeleton.keys.includes(id).not) {
        if (skeleton.keys.asArray.size < skel.limit) {
            skeleton[id] = (complete: false)
        }
    };
    if (joint.isNil.not) {
        if (skeleton.keys.includes(id)) {
            if (skeleton[id].keys.includes(joint).not) {
                part = initParticle.(world.starMass, x, y, z);
                part.makeFixed;
                skeleton[id][joint] = part;
            };
            skeleton[id][joint].position.set(x, y, z);
            skeleton[id][\update] = Date.getDate.secStamp;
        };
    };
};


// Removes skeleton particles (cannot be removed as ordinary particles).
skeletonRemove = { |id|
    var springsPhysical;
    skeleton[id].do { |p|
        List.newFrom(physics.springs).do { |spring|
            if ([spring.a, spring.b].includes(p)) {
                physics.removeSpring(spring);
            }
        };
        List.newFrom(physics.attractions).do { |attr|
            if ([attr.getOneEnd, attr.getTheOtherEnd].includes(p)) {
                removeAttraction.(attr)
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
                applyAttractions.(particle, world.mutualAttraction)
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
        \drag, {
            world.drag = msg[2].asFloat
        },
        \repulsion, {
            world.repulsion = msg[2].asFloat
        },
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


oscGroupTree = OSCFunc({ |msg, time, addr, recvPort|
    var synth, i=0, node=msg[2].asInteger;
    // postf("from % received %\n", addr, msg);
    { synth.isNil }.while({
        i = i + 1;
        if ("sr__(e|g|p)__".matchRegexp(msg[i].asString)) {
            synth = msg[i].asString.stripWhiteSpace;
            synth = synth[7..]; // only synth type and name
        };
        if ((i >= msg.size) && (synth.isNil)) { synth = node.asString };
    });
    particles.keysValuesDo { |part, dict|
        if (dict[\node] == node) { dict[\synth] = synth }
    };
}, '/g_queryTree.reply');


// Remove all OSC functions.
oscRemoveFunc = {
    oscParticle.free;
    oscSkeletonNew.free;
    oscSkeletonLost.free;
    oscSkeletonJoint.free;
    oscGroupTree.free;
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

CmdPeriod.doOnce({
    oscRemoveFunc.();
    win.close;
});
)