// Synth defs.
// mono recording synth
SynthDef(\recsyn_1, { arg inbus, bufnum= 0, amp= 1;
	DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).send(s);

// probe (VBAP)
// WARNING! CALIBRATE CAREFULLY!
// USE AS EXAMPLE FOR THE REST OF SYNTHS!
SynthDef(\sr_prob, {
	arg bufnum=0, busnum=0, ax=0, ay=0, gate=1, amp=1, master=1, att=0.1, rel=1, crva= -3, crvr=3,
		azimuth=0, elevation=0, distance=1,
		dtl=0.01, dtr=0.05;
	var speakerAzim= #[-45, -90, -135, -180, 135, 90, 45, 0], speakerElev= 0, speakerBuff;	var in, out, fbase, signal, startPos=0.0, rate=1, spread=0;
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

//// probe
//SynthDef(\sr_prob, {arg bufnum=0, busnum=0, ax, ay, gate=0, amp=0, master=1, att=0.1, rel=1, crva= -3, crvr=3, azimuth=0, elevation=0, spread=0, distance, speakerBuffNum, dtl=0.01, dtr=0.05;
//	var in, out, fbase, signal, startPos=0.0, rate=1;
//	rate= ay.linlin(0,1, 2,0.1) * exprand(3,8);
//	fbase= distance.linlin(30,75, 25,4000);
//	in = LPZ2.ar(
//		LFPulse.ar( // populate the sin w/SinOsc
//			fbase, 2pi.rand, 0.1,
//			(Mix.ar(SinOsc.ar(rate * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand], 0.04)).max(0)
//			* Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand])).abs)
//			)
//		);		
//	2.do({ in= AllpassN.ar(in, 0.05, [dtl,dtr], 3.0.rand, 2); });
//	in= Mix.ar(in)*EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
//	signal= RLPF.ar(
//		DelayL.ar(
//			in, 30/344, distance/344), //~30kph
//			distance.linlin(30,75, 10000, 500).clip(500,10000), 0.5, mul: amp * master
//		);
//	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
//	Out.ar(busnum, out)
//}).send(s);

// cmb
SynthDef(\sr_cmb, {arg bufnum=0, busnum=0, ax, ay, gate=0, amp=0, master=1, att= 0.1, rel= 1, crva= -3, crvr=3, azimuth=0, elevation=0, spread=0, distance, speakerBuffNum;
	var rate=1, clk, in, out, signal, delayL, delayR, pos=0.0, pulse, mix, n=8;
	rate= ay.linlin(0,1, 2, 0.2);
	pulse= LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
	delayL= ay.linlin(0,1, 0.01, 0.05);
	delayR= ax.linlin(0,1, 0.01, 0.05);
	mix= Klank.ar(
		`[Array.fill(n, {exprand(1.0,20.0)}),
			nil,
			Array.fill(n, {0.2.rand})
			],
		Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
	).fold2(0.2).cubed * 12;
	mix= Mix.arFill(3, { CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand) });
	in= mix.distort * 0.5;
	6.do({in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 3)});
	in= Mix.ar(LeakDC.ar(in))*EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}).send(s);

// starfield
SynthDef(\sr_star, { arg bufnum=0, busnum=0, bufdur=1, ax=0.1, ay=0.1, panidx=0.5, amp=0.5, master=1, trigID=60, gate=0, frate=1, modf=1, att= 0.1, rel= 1, crva= -3, crvr=3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var in, out, signal, q= 0.1, a= 2pi, b= 400, c= 0, dir= [1, 0], freq=400, x= (1..5)*20, updateRate=30;
	dir= dir.put(1, ay.linlin(0, 1, -pi, pi));
	dir= dir.put(0, ax.linlin(0, 1, -pi, pi));
	q= dir[1].atan2(dir[0])+pi;
	a= frate.linlin(0,2, 2pi, 0);
	b= dir[1].hypot(dir[0])*400+200;
	c= modf.linlin(-440,440, 0, 50);
	in= SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq*x, 0, a), b), x, q), amp * 0.1); // it's a very loud synth
	in= Limiter.ar(Mix(in)) * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}, #[0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]).send(s);

SynthDef( \sr_melo, { // "melodic"
	arg bufnum= 0, busnum= 0, ax, ay, note=60, amp=0.1, master=1, gate= 0, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum=b.bufnum;
	var trate, dur, pos, in, out, clk, d, z, freq, scale, signal;
	scale = FloatArray[0, 3, 10, 12, 19];
	freq= DegreeToKey.kr(LocalBuf.newFrom(scale), ay.linlin(0, 1, 0, 15), 12, 1, 17).midicps;
//	freq= ay.linlin(0,1, 125, 4000); // note.midicps;
	in= RLPF.ar(
		LFSaw.ar(freq)
		+ Impulse.ar( XLine.kr(freq, freq + 100, 1.5), 0.0, 0.7.rand) 
		+ WhiteNoise.ar(0.8.rand, mul:ay.linlin(0,1,1,0.1)),
		LFNoise1.kr(1, 38, 115).midicps,
		0.1,
		amp * 0.1 * master
		);
 	in= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
	in= Mix.ar(LeakDC.ar(in))*EnvGen.kr(Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction:2);
	signal= RLPF.ar(
		FreeVerb.ar(
			in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(busnum, out)
	}
).send(s);

// looper
SynthDef(\sr_loop, {arg bufnum=0, busnum=0, ax, ay, gate= 0, amp= 0, master=1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var in, out, signal, startPos=0.0, rate=1;
	rate= ay.linlin(0,1, 0.1, 2); // ay.linlin(0,1, -1.5, 2);
	in = PlayBuf.ar(
		1,
		bufnum,
		rate*BufRateScale.kr(bufnum),
		Impulse.ar(BufDur.kr(bufnum).reciprocal),
		BufFrames.ir(bufnum)*startPos
		)
		*EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
				), 110/344, distance/344
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}).load(s);

// looper with random trigger time
SynthDef(\sr_lopt, {arg bufnum=0, busnum=0, ax, ay, gate= 0, amp= 0, master=1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var rate=1, clk, in, out, signal, pos=0.0;
	//rate= ay.linlin(0,1, 0.1, 2);
	clk= Dust.ar(BufDur.kr(bufnum).reciprocal);
	rate= BufRateScale.kr(bufnum) * LFNoise1.kr(12/clk, ay.linlin(0,1, 0.01, 0.2), 1);
	pos= BufFrames.ir(bufnum) + TRand.kr(0, BufDur.kr(bufnum), clk);
	in = PlayBuf.ar( 1, bufnum, rate, clk, pos )
		*EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	signal= RLPF.ar(
		DelayL.ar(
			FreeVerb.ar(
				in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
				), 110/344, distance/344
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}).load(s);

// granulating
SynthDef( \sr_regu, { // regular
	arg bufnum= 0, busnum= 0, ax, ay, amp, master=1, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var trate, dur, pos, in, out, clk, signal, rate= 1;
	rate= ay.linlin(0,1, 0.2, 2);
	trate= ay.linlin(0,1, 0.2,100);
	dur= 4 / trate;
	clk= Dust.kr(trate);
	pos = Integrator.kr(BrownNoise.kr(ax));
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
		DelayL.ar(
			Mix.new(
				FreeVerb.ar(
					in, distance.linlin(30,75, 0.99, 0.01), distance/344, 0.2
					)
				), 30/344, distance/344), //~30kph
			distance.linlin(30,75, 10000, 500).clip(500,10000), 0.5, mul: amp * master
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).send(s);

SynthDef( \sr_dron, { // drone
	arg bufnum= 0, busnum= 0, ax, ay=0.5, amp=0.1, master=1, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var trate, dur, pos, in, out, clk, signal, rate= 1;
	rate= ay.linlin(0,1, 0.2, 2);
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
		amp: amp * master
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
				)
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).send(s);

SynthDef( \sr_gust, { // "gusts of wind"
	arg bufnum= 0, busnum= 0, ax, ay, amp, master=1, gate= 0, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var trate, dur, pos, in, out, clk, d, z, signal;
	pos= round((ax*0.19)+0.1, 0.01);
	trate= ay.linlin(0,1, 0.1,20); //(ay*49.0)+1; //arg Y: trate 1..50
	clk= Impulse.ar(trate);
	d= { Dwhite(0.1, 0.2, 1) };
	z= { Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))]) };
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: Dseq([1, 1, z.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf)*pos+1,
		centerPos: Dseq(z.dup(8), inf) / pos,
		dur: Dseq([1, d.value, 1, z.value, 0.5, 0.5, 0.1, z.value]*2, inf)/trate,
		amp: Dseq([1, 0, z.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf) * amp * ay.linlin(0,1, 0.3,1.1).fold(0,1) * master
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
				)
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).send(s);

SynthDef( \sr_slid, { // "slicing"
	arg bufnum= 0, busnum= 0, ax, ay, amp, master=1, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var trate, dur, pos, in, out, clk, signal, rateratio, rate= 1;
	rate= ay.linlin(0,1, 0.2, 2);
	trate= ay.linlin(0,1, 1,100); //arg Y: trate 0.1..50
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
		amp: amp * rateratio.linlin(0,4, 1,0.15) * master
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
				)
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5
		);
	out= VBAP.ar(8, signal, speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).send(s);

// audio in
SynthDef(\audioin_1, {arg rate=1, amp= 1, master=1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var in, out, env, vol;
	vol= 55/distance.squared;
	env= EnvGen.kr( Env.asr(att, amp*master, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	//dl= DelayL.ar( InFeedback.ar(inbus, 1), 110/344, distance/344);
	in= RLPF.ar( InFeedback.ar(inbus, 1), distance.linlin(44,110, 10000,800).clip(800,10000), 0.5, vol.max(0.3)) * env;
	out= VBAP.ar(8, in, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(outbus, out)
	}
).send(s);

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

SynthDef( \noisyhold, { arg outbus= 0, freq= 20, amp=0.2, master=1, att=0.5, rel= 0.1, gate=1, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var in, out, env, signal, filtout, vol;
	vol= 55/distance.squared;
	env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: 2 );
	in= env * RLPF.ar(
		Impulse.ar( XLine.kr(freq, freq + 100, Rand(1, 2)), 0.0, 0.7.rand) + WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps, 0.1
		);
 	signal= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4, amp * 0.15 * master) });
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

SynthDef(\sr_lsaw, { arg outbus= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, master=1, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var env, in, out;
	env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
	in= env * LFSaw.ar(
		freq: mnote + freqBase + mod.linlin(-1,1, -50, 0),
		mul: ( amp * mod.linlin(-1,1, 0.01, 0.25) ).clip(0.01, 0.99) * master
		);
	out= VBAP.ar(8, in, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).send(s);	
