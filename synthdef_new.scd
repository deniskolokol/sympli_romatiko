//    arg:
// inbus => in
// outbus => out
// att => attack
// rel => release
// momentum => momentum
// offset => \ (shold receive a note!)
//
//    var:
// in => signal (no diff between in and signal anymore)
// out => output
//
(
var outFuncName, outCodeFunc;

// default speaker placement configurations
var spatialConf = (
	"a2": (
		azim: #[-0.25pi, -0.75pi],
		elev: #[0, 0],
		dist: #[2, 2],
		maxDist: 2
	),
	"a4": (
		azim: #[-0.25pi, -0.75pi, 0.75pi, 0.25pi],
		elev: #[0, 0, 0, 0],
		dist: #[2, 2, 2, 2],
		maxDist: 2
	),
	"a6": (
		azim: #[-0.25pi, -0.5pi, -0.75pi, 0.75pi, 0.5pi, 0.25pi],
		elev: #[0, 0, 0, 0, 0, 0],
		dist: #[2, 2, 2, 2, 2, 2],
		maxDist: 2
	),
	"a8": (
		azim: #[-0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0],
		elev: #[0, 0, 0, 0, 0, 0, 0, 0],
		dist: #[2, 2, 2, 2, 2, 2, 2, 2],
		maxDist: 2
	),
	"a10": (
		azim: #[-0.15, -0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0.15pi, 0],
		elev: #[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		dist: #[2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
		maxDist: 2
	),
);

var makeSynthDefPerc = { |name, outCodeFunc|
	// XXX - former \sr__e__perc
	SynthDef("kick__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi;
		var lag=0.25;
		var trig = momentum > 0.2;
		var timer = Timer.kr(trig);
		var att = momentum.linexp(0.0, 1.0, 0.0, 0.2);
		var rel = 1 - momentum;
		var gt = (timer > lag) * trig;
		var signal = Pulse.ar(freq,
			width: PinkNoise.kr((ExpRand(0.009, momentum*0.9)*amp).min(0.45), 0.45),
			mul: FSinOsc.ar(LinRand(9, 99*freq).round(9), 0, LinRand(0.09, 0.999-momentum), amp));
		signal = RLPF.ar(signal,
			freq: (freq*9*momentum).max(freq*4.5),
			rq: LinRand(0.09, 4.5)
		).softclip;
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gt, att, rel, depth, elevClip
		);
	}).add;
};

var makeSynthDefADSR = { |name, outCodeFunc|
	// XXX - former \sr__e__silent
	SynthDef("silent__" ++ name, {
		arg out=0, trigID=80,
		    azimuth= -0.5pi, distance=0.1, elevation=0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    depth=5, elevClip=0.01pi;
		var signal = Silent.ar();
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;


	SynthDef("humm__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi,
		    offset=36;
		var note = (DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 15), 12, 1, offset)
			+ LFNoise1.kr([3, 3], 0.04)).midicps;    // add some low freq stereo detuning
		var raw = Mix.ar(
			LFSaw.ar((1..5) * note, abs(momentum * 2), momentum)
			+ Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300))
		) * amp * 0.1;
		var signal = RLPF.ar(raw, LinLin.kr(momentum, 0, 1, 80, 30).midicps, momentum);
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;


	SynthDef("entro__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi;
		var signal;
		var rq = distance.linlin(0, 2.sqrt, 0.2, 1);
		// XXX - old (allowing for more)
		// var shift = ((momentum ** 0.2 * 30) ** 3).lag(0.5); // boost momentum
		var shift = ((momentum ** 0.3 * 50) ** 2).lag(0.5); // boost momentum
		var trig = momentum > 0.2;
		var timer = Timer.kr(trig);
		var raw = TChoose.ar((timer > 0.25) * trig, [
			RLPF.ar(Normalizer.ar(LorenzL.ar(az.linlin(0, 1, 10, SampleRate.ir),
				LFNoise0.kr(1, 2, 10), r: LFNoise0.kr(1, 20, 38), b: LFSaw.kr(0.2).exp.cubed), 1),
			LFPulse.kr(LFSaw.ar(0.2).exp.cubed, 0.5, 2500, 3500),
			momentum.scurve),
			Saw.ar((1..15) * LFNoise0.kr(5, 10, 50) + SinOsc.ar((6..2) * 0.5))
		]);
		signal = RLPF.ar(RLPF.ar(Mix.ar(raw)*momentum*amp*0.1, shift, rq), shift, rq);
		// signal = BPeakEQ.ar(
		// 	RLPF.ar(
		// 		Mix.ar(raw), shift, rq
		// 	),
		// 	freq: az.linlin(0, 1, 36, 432),
		// 	rq: az.linlin(0, 1, 0.1, 10),
		// 	db: 6
		// );
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;


	// XXX:
	// - add less obvious elevation based control (az)
	// - more effective compander, possibly multiband! don't allow it to burst!
	SynthDef("neural__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi;
		var signal;
		// Conversion.
		var mul = momentum.linlin(0, 1, 1850, 2350);
		var add = distance.linlin(0, 1, 2250, 5800);
		var trig = momentum > 0.33; // high momentum causes sharp switch
		var timer = Timer.kr(trig);
		var baseFreq = TRand.kr(trig:Delay2.kr(Dust.kr(momentum.linexp(0.01, 1, 0.5, 10))));
		var rq = momentum.linlin(0, 1, 0.8, 0.2);
		var cutoff = TWChoose.kr((timer > 0.25) * trig,
			[
				LFNoise0.ar(baseFreq, mul, add),
				LFNoise1.ar(baseFreq, mul, add),
				LFNoise2.ar(baseFreq).clip2 * mul + add // quadratic interpolation can push beyond [-1..1]
			],
			[0.1, 0.3, 0.6]
		);
		// Synthesis.
		var raw = TermanWang.ar(
			2.0 + SinOsc.ar(az.linexp(0.01, 1, 10, 10000), 0, az.linexp(0.01, 1, 0.1, 100.0)),
			Impulse.kr(distance.linexp(0.01, 1, 1, 10000)),
			0.01, 0.01, 1.0, 1.0, 1.0,
			ax.linlin(0, 1, 0.4, 1.2), ay.linlin(0, 1, 2.0, 4.0)
		) * 0.2;
		raw = RLPF.ar(raw, cutoff, rq);
		signal = Compander.ar(raw, raw, 0.1, slopeBelow: 1, slopeAbove: 0.5,
			clampTime: 0.01, relaxTime: 0.01, mul: amp);
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;


	// XXX - former \sr__e__radio
	SynthDef("komar__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi,
		    offset=36; // XXX - let modulator control offset
		var baseFreq; // XXX - remove baseFreq, let modulator control \freq
		var trig, timer, cutoff, raw, signal;
		// Conversion.
		baseFreq = (az * (36..72)).midicps;
		trig = momentum > 0.3;
		timer = Timer.kr(trig);
		cutoff = TChoose.ar((timer > 0.25) * trig, [
			LFDClipNoise.ar(az, 450, 650),
			LFNoise2.ar(TRand.kr(trig: Delay2.kr(Dust.kr(0.2))), 450, 550)
		]);
		// Synthesis.
		raw = (
			LFSaw.ar(baseFreq, mul:momentum)
			+ Impulse.ar(SinOsc.ar(cutoff).exprange(48, 10000), mul:momentum)
			+ Formlet.ar(
				Impulse.ar(baseFreq + SinOsc.ar(baseFreq * 0.02).exprange(0.3, cutoff / 3.67)),
				(1..5)
				* SinOsc.ar(momentum).exprange(20, 2000)
				* SinOsc.ar(SinOsc.ar(momentum, 0, 0.1), 0, 0.1, 1), 0.001, 0.0015,
				mul: momentum.scurve
			)
		) * amp;
		signal = Mix.ar(raw) * 0.06;
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;


	// XXX - former \sr__e__noisy
	SynthDef("wind__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi;
		var raw, signal;
		var fbase, shift;
		// Conversion.
		fbase = distance.linexp(0, 1, 10, 40);
		shift = ((momentum * 30) ** 3).lag(0.01);
		// Synthesis.
		raw = Formlet.ar(
			WhiteNoise.ar(SinOsc.ar(fbase, shift, 0.5, 1)).min(1) + SinOsc.ar(fbase, shift),
			LFNoise1.ar(TRand.kr(trig:Delay2.kr(Dust.kr(0.5))), 2450, 2550), 0.01, 0.1
		).softclip;
		raw = [raw, DelayN.ar(raw, 0.04, 0.4)];
		4.do({raw = AllpassN.ar(raw, 0.5, [0.5.rand, 0.5.rand], 4, amp)});
		signal = Mix.ar(raw) * 0.02;
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;


	// The "lowe"st.
	// XXX - former \sr__e__lowe
	// XXX - in orig synth \freq was a var with default val 400
	SynthDef("lowe__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi;
		var signal;
		var q=0.1, a=2pi, b=400, c=0, dir=[1, 0], frate=1, xx=(1..5)*20;
		// Conversion.
		dir = dir.put(1, az.linlin(0, 1, -pi, pi));
		dir = dir.put(0, ax.linlin(0, 1, -pi, pi));
		q = dir[1].atan2(dir[0]) + pi;
		a = frate.linlin(0,2, 2pi, 0);
		b = dir[1].hypot(dir[0]) * 400 + 200;
		c = momentum.linlin(0, 1, 50, 150);
		// Synthesis.
		signal = SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
		signal = RLPF.ar(Limiter.ar(Mix.ar(signal)), distance.linlin(0, 2.sqrt, 500, 10000), 0.5);
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;

	SynthDef("buzz__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi;
		var signal;
		// Synthesis.
		signal = Mix.new([
			LFSaw.ar((1..5) * freq, abs(momentum * 2)),
			Impulse.ar((0..4) + SinOsc.ar((4..8) * freq).exprange(0.3, 300))
		]);
		signal = RLPF.ar(signal, LinLin.kr(momentum, 0, 1, 80, 30).midicps, momentum, amp);
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;

	// "POLE - POLyphonic Electronic synth"
	// XXX - former \sr__e__growl
	SynthDef("pole__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0, dur=0.1,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.1,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi,
		    offset=6; // XXX - let modulator control offset
		var mix, room, signal, output;
		var cutoff, rq, rate, pitches, trig, mul, add, detune, lag,
		    tones=10, noOfSynths=20, note;
		// Conversion.
		rq = momentum.lincurve(0, 1, 0.6, 0.01, 4);
		mul = momentum.lincurve(0, 1, 400, 2000, 4);
		add = momentum.lincurve(0, 1, 600, 10000, 4);
		cutoff = (LFNoise2.ar(momentum).clip2 * mul + add);
		rate = momentum.linlin(0, 1, 2, 4).round;
		trig = Impulse.kr(0) + Dust2.kr(rate);
		lag = momentum.lincurve(0, 1, 0.5, 0.05, -4);
		detune = momentum.lincurve(0, 1, 0.1, 0.5, 4);
		// XXX - del;ete this in new version
		// guide params for fine control of pitch and threshold
		note = DegreeToKey.kr(bufnum, gz.linlin(0, 1, 0, 15), 12, 1, offset).min(124);
		// Synthesis.
		signal = Mix.fill(tones,
			{ |index|
				pitches = Lag.kr(
					Select.kr(
						Demand.kr(trig, 0, Drand([0, 1, 2], inf)),
						// XXX - move to this scheme
						// DegreeToKey.kr(bufnum, index.linlin(0, tones, 0, 6), 12, 1, freq.cpsmidi)
						DegreeToKey.kr(bufnum, index.linlin(0, tones, 0, 6), 12, 1, note)
					)
					+ TRand.kr(detune.neg, detune, trig),
					lag * Rand(0.8, 1.2)
				).min(127).midicps;

				Blip.ar(
					SinOsc.kr(0.5, 0, LFDNoise1.kr(1.5), pitches),
					100,
					Lag.kr(TRand.kr(0.8, 1.0, trig), lag * Rand(0.8, 1.2)),
				)
				* ( if(index < noOfSynths, 1, 0) );
			}
		);
		signal = RLPF.ar(RLPF.ar(Mix.fill(10, signal), cutoff, rq), cutoff, rq);
		signal = Limiter.ar(MidEQ.ar(signal, [200, 1400], 0.7, 8), (amp/tones) * 0.5);
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;

	// XXX - former \sr__e__perc
	SynthDef("bass__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi;
		var mix, room, signal;
		var trig, timer, lag=0.25;
		trig = momentum > 0.2;
		timer = Timer.kr(trig);
		signal = Pulse.ar(freq,
			width: PinkNoise.kr((ExpRand(0.009, momentum*0.9)*amp).min(0.45), 0.45),
			mul: FSinOsc.ar(LinRand(9, 99*freq).round(9), 0, LinRand(0.09, 0.999-momentum), amp));
		signal = RLPF.ar(signal,
			freq: (freq*9*momentum).max(freq*4.5),
			rq: LinRand(0.09, 4.5)
		).softclip;
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;

	// XXX former \sr__e__analog
	SynthDef("moog__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi,
		    offset=36, cutoff=0,
		    threshold=0.7, scope=12; // XXX =- move this to LFO synth (modulator with DegreeToKey)
		var note, signal;
		var rq;
		var baseFreq, trig, timer, mul, add;
		// Conversion.
		mul = momentum.linlin(0, 1, 1850, 2350);
		add = momentum.linlin(0, 1, 2250, 2800);
		trig = momentum > 0.33; // high momentum causes sharp switch
		timer = Timer.kr(trig);
		baseFreq = TRand.kr(trig:Delay2.kr(Dust.kr(1)));
		cutoff = SelectX.kr(BinaryOpUGen('<', cutoff, 0) * 2,
			[ // Positive cutoff falls at the baseFreq range 500..5000
				TWChoose.kr((timer > 0.25) * trig,
					[
						LFNoise0.ar(baseFreq, mul, add),
						LFNoise1.ar(baseFreq, mul, add),
						LFNoise2.ar(baseFreq).clip2 * mul + add // quadratic interpolation can push beyond [-1..1]
					],
					[0.1, 0.3, 0.6]
				),
				5666 // zero or negative cutoff means constant
			]
		);
		rq = SelectX.kr(BinaryOpUGen('==', cutoff, 5666) * 2,
			[ // If cutoff is variable, RQ depends on momentum.
				momentum.linlin(0, 1, 0.5, 0.1),
				0.1 // constant cutoff means constant RQ
			]
		);
		note = SelectX.kr(BinaryOpUGen('<', az, threshold) * 2,
			[   // Go melodic above height threshold.
				DegreeToKey.kr(bufnum, az.linlin(threshold, 1, 0, scope), 12, 1, offset),
				az.linlin(0, threshold, (offset-6), offset) // bottom to middle change continuously
			]
		);
		// Synthesis.
		signal = Mix.fill(8, { LFSaw.ar((note + 0.1.rand2).midicps) * 0.05 });
		signal = RLPF.ar(RLPF.ar(signal, cutoff, rq), cutoff, rq, amp);
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;

	// audio-through
	// XXX - former \sr__r__authro
	SynthDef("atru__" ++ name, {
		arg bufnum=0, in=0, out=0, trigID=80, amp=1,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    depth=5, elevClip=0.01pi;
		var signal, ds;
		// Conversion.
		ds = distance/3.44;
		// Synthesis.
		signal = RLPF.ar(
			DelayL.ar(
				FreeVerb.ar(
					InFeedback.ar(in, 1),
					distance.clip(0.01, 1), ds, 0.2
				), 0.3, ds
			), distance.linlin(0, 2.sqrt, 10000, 1000), 0.5
		);
		outCodeFunc.value(
			signal, out, trigID, azimuth, distance, elevation,
		    gate, attack, sustain, release, ca, cr, depth, elevClip
		);
	}).add;
};

spatialConf.keysValuesDo { |name, conf|
	// call SynthDef creation
	// `name` - name of spatial configuration
	// function - functionality of spatial configuration

	// synths based on ADSR
	makeSynthDefADSR.(name, {
		arg signal, out=0, trigID=80,
		    azimuth= -0.5pi, distance=0.1, elevation=0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    depth=5, elevClip=0.01pi;
		var dist=distance.linlin(0, 2.sqrt, 0.01, depth);
		var elev=elevation.linlin(-0.5pi, 0.5pi, elevClip.neg, elevClip);
		var mix=distance.linexp(0, 2.sqrt, 0.1, 0.8);
		var room=distance.linexp(0, 2.sqrt, 0.2, 1);
		var w, x, y, z, r, s, t, u, v;
		// reverb, filter, envelope
		var output = RLPF.ar(
			FreeVerb.ar(Mix.ar(signal), mix, room, 0.2),
			distance.linlin(0, 2.sqrt, 10000, 1000),
			0.5
		) * EnvGen.kr(
			Env.asr(attack, sustain, release, curve:[ca, cr]),
			gate: gate,
			doneAction: 2
		);
		// report (single channel after effects before spatialisation)
		SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(output));
		// spatialisation
		#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(output, azimuth, elev, dist);
		Out.ar(out,
			FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
				azimuth: \azim.kr(conf.azim),
				elevation: \elev.kr(conf.elev),
				distance: \dist.kr(conf.dist),
				maxDist: \maxDist.kr(conf.maxDist),
			)
		);
	});

	// percussive synths
	makeSynthDefPerc.(name, {
		arg signal, out=0, trigID=80,
		    azimuth= -0.5pi, distance=0.1, elevation=0,
		    gate=1, attack=0.01, release=0.5,
		    depth=5, elevClip=0.01pi;
		var dist=distance.linlin(0, 2.sqrt, 0.01, depth);
		var elev=elevation.linlin(-0.5pi, 0.5pi, elevClip.neg, elevClip);
		var mix=distance.linexp(0, 2.sqrt, 0.1, 0.8);
		var room=distance.linexp(0, 2.sqrt, 0.2, 1);
		var w, x, y, z, r, s, t, u, v;
		// reverb, filter, envelope
		var output = RLPF.ar(
			FreeVerb.ar(Mix.ar(signal), mix, room, 0.2),
			distance.linlin(0, 2.sqrt, 10000, 1000),
			0.5
		) * EnvGen.kr(
			Env.perc(attack, release), gate:gate
		);
		// report (single channel after effects before spatialisation)
		SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(output));
		// spatialisation
		#w, x, y, z, r, s, t, u, v = FMHEncode1.ar(output, azimuth, elev, dist);
		Out.ar(out,
			FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
				azimuth: \azim.kr(conf.azim),
				elevation: \elev.kr(conf.elev),
				distance: \dist.kr(conf.dist),
				maxDist: \maxDist.kr(conf.maxDist),
			)
		);
	});
};
)


// // TESTING
// a = Synth("buzz__a2", [\freq, 36.midicps, \amp, 0.5]);
// b = Synth("perc__a4", [\freq, 36.midicps]);
// c = Synth("buzz__a4", [\freq, 48.midicps, \amp, 0.5]);
// d = Synth("moog__a2", [\offset, 36, \amp, 0.5]);
// c.setn(\azim, #[-0.1, -0.2, -0.3, -0.4])
// b.setn(\maxDist, 3.5) // this also works: a.set(\maxDist, 2)
// a.set(\gate, 0)
// d.set(\gate, 0)
// c.set(\gate, 0)
//
// b = Buffer.sendCollection(s, FloatArray[0, 3, 7, 10])
// a = Synth(\buzz__a4, [\bufnum, b.bufnum, \freq, 12.midicps, \attack, 3, \momentum, 0.1]);
// a.set(\momentum, 0.8)
// a.set(\amp, 0.5)
// a.set(\freq, 432)
// (
// r = {
// 	(0, 0.05..1).do { |i|
// 		(12,18..72).do { |f|
// 			[i, f].postln;
// 			c.set(
// 				\momentum, i,
// 				\freq, f.midicps
// 			);
// 			0.5.wait;
// 		};
// 		"...".postln;
// 		0.5.wait;
// 	}
// }.fork
// )
// r.stop
// c.set(\gate, 0)


// TEST with nodeId
// (
// r = {
// 	(380..800).do { |i|
// 		i.postln;
// 		s.sendMsg("/n_set", 1006, \freq, i);
// 		0.5.wait;
// 	}
// }.fork
// )
// r.stop

//
//
// // TEST: intro \gro2
// (
// k = Pbind(
// 	\attack, Pseq([60, 0.5, Pxrand(#[1, 0.5, 0.3], 3)]),
// 	\degree, Pseq([8, 11, Pxrand(#[0, 3, 7, 10]+8, 3)]),
// 	\octave, 3,
// 	\momentum, Pseq([0.5, Pwhite(0.0, 1.0)]).round(0.001),
// 	\dur, Pseq([80, 2, Pxrand(#[10, 30, 5], 3)]),
// 	\legato, Pseq([1, 0.5, Pxrand(#[1, 0.5, 0.3], 3)]),
// 	\instrument, \pole__a2,
// 	\bufnum, b.bufnum
// ).trace;
// f = k.play
// )
// f.stop
//
// // TEST: slow bass \prc2
// (
// p = Pbind(
// 	\degree, Pseq(
// 		[ Pseries(0, 3, 3), Pseq([ \ ], 3)], inf
// 	),
// 	\octave, 3,
// 	\dur, Pseq([1/8, 1/2, 1/8, 1/2, 1/2, 1/2], inf),
// 	\instrument, \perc__a2,
// 	\sustain, Pseq(
// 		[ Pseq([0.5, Pwhite(0.2, 0.8)]), Pseq([ \ ], 4)], inf
// 	),
// 	\amp, 0.8,
// 	\bufnum, b.bufnum,
// ).trace;
// e = p.play(TempoClock(16/60))
// )
// e.stop
//
// (
// k = Pbind(
// 	\degree, Pseq(
// 		[ Pseries(0, 5, 4), Pseq([ \ ], 3)], inf
// 	),
// 	\octave, 4,
// 	\dur, Pseq([1/8, 1/2, 1/8, 1/2, 1/2, 1/2], inf),
// 	\instrument, \perc__a4,
// 	\sustain, Pseq(
// 		[ Pseq([0.5, Pwhite(0.2, 0.8)]), Pseq([ \ ], 4)], inf
// 	),
// 	\amp, 0.8,
// 	\bufnum, b.bufnum,
// ).trace;
// f = k.play(TempoClock(32/60))
// )
// f.stop