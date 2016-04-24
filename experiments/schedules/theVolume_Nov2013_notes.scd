// TO-DO:
// - opportunity to hook synth from node to the object and back (only change \busnum??)

// // finish experiment with bass line:
// (
// SynthDef(\help_mdapiano, { |out=0, freq=440, gate=1|
//     var son = MdaPiano.ar(freq, gate, release: 0.9, stereo: 0.3, sustain: 0);
//     DetectSilence.ar(son, 0.01, doneAction:2);
//     Out.ar(out, son * 0.1);
// }).add;
//
// //TempoClock.default.beatsPerBar= 3;
// p= Pbind(
//     \instrument, \help_mdapiano,
//     \octave, 3,
//     //\degree, Pn(Pseq(Scale.choose.degrees.scramble ++ [\], 4), inf).trace,
//     \degree, Pseq(
//     [13, 12, 0, 8, 7, 1, 0, 7, 12, Pwrand([\, 13], [0.9, 0.1], 1)], inf).trace,
//     \dur, Pseq(1/4 ! 10, inf),
//     \legato, Pwhite(0.3, 0.5, inf)
// );
// t = TempoClock.default.tempo= 60/60;
// t.schedAbs(t.nextTimeOnGrid(2, -0.001, t.elapsedBeats.ceil), { arg ... args;
//     args.postln;
//     t.beatsPerBar_(3);
//     p.play;
// });
// )


// (["a#3", "a3", "a2", "f3", "e3", "a#2", "a2", "e3", "a3"].namemidi - 57).sort
// // = orig: Pelog 0,1,3,7,8
// [13, 12, 0, 8, 7, 1, 0, 7, 12]
// // test 1: #[0,1,4,6,7,8,11], 12, name: "Purvi"
// [13, 12, 0, 8, 7, 1, 0, 7, 12]
//