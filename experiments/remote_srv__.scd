// boot remote server manually:
// $ ssh <login>@dk-synthsrv.local
// $ scsynth -t 57110 -i 4 -o 10 -z 512 -S 48000 -m 1048576 -H Saffire\ \(3090\) -v 0
c = Server("SynthServer", NetAddr.new("192.168.1.106", 57110));
{ c.addr.connect.debug("connected") }.defer(0.5);
c.startAliveThread(0);
c.doWhenBooted({
    "remote server started".postln;
    c.notify;
    c.initTree;
    c.queryAllNodes;
});

c.name

// test
SynthDef("sine", { Out.ar(0, Pan2.ar(SinOsc.ar(440, 0, 0.2), LFNoise1.ar(0.5))) }).send(c);
SynthDef("sine1", { Out.ar(2, Pan2.ar(SinOsc.ar(220, 0, 0.2), LFNoise2.ar(0.3))) }).send(c);
c.sendMsg("s_new", "sine", n = c.nextNodeID, 0, 1);
c.sendMsg("s_new", "sine1", m = c.nextNodeID, 0, 1);

// OR
c.sendMsg("s_new", "sr__e__analog", n=c.nextNodeID, 0, 1, \route, 0);
c.sendMsg("s_new", "sr__e__growl", m=c.nextNodeID, 0, 1, \route, 1);

c.meter;
c.sendMsg("/n_free", n);
c.sendMsg("/n_free", m);
c.quit