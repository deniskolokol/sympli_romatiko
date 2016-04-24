// TEST:
b = NetAddr.new("127.0.0.1", 57120);
k = Buffer.loadCollection(s, FloatArray[0, 3, 7, 10]); // default Scale buffer
c = {
    10.do { |i|
        g = s.nextNodeID;
        s.sendBundle(0.001,
            ["/g_new", g],
            ["/s_new", \sr__s__ambisonic2, s.nextNodeID, 1, g, // add spatializer to new group's tail
                \inbus, 4, // getting signal from synth
                \outbus, 0], // to main output
            ["/s_new", [\sr__e__analog, \sr__e__melo, \sr__e__wasp].choose, s.nextNodeID, 0, g, // add synth to new group's head
                \outbus, 4, // feeding into spatilizer
                \depth, 3,
                \bufnum, k.bufnum
            ]
        );
        4.0.rand.wait;
        // '/particle', create:1, node, spring:0|1, mass:9, x:470, y:300, z:250, age:inf
        b.sendMsg('/particle', 1, g, 0, rrand(0.5, 1), 600.rand, 600.rand, 600.rand, rrand(500, 5000));
    };
}.fork;

// '/particle', remove:0, nodeId:..
b.sendMsg('/particle', 0, 1008);

b.sendMsg('/physics', \drag, 0.001);
b.sendMsg('/physics', \gravity, 0, 0, 0);
b.sendMsg('/physics', \repulsion, 10);
b.sendMsg('/physics', \star, \mass, 5);
b.sendMsg('/physics', \star, \free);

f = {
    var grav;
    {
        grav = [0, 0, 0];
        grav[(0..2).choose] = 2.0.rand2;
        b.sendMsg('/physics', \gravity, grav[0], grav[1], grav[2]);
        rrand(0.5, 2.0).wait;

        b.sendMsg('/physics', \drag, 0.5.rand);
        rrand(0.5, 2.0).wait;

        b.sendMsg('/physics', \star, [\fixed, \free].choose);
        rrand(0.5, 2.0).wait;

        b.sendMsg('/physics', \star, \mass, rrand(1, 10));
        rrand(0.5, 2.0).wait;

        b.sendMsg('/physics', \star, \pos, 700.rand, 700.rand, 700.rand);
        rrand(0.5, 2.0).wait;
    }.loop;
}.fork

f.stop