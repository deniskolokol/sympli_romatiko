// probe (Ambisonic)
SynthDef(\sr_prob, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1,
		dtl=0.01, dtr=0.05;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.85pi, 0.85pi, 0.25pi], speakerElev= 0, speakerDist= [3, 2.5, 2.5, 3], maxDist=3, scaleFlag=1;
	var in, out, fbase, signal, startPos=0.0, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= ay.linlin(0,1, 2,0.1) * exprand(3,8);
	fbase= distance.linlin(0,1.41, 25,4000);
	in = LPZ2.ar(
		LFPulse.ar(
			fbase, 2pi.rand, 0.1,
			(
			Mix.ar(SinOsc.ar(rate * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand], 0.04)).max(0)
			* Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand])).abs
			* (amp*0.2))
			)
		);
	2.do({ in= AllpassN.ar(in, 0.05, [dtl, dtr], 3.0.rand, 2); });
	in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
}).send(s);

// ringz (Ambisonic)
SynthDef(\sr_ringz, {
	arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.85pi, 0.85pi, 0.25pi], speakerElev= 0, speakerDist= [3, 2.5, 2.5, 3], maxDist=3, scaleFlag=1;
	var in, out, signal;
	var fbase, phase, cutoff, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	fbase= distance.linexp(0,1.41, 10,40);
	phase= velocity*100;
	cutoff= distance.linexp(0,1.41, 200,2000);
	in=
		Ringz.ar(SinOsc.ar(fbase, phase.lag(0.01), amp*0.01), cutoff, 0.01);
	5.do({in});
	in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
}).send(s);
