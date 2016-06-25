// probe (VBAP4)
SynthDef(\sr_prob, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1,
		dtl=0.01, dtr=0.05;
	var speakerAzim= #[-45, -140, 140, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, fbase, signal, startPos=0.0, rate=1;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion from radians.
	rate= ay.linlin(0,1, 2,0.1) * exprand(3,8);
	fbase= distance.linlin(0,1.41, 25,4000);
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
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
	signal= RLPF.ar(
		DelayL.ar(in, 30/344, distance.linlin(0.0,1.41, 30,75)/344), //~30kph
			distance.linlin(0.0,1.41, 10000,500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(8, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
}).send(s);

// ringz (VBAP4)
SynthDef(\sr_ringz, {
	arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1, velocity=10;
	var speakerAzim= #[-45, -140, 140, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal;
	var fbase, phase, cutoff;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion.
	fbase= distance.linexp(0,1.41, 10,40);
	phase= velocity*100;
	cutoff= distance.linexp(0,1.41, 200,2000);
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	in=
		Ringz.ar(SinOsc.ar(fbase, phase.lag(0.01), amp*0.01), cutoff, 0.01);
	5.do({in});
	in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= RLPF.ar(
		DelayL.ar(in, 30/344, distance.linlin(0.0,1.41, 30,75)/344), //~30kph
			distance.linlin(0.0,1.41, 10000,500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(8, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
}).send(s);
