// ================================================
//
// 					   Ambisonic 4
//
// ================================================

// == GRANULAR SYNTHS
// "regular" granulating (Ambisonic 4)
SynthDef( \sr_regu_ambisonic4, { // regular
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
	trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
	dur= 4 / trate;
	clk= Dust.kr(trate);
	pos = Integrator.kr(BrownNoise.kr(azimuth));
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rate,
		centerPos: pos,
		dur: dur,
		amp: amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.clip(0.01, 0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000, 500), 0.5
		) 
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "drone" (Ambisonic 4)
SynthDef( \sr_dron_ambisonic4, {
	arg bufnum=0, busnum=0, ax=0, ay=0.5, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
	trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
	dur= 12 / trate;
	clk= Impulse.kr(trate);
	pos= ax*BufDur.kr(bufnum);	
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rate,
		centerPos: pos + TRand.kr(0, 0.01, clk),
		dur: dur,
		amp: amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000,500), 0.5
		)
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "gusts of wind" (Ambisonic 4)
SynthDef( \sr_gust_ambisonic4, {
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=1, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var trate, dur, pos, in, out, clk, d, zz, signal, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	pos= round((distance*0.19)+0.1, 0.01);
	trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
	clk= Impulse.ar(trate);
	d= {Dwhite(0.1, 0.2, 1)};
	zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
		centerPos: Dseq(zz.dup(8), inf) / pos,
		dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
		amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.clip(0.01, 0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000, 500), 0.5
		) 
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "slicing" (Ambisonic 4)
SynthDef( \sr_slid_ambisonic4, {
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
	trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
	dur= 8 / trate;
	clk= Dust.kr(trate);
	pos= ax * BufDur.kr(bufnum);
	rateratio= (2 ** WhiteNoise.kr(2)) * rate;
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rateratio,
		centerPos: pos,
		dur: dur,
		amp: amp * rateratio.linlin(0,4, 1,0.5)
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
				distance.linlin(0,1.41, 10000,500), 0.5)
				* EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// looper (Ambisonic 4)
SynthDef(\sr_loop_ambisonic4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var in, out, signal, startPos=0.0, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= ay.linlin(-0.5pi,0.5pi, 0.1, 1.9);
	in = PlayBuf.ar(
		1,
		bufnum,
		rate*BufRateScale.kr(bufnum),
		Impulse.ar(BufDur.kr(bufnum).reciprocal),
		BufFrames.ir(bufnum)*startPos
		)
		* EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
				), 110/344, distance/3.44
			), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, amp);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// == ELECTRONIC SYNTHS
// doors (Ambisonic 4)
SynthDef(\sr_doors_ambisonic4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3, 
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var freq, in, out, signal, grav, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	freq= 1/(2..5);
	grav= 7-(1/freq);
	in= GVerb.ar(
			Ball.ar(
				LPF.ar(Impulse.ar(freq), 500),
				grav, 1e-5,
				LFNoise2.kr(freq/5,2e-4,12e-4))/2,
			5, 0.5, 0.9);
	in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= PitchShift.ar(in, 0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// probe (Ambisonic 4)
SynthDef(\sr_prob_ambisonic4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1, velocity=10;
	var	dtl=0.01, dtr=0.05;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var in, out, fbase, scale, signal, startPos=0.0, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= velocity.linlin(1,30, 0.5, 3) * exprand(3,8);
	scale = FloatArray[0, 3, 10, 12, 19];
	fbase= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi,0.5pi, 15,0), 24, 1, 17).midicps;
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

// cmb (Ambisonic 4)
SynthDef(\sr_cmb_ambisonic4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3, 
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
	pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
	delayL= elevation.linlin(-0.5pi, 0.5pi, 0.01, 0.05);
	delayR= ax.linlin(0,1, 0.01, 0.05);
	mix= Klank.ar(
		`[Array.fill(n, {exprand(1.0,20.0)}),
			nil,
			Array.fill(n, {0.2.rand})
			],
		Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
	).fold2(0.2).cubed * 12;
	mix= Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
	in= mix.distort * 0.5;
	6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
	in= Mix.ar(LeakDC.ar(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
			), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.3
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// starfield (Ambisonic 4)
SynthDef(\sr_star_ambisonic4, {
	arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, gate=1, frate=1, modf=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
	dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
	q= dir[1].atan2(dir[0])+pi;
	a= frate.linlin(0,2, 2pi, 0);
	b= dir[1].hypot(dir[0])*400+200;
	c= modf.linlin(-440,440, 0, 50);
	in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
	in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(FreeVerb.ar(in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2), distance.linlin(0,1.41, 10000, 500), 0.5);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).send(s);

// "melodic" (Ambisonic 4)
SynthDef( \sr_melo_ambisonic4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
	var trate, dur, pos, in, out, clk, freq, scale, signal, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	scale = FloatArray[0, 3, 10, 12, 19];
	freq= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 17).midicps;
	in= RLPF.ar(
		LFSaw.ar(freq)
		+ Impulse.ar( XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand) 
		+ WhiteNoise.ar(0.8.rand, mul:ay.linlin(0,1,1,0.1)),
		LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp*0.02
		);
 	in= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
	in= Mix.ar(LeakDC.ar(in))*EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
			), distance.linlin(0,1.41, 10000, 500), 0.5
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
	}
).send(s);

// ringz (Ambisonic 4)
SynthDef(\sr_ringz_ambisonic4, {
	arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.75pi, 0.75pi, 0.25pi], speakerElev= 0, speakerDist= [3, 3, 3, 3], maxDist=3, scaleFlag=1;
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







// ================================================
//
// 					   Ambisonic 8
//
// ================================================

// == GRANULAR SYNTHS
// "regular" granulating (Ambisonic 8)
SynthDef( \sr_regu_ambisonic8, { // regular
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
	trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
	dur= 4 / trate;
	clk= Dust.kr(trate);
	pos = Integrator.kr(BrownNoise.kr(azimuth));
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rate,
		centerPos: pos,
		dur: dur,
		amp: amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.clip(0.01, 0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000, 500), 0.5
		) 
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "drone" (Ambisonic 8)
SynthDef( \sr_dron_ambisonic8, {
	arg bufnum=0, busnum=0, ax=0, ay=0.5, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
	trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
	dur= 12 / trate;
	clk= Impulse.kr(trate);
	pos= ax*BufDur.kr(bufnum);	
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rate,
		centerPos: pos + TRand.kr(0, 0.01, clk),
		dur: dur,
		amp: amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000,500), 0.5
		)
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "gusts of wind" (Ambisonic 8)
SynthDef( \sr_gust_ambisonic8, {
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=1, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, d, zz, signal, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	pos= round((distance*0.19)+0.1, 0.01);
	trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
	clk= Impulse.ar(trate);
	d= {Dwhite(0.1, 0.2, 1)};
	zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
		centerPos: Dseq(zz.dup(8), inf) / pos,
		dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
		amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.clip(0.01, 0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000, 500), 0.5
		) 
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "slicing" (Ambisonic 8)
SynthDef( \sr_slid_ambisonic8, {
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
	trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
	dur= 8 / trate;
	clk= Dust.kr(trate);
	pos= ax * BufDur.kr(bufnum);
	rateratio= (2 ** WhiteNoise.kr(2)) * rate;
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rateratio,
		centerPos: pos,
		dur: dur,
		amp: amp * rateratio.linlin(0,4, 1,0.5)
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
				distance.linlin(0,1.41, 10000,500), 0.5)
				* EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// looper (Ambisonic 8)
SynthDef(\sr_loop_ambisonic8, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var in, out, signal, startPos=0.0, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= ay.linlin(-0.5pi,0.5pi, 0.1, 1.9);
	in = PlayBuf.ar(
		1,
		bufnum,
		rate*BufRateScale.kr(bufnum),
		Impulse.ar(BufDur.kr(bufnum).reciprocal),
		BufFrames.ir(bufnum)*startPos
		)
		* EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
				), 110/344, distance/3.44
			), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, amp);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// == ELECTRONIC SYNTHS
// doors (Ambisonic 8)
SynthDef(\sr_doors_ambisonic8, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3, 
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var freq, in, out, signal, grav, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	freq= 1/(2..5);
	grav= 7-(1/freq);
	in= GVerb.ar(
			Ball.ar(
				LPF.ar(Impulse.ar(freq), 500),
				grav, 1e-5,
				LFNoise2.kr(freq/5,2e-4,12e-4))/2,
			5, 0.5, 0.9);
	in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= PitchShift.ar(in, 0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// probe (Ambisonic 8)
SynthDef(\sr_prob_ambisonic8, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1, velocity=10;
	var	dtl=0.01, dtr=0.05;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var in, out, fbase, scale, signal, startPos=0.0, rate=1, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= velocity.linlin(1,30, 0.5, 3) * exprand(3,8);
	scale = FloatArray[0, 3, 10, 12, 19];
	fbase= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi,0.5pi, 15,0), 24, 1, 17).midicps;
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

// cmb (Ambisonic 8)
SynthDef(\sr_cmb_ambisonic8, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3, 
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
	pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
	delayL= elevation.linlin(-0.5pi, 0.5pi, 0.01, 0.05);
	delayR= ax.linlin(0,1, 0.01, 0.05);
	mix= Klank.ar(
		`[Array.fill(n, {exprand(1.0,20.0)}),
			nil,
			Array.fill(n, {0.2.rand})
			],
		Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
	).fold2(0.2).cubed * 12;
	mix= Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
	in= mix.distort * 0.5;
	6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
	in= Mix.ar(LeakDC.ar(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
			), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.3
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// starfield (Ambisonic 8)
SynthDef(\sr_star_ambisonic8, {
	arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, gate=1, frate=1, modf=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
	dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
	q= dir[1].atan2(dir[0])+pi;
	a= frate.linlin(0,2, 2pi, 0);
	b= dir[1].hypot(dir[0])*400+200;
	c= modf.linlin(-440,440, 0, 50);
	in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
	in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(FreeVerb.ar(in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2), distance.linlin(0,1.41, 10000, 500), 0.5);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).send(s);

// "melodic" (Ambisonic 8)
SynthDef( \sr_melo_ambisonic8, {
	arg bufnum=0, busnum=0, ax=0, ay=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, freq, scale, signal, dist;
	dist= distance.linlin(0.0,1.41, 0.5, 3);
	scale = FloatArray[0, 3, 10, 12, 19];
	freq= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 17).midicps;
	in= RLPF.ar(
		LFSaw.ar(freq)
		+ Impulse.ar( XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand) 
		+ WhiteNoise.ar(0.8.rand, mul:ay.linlin(0,1,1,0.1)),
		LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp*0.02
		);
 	in= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
	in= Mix.ar(LeakDC.ar(in))*EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
			), distance.linlin(0,1.41, 10000, 500), 0.5
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, dist, master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
	}
).send(s);

// ringz (Ambisonic 8)
SynthDef(\sr_ringz_ambisonic8, {
	arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
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









// ================================================
//
// 						VBAP 4
//
// ================================================

// == GRANULAR SYNTHS
// "regular" granulating (VBAP 4)
SynthDef( \sr_regu_vbap4, { // regular
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rate=1;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
	trate= elevation.linlin(-0.5pi,0.5pi, 100, 0.2);
	dur= 4 / trate;
	clk= Dust.kr(trate);
	pos = Integrator.kr(BrownNoise.kr(azimuth));
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rate,
		centerPos: pos,
		dur: dur,
		amp: amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.clip(0.01, 0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000, 500), 0.5
		) 
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
	}
).send(s);

// "drone" (VBAP 4)
SynthDef( \sr_dron_vbap4, {
	arg bufnum=0, busnum=0, ax=0, ay=0.5, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rate=1;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	rate= elevation.linlin(-0.5pi,0.5pi, 0.2,2);
	trate= SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
	dur= 12 / trate;
	clk= Impulse.kr(trate);
	pos= ax*BufDur.kr(bufnum);	
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rate,
		centerPos: pos + TRand.kr(0, 0.01, clk),
		dur: dur,
		amp: amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000,500), 0.5
		)
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
	}
).send(s);

// "gusts of wind" (VBAP 4)
SynthDef( \sr_gust_vbap4, {
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=1, distance=1, velocity=10;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, d, zz, signal;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	pos= round((distance*0.19)+0.1, 0.01);
	trate= elevation.linlin(-0.5pi, 0.5pi, 0.1,20);
	clk= Impulse.ar(trate);
	d= {Dwhite(0.1, 0.2, 1)};
	zz= {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
		centerPos: Dseq(zz.dup(8), inf) / pos,
		dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value]*2, inf)/trate,
		amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.clip(0.01, 0.99), distance/3.44, 0.2
				)
			), distance.linlin(0,1.41, 10000, 500), 0.5
		) 
		* EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
	}
).send(s);

// "slicing" (VBAP 4)
SynthDef( \sr_slid_vbap4, {
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	rate= elevation.linlin(-0.5pi, 0.5pi, 0.2,2);
	trate= elevation.linlin(-0.5pi, 0.5pi, 1,100);
	dur= 8 / trate;
	clk= Dust.kr(trate);
	pos= ax * BufDur.kr(bufnum);
	rateratio= (2 ** WhiteNoise.kr(2)) * rate;
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rateratio,
		centerPos: pos,
		dur: dur,
		amp: amp * rateratio.linlin(0,4, 1,0.5)
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2)),
				distance.linlin(0,1.41, 10000,500), 0.5)
				* EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
	}
).send(s);

// looper (VBAP 4)
SynthDef(\sr_loop_vbap4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal, startPos=0.0, rate=1;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	rate= ay.linlin(-0.5pi,0.5pi, 0.1, 1.9);
	in = PlayBuf.ar(
		1,
		bufnum,
		rate*BufRateScale.kr(bufnum),
		Impulse.ar(BufDur.kr(bufnum).reciprocal),
		BufFrames.ir(bufnum)*startPos
		)
		* EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
				), 110/344, distance/3.44
			), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
}).send(s);

// == ELECTRONIC SYNTHS
// doors (VBAP 4)
SynthDef(\sr_doors_vbap4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3, 
		azimuth=0, elevation=0, distance=1, velocity=10;
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var freq, in, out, signal, grav;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	freq= 1/(2..5);
	grav= 7-(1/freq);
	in= GVerb.ar(
			Ball.ar(
				LPF.ar(Impulse.ar(freq), 500),
				grav, 1e-5,
				LFNoise2.kr(freq/5,2e-4,12e-4))/2,
			5, 0.5, 0.9);
	in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= PitchShift.ar(
		RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
				), 110/344, distance/3.44
			), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		),
		0.02, 0.5, 0, 0.0001).distort(0.25)[0]; // Taking a mono channel after the mix.
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}).send(s);

// probe (VBAP4)
SynthDef(\sr_prob_vbap4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var dtl=0.01, dtr=0.05;
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, scale, fbase, signal, startPos=0.0, rate=1;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	rate= velocity.linlin(1,30, 0.5, 3) * exprand(3,8);
	scale = FloatArray[0, 3, 10, 12, 19];
	fbase= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi,0.5pi, 15,0), 24, 1, 17).midicps;
	//Conversion.
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
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
}).send(s);

// cmb (VBAP 4)
SynthDef(\sr_cmb_vbap4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3, 
		azimuth=0, elevation=0, distance=1, velocity=10;
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	rate= elevation.linlin(-0.5pi,0.5pi, 2, 0.2);
	pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
	delayL= elevation.linlin(-0.5pi, 0.5pi, 0.01, 0.05);
	delayR= ax.linlin(0,1, 0.01, 0.05);
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	mix= Klank.ar(
		`[Array.fill(n, {exprand(1.0,20.0)}),
			nil,
			Array.fill(n, {0.2.rand})
			],
		Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
	).fold2(0.2).cubed * 12;
	mix= Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
	in= mix.distort * 0.5;
	6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
	in= Mix.ar(LeakDC.ar(in)) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
			), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.3
		);
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}).send(s);

// starfield (VBAP 4)
SynthDef(\sr_star_vbap4, {
	arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, gate=1, frate=1, modf=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var speakerAzim= #[-45, -135, 135, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
	dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
	q= dir[1].atan2(dir[0])+pi;
	a= frate.linlin(0,2, 2pi, 0);
	b= dir[1].hypot(dir[0])*400+200;
	c= modf.linlin(-440,440, 0, 50);
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
	in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(FreeVerb.ar(in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2), distance.linlin(0,1.41, 10000, 500), 0.5);
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).send(s);

// "melodic" (VBAP 4)
SynthDef( \sr_melo_vbap4, {
	arg bufnum=0, busnum=0, ax=0, ay=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1, velocity=10;
	var speakerAzim= #[-45, -140, 140, 45], speakerElev= 0, speakerBuff, spread=0;	var trate, dur, pos, in, out, clk, freq, scale, signal;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	scale = FloatArray[0, 3, 10, 12, 19];
	freq= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 12, 1, 17).midicps;
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	in= RLPF.ar(
		LFSaw.ar(freq)
		+ Impulse.ar( XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand) 
		+ WhiteNoise.ar(0.8.rand, mul:ay.linlin(0,1,1,0.1)),
		LFNoise1.kr(1, 38, 115).midicps, 0.1, mul:amp*0.02
		);
 	in= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
	in= Mix.ar(LeakDC.ar(in))*EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
			), distance.linlin(0,1.41, 10000, 500), 0.5
		);
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out)
	}
).send(s);

// ringz (VBAP4)
SynthDef(\sr_ringz_vbap4, {
	arg bufnum=0, busnum=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1, velocity=10;
	var speakerAzim= #[-45, -140, 140, 45], speakerElev= 0, speakerBuff, spread=0;	var in, out, signal;
	var fbase, phase, cutoff;
	//Speakers config.
	speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
	//Conversion.
	azimuth= azimuth.linlin(-pi,pi, -180,180);
	elevation= elevation.linlin(-0.5pi,0.5pi, -90,90);
	spread= distance.linlin(0,1.41, 50,0); // The closer the signal, the more speakers involved.
	fbase= distance.linexp(0,1.41, 10,40);
	phase= velocity*100;
	cutoff= distance.linexp(0,1.41, 200,2000);
	in=
		Ringz.ar(SinOsc.ar(fbase, phase.lag(0.01), amp*0.01), cutoff, 0.01);
	5.do({in});
	in= Mix.ar(in) * EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2);
	signal= RLPF.ar(
		DelayL.ar(in, 30/344, distance.linlin(0.0,1.41, 30,75)/344), //~30kph
			distance.linlin(0.0,1.41, 10000,500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(4, signal, speakerBuff.bufnum, azimuth, elevation, spread);
	Out.ar(busnum, out);
}).send(s);
