

// markov set experiments
m = MarkovSet.fill(100, Pseq([1, 2, 3, 4, Pxrand([5, 10, 15, 30, 35, 45, 60, 120])], inf).asStream);

(
m = MarkovSet([
	[\s, [1, 2, 2.5, 3, 3.5, 4]],
	[\m, [5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 10, 12]],
	[\l, [20, 25, 27, 32, 40, 45, 55, 60, 90, 120]]
]);
)


m.dict.keysValuesDo { |key, val| postf("key: %\t\tvalue: %\n", key, val) }; ""

8.do { m.next(\s).postln };
8.do { m.next(\m).postln };
8.do { m.next(\l).postln };


////////////////////////////////////////////////////////////////////////////////

(
SynthDef( \ev_start, { arg out= 0, note= 60, dur=1, amp=0.2;
	var freq, env, signal;

	freq= note.midicps;
	env= EnvGen.kr( Env.perc, levelScale: 0.3, timeScale: dur, doneAction: 2 );
	out= env * RLPF.ar( LFSaw.ar( freq )
			+ Impulse.ar( XLine.kr(freq, freq + 100,1.5), 0.0, 0.7.rand)
			+ WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps,
		0.1
	);
 	signal = [out, DelayN.ar(out, 0.04, 0.04) ];
	4.do({ out = AllpassN.ar(out, 0.05, [0.05.rand, 0.05.rand], 4, amp) });
	Out.ar( out, signal );
	}
).send(s);

SynthDef( \rec_start, { arg outbus= 0, freq= 60, dur=0.6, amp=0.1, pan= 0;
	var env, signal;

	env= EnvGen.kr( Env.new([0, 0.8, amp, amp, 0.001],[0.1, 0.01, dur-0.21, 0.1], 'welch'), doneAction: 2 );
	signal= env * SinOsc.ar( freq );
	Out.ar( outbus, Pan2.ar(signal, pan) );
	}
).send(s);

SynthDef( \noisy, { arg outbus= 0, freq= 20, dur=1, amp=0.2, att=0.5, rel=0.2, gate=1;
	var out, env, signal;

	env= EnvGen.kr( Env.asr(att, amp, rel, -4), gate: gate, doneAction: 2 );
	out= env * RLPF.ar( Impulse.ar( XLine.kr(freq, freq + 100,1.5), 0.0, 0.7.rand)
			+ WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps,
		0.1
	);
 	signal = [out, DelayN.ar(out, 0.04, 0.04) ];
	4.do({ out = AllpassN.ar(out, 0.05, [0.05.rand, 0.05.rand], 4, amp) });
	Out.ar( outbus, signal );
	}
).send(s);
)

(
var rout, msetKey, msetWait, rectime;
var totalTime= 0, cycles= 0;

cycles= rrand(30, 50);

msetWait= MarkovSet([ // markov set for waiting time (1st order)
	[\ss, [1, 1.5, 2, 2.5, 3]], // super short
	[\s, [2.5, 3.5, 4, 4.5, 5, 5.5]], // short
	[\a, [5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 10, 12]], // ave
	[\l, [20, 25, 27, 32, 40, 45, 55, 60, 90, 120], [6,7,4,4,3,3,2,2,1,1].normalizeSum ] // long
]);

msetKey= MarkovSet([ // markov set for number of msetWait use (2nd order)
	[\n,
		[ 2, 5, 10, 12, 15, 25, 40 ], // number of repeats
		[ 6, 12, 9, 3, 2, 0.5, 0.1 ].normalizeSum // longer sequences are less probable
	]
]);

//msetKey.dict.keysValuesDo { |k, v| postf("key: %\t\tvalue: %\n", k, v) }; "";

rout= Routine.new({
	var keySteps, key, waitKey, wait, midinote, ns;
	var resArr= [ List.new(), List.new() ];

	cycles.do({ |i|
		key= msetWait.dict.keys.asArray.choose;
		keySteps= msetKey.next(\n);
		postf("---\nkey: %\tsteps: %\n", key, keySteps);

		keySteps.do({ |j|
			waitKey= msetWait.next(key);
			wait= rrand(waitKey * 0.75, waitKey).max(0.01);
			midinote= wait.linlin(0.5, 120, 10, 80); // the shorter dur, the higher the note
			rectime= switch (key) // record time varies but depends on the current duration
				{ \ss } { 0.1 }
				{ \s } { rrand(0.5, 2) }
				{ \a } { rrand(2, 3) }
				{ \l } { rrand(1, 10) };

			resArr[0].add(keySteps);
			resArr[1].add(wait);

			totalTime= totalTime+wait;

			postf("%:% - wait time: %\trec time: %\t\tmidinote: %\n", i, j, wait, rectime, midinote);

			Synth(\rec_start, [ \pan, 1.0.bilinrand, \freq, 1300+130.0.bilinrand ]);
			ns= Synth(\noisy, [ \freq, rrand(24, 240), \amp, rrand(0.01, 0.1), \att, 0.5.rand ]); // hold the noise while rec
			rectime.wait;
			ns.set(\gate, 0, \rel, 2.0.rand);
			Synth(\ev_start, [ \note, midinote ]);
			(wait-rectime).max(0.1).wait;
//
//			0.001.wait;
		});
		0.001.wait;
	});
	0.001.wait;
	postf("---\ncycles: %\ttotal min: %\n", cycles, totalTime/60);
	{
		Plotter("markov chain", Rect(600, 30, 1000, 400))
			.superpose_(true)
			.plotMode_(\plines)
			.value= resArr;
	}.defer;
});

rout.play;
)
