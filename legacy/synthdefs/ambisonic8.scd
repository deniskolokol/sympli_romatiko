// Synth defs.
// mono recording synth
SynthDef(\recsyn_1, { arg inbus, bufnum= 0, amp= 1;
	DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).send(s);

// silence
SynthDef(\sr_silencio, {
	arg busnum=0;
	Out.ar(busnum, Silent.ar());
}).send(s);

// Ambisonic test
SynthDef(\sr_atest, {
	arg outbus= 0, mod= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 1, master=1,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var velocity, excitation, membrane, env, in, out, signal;
	velocity= 0.8;
	env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
	excitation= LPF.ar(WhiteNoise.ar(1), 7040, 1) * (0.1 + velocity); 
	membrane= ((LFTri.ar(330,0,1) * 0.25) + (LFTri.ar(185,0,1) * 0.25) 
		+ (excitation * 0.2) + (HPF.ar(excitation, 523, 1) * 0.2));
	in= membrane * (LFSaw.ar(1, 0, 0.5) * -1).max(0);
	signal= RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in!2, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
				), 110/344, distance/3.44
			), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp * master
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), amp);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(outbus, out);
	}
).send(s);

// probe (Ambisonic)
SynthDef(\sr_prob, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance= 1,
		dtl=0.01, dtr=0.05;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;	var in, out, fbase, signal, startPos=0.0, rate=1;
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
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
}).send(s);

// cmb (Ambisonic)
SynthDef(\sr_cmb, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att= 0.1, rel= 1, crva= -3, crvr=3, 
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8;
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
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// starfield (Ambisonic)
SynthDef(\sr_star, {
	arg bufnum=0, busnum=0, bufdur=1, ax=0, ay=0, panidx=0.5, amp=1, master=1, trigID=60, gate=1, frate=1, modf=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, xx= (1..5)*20, updateRate=30;
	dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
	dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
	q= dir[1].atan2(dir[0])+pi;
	a= frate.linlin(0,2, 2pi, 0);
	b= dir[1].hypot(dir[0])*400+200;
	c= modf.linlin(-440,440, 0, 50);
	in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
	in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(FreeVerb.ar(in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2), distance.linlin(0,1.41, 10000, 500), 0.5);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).send(s);

// "melodic" (Ambisonic)
SynthDef( \sr_melo, {
	arg bufnum=0, busnum=0, ax=0, ay=0, note=60, amp=1, master=1, gate=1, rate=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, freq, scale, signal;
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
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
	}
).send(s);

// noisy synth (Ambisonic)
SynthDef(\noisyhold, {
	arg busnum= 0, freq= 20, amp=1, master=0.1, att=0.5, rel= 0.1, gate=1,
		azimuth=0, elevation=1, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var in, out, env, signal, filtout;
	env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: 2);
	in= env * RLPF.ar(
		Impulse.ar(XLine.kr(freq, freq + 100, Rand(1, 2)), 0.0, 0.7.rand) + WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps, 0.1
		);
 	signal= [in, DelayN.ar(in, 0.04, 0.04)];
	4.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4, amp)});
	filtout= RLPF.ar(Mix.new(signal), distance.linlin(0, 1.41, 10000, 800), 0.5);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(filtout, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master*0.3);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// audio in (Ambisonic)
SynthDef(\audioin_1, {
	arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=1, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var in, out, dl, env;
	env= EnvGen.kr(Env.asr(att, master, rel, [crva, crvr]), gate: gate, doneAction: 2);
	dl= DelayL.ar(InFeedback.ar(inbus, 1), 110/344, distance/3.44);
//	in= RLPF.ar(InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 10000,800), 0.5) * env;
	in= RLPF.ar(
		FreeVerb.ar(
			InFeedback.ar(inbus, 1), distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
			), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.3
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(outbus, out)
	}
).send(s);

// granulating (Ambisonic)
SynthDef( \sr_regu, { // regular
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=0.1, master=1, gate=1, att=0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rate=1;
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
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "gusts of wind" (Ambisonic)
SynthDef( \sr_gust, {
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=1, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, d, zz, signal;
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
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "slicing" (Ambisonic)
SynthDef( \sr_slid, {
	arg bufnum= 0, busnum= 0, ax=0, ay=0, amp=1, master=1, gate=1, att= 0.1, rel= 1, crva= -3, crvr= 3,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1;
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
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "drone" (Ambisonic)
SynthDef( \sr_dron, {
	arg bufnum=0, busnum=0, ax=0, ay=0.5, amp=1, master=1, gate=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var trate, dur, pos, in, out, clk, signal, rate=1;
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
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// "saw" (Ambisonic)
SynthDef(\sr_lsaw, {
	arg outbus= 0, mod= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 1, master=1,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var mnote, scale, freq, env, in, out, signal;
	scale= FloatArray[0,8,14,20,25,34];
	mnote= DegreeToKey.kr(LocalBuf.newFrom(scale), elevation.linlin(-0.5pi, 0.5pi, 15, 0), 43, 1, 17).midicps;
	env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
	in= env * LFSaw.ar(
		freq: mnote + freqBase + mod.linlin(-1,1, -50, 0),
		mul: amp * master
		);
	signal= RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
				), 110/344, distance/3.44
			), distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp * master
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(in, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), amp);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar( outbus, out );
	}
).send(s);

// buffer player (Ambisonic)
SynthDef(\sr_play, {
	arg bufnum=0, busnum=0, amp=1, master=1, att=0.5, rel= 1, gate=1, done= 2,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var env, signal, in, out;
	env= EnvGen.kr(Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done);
	in= PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), doneAction:2) * env;
	signal= RLPF.ar(
		FreeVerb.ar(
			in,
			distance.linlin(0,1.41, 0.01,0.99), distance/3.44, 0.2
			),
		distance.linlin(0,1.41, 10000, 500), 0.5, mul: amp*0.3
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out);
	}
).send(s);

// looper (Ambisonic)
SynthDef(\sr_loop, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var in, out, signal, startPos=0.0, rate=1;
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
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), amp);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// looper with random trigger time
SynthDef(\sr_lopt, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=0, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1;
	var w, x, y, z, r, s, t, u, v; // !!
	var speakerAzim= [-0.25pi, -0.5pi, -0.75pi, -pi, 0.75pi, 0.5pi, 0.25pi, 0pi], speakerElev= 0, speakerDist= [8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7, 8.7], maxDist=8.7, scaleFlag=1;
	var rate=1, clk, in, out, signal, pos=0.0;
	clk= Dust.ar(BufDur.kr(bufnum).reciprocal);
	rate= BufRateScale.kr(bufnum) * LFNoise1.kr(12/clk, elevation.linlin(-0.5pi,0.5pi, 0.01, 0.2), 1);
	pos= BufFrames.ir(bufnum) + TRand.kr(0, BufDur.kr(bufnum), clk);
	in = PlayBuf.ar( 1, bufnum, rate, clk, pos )
		*EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in, distance.linlin(0,1.41, 0.01, 0.99), distance/3.44, 0.2
				), 110/344, distance/3.44
			), distance.linlin(0,1.41, 10000, 500).clip(500,10000), 0.5, mul: amp
		);
	#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(signal, azimuth, elevation, distance.linlin(0.0,1.41, 0.8,2.5), master);
	out= FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
		azimuth: speakerAzim, elevation: speakerElev, distance: speakerDist, maxDist:maxDist, scaleflag:scaleFlag);
	Out.ar(busnum, out)
}).send(s);

// synths for routine
SynthDef( \rec_start, { arg outbus= 0, freq= 60, dur=0.8, amp=0.05, master=1, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var signal, out;
	signal= SinOsc.ar( freq ) *
		EnvGen.kr(Env.new(
			[0, amp * master - 0.02, amp * master, amp * master, 0.001],
			[0.1, 0.01, dur-0.21, 0.1], 'welch'), doneAction: 2);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).send(s);

SynthDef( \ev_start, { arg outbus= 0, note= 60, dur=1, amp=0.3, master=1, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var in, out, freq, env, signal;
	freq= note.midicps;
	env= EnvGen.kr( Env.perc, levelScale: 0.3, timeScale: dur, doneAction: 2 );
	in= env * RLPF.ar( LFSaw.ar( freq )
			+ Impulse.ar( XLine.kr(freq, freq + 100,1.5), 0.0, 0.7.rand) 
			+ WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps,
		0.1,
		amp * master
	);
 	signal= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
	out= VBAP.ar(8, Mix.new(signal), speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).send(s);

SynthDef( \noisy, { arg outbus= 0, freq= 20, dur=1, amp=0.2, master=1, att=0.5, rel= 0.1, gate=1, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var in, out, env, signal, filtout, vol;
	vol= 55/distance.squared;
	env= EnvGen.kr( Env.linen(att, dur-att-rel, rel, amp * master, \sine), doneAction: 2 );
	in= env * RLPF.ar(
		Impulse.ar( XLine.kr(freq, freq + 100, dur-rel), 0.0, 0.7.rand) + WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps, 0.1
		);
 	signal= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4, amp) });
	filtout= RLPF.ar( Mix.new(signal), distance.linlin(44,110, 10000,800).clip(800,10000), 0.5, vol.max(0.1));
	out= VBAP.ar(8, filtout, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).send(s);

SynthDef(\sr_form, { arg outbus= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, master=1, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var env, in, out;
	env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
	in= env * RLPF.ar(
		in: LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -40, 40)),
		freq: LinLin.kr(mod, -1, 1, 80, 30).midicps,
		rq: 0.1,
		mul: ( amp * mod.linlin(-1,1, 0.01, 0.1) ).clip(0.01, 0.99) * master
		);
	out= VBAP.ar(8, in, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).send(s);
