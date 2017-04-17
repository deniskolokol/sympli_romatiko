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

var makeSynthDef = { |name, outCodeFunc|
	SynthDef("buzz__" ++ name, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
		    gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
		    depth=5, elevClip=0.01pi;
		var w, x, y, z, r, s, t, u, v, elev, dist;
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
		    depth=5, elevClip=0.01pi;
		var w, x, y, z, r, s, t, u, v, elev, dist;
		var mix, room, signal, output;
		var cutoff, rq, rate, pitches, trig, mul, add, detune, lag,
		tones=10, noOfSynths=20;
		// Conversion.
		rq = momentum.lincurve(0, 1, 0.6, 0.01, 4);
		mul = momentum.lincurve(0, 1, 400, 2000, 4);
		add = momentum.lincurve(0, 1, 600, 10000, 4);
		cutoff = (LFNoise2.ar(momentum).clip2 * mul + add);
		rate = momentum.linlin(0, 1, 2, 4).round;
		trig = Impulse.kr(0) + Dust2.kr(rate);
		lag = momentum.lincurve(0, 1, 0.5, 0.05, -4);
		detune = momentum.lincurve(0, 1, 0.1, 0.5, 4);
		// Synthesis.
		signal = Mix.fill(tones,
			{ |index|
				pitches = Lag.kr(
					Select.kr(
						Demand.kr(trig, 0, Drand([0, 1, 2], inf)),
						DegreeToKey.kr(bufnum, index.linlin(0, tones, 0, 6), 12, 1, freq.cpsmidi)
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
		signal = Limiter.ar(MidEQ.ar(signal, [200, 1400], 0.7, 8), amp);
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
		var w, x, y, z, r, s, t, u, v, elev, dist;
		var mix, room, signal, output;
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
};

spatialConf.keysValuesDo { |name, conf|
	// call SynthDef creation
	// `name` - name of spatial configuration
	// function - functionality of spatial configuration
	makeSynthDef.(name, {
		arg signal, out=0, trigID=80,
		    azimuth= -0.5pi, distance=0.1, elevation=0,
		    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
		    depth=5, elevClip=0.01pi;
		var dist=distance.linlin(0, 2.sqrt, 0.01, depth);
		var elev=elevation.linlin(-0.5pi, 0.5pi, elevClip.neg, elevClip);
		var mix=distance.linexp(0, 2.sqrt, 0.1, 0.8);
		var room=distance.linexp(0, 2.sqrt, 0.2, 1);
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
}
)

// // TESTING
// a = Synth("buzz__a2", [\freq, 36.midicps, \amp, 0.5]);
// b = Synth("perc__a4", [\freq, 36.midicps]);
// c = Synth("buzz__a4", [\freq, 48.midicps, \amp, 0.5]);
// d = Synth("pole__a2", [\freq, 49.midicps, \amp, 0.5]);
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