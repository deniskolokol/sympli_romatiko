// 2D - redUniverse: simple spring controlled with kinect in multichannel
// first do:
// $ cd ~/dev/kinect/OpenNI-Bin-MacOSX-v1.1.0.41/OSCeleton/
// $ ./osceleton -p 57120

//
(
var calibMag= 1.41;
var soundsDir= "~/Music/bibeast/sounds/";
var speakerArr, speakerBuff;
var w, world, wgrav, width= 800, height= 800, margin= 5, trashCleaner;
var skelObj, skelCoords;
var objects, synths, currObj= 0, currSynth= 0, objInd, mass, color, pos, objNoisy= nil, synNoisy= nil, posNoisy, objAudioIn= nil, synAudioIn= nil, posAudioIn, wind;
var responderKinect, responderKinectNewUser, responderKinectLostUser, removeKinectResp;
var fps= 40, frame= 0, fmsTrashClean, trigTrashClean;
var msetWait, msetKey, key, keySteps, waitKey, wait, waitCurr, waitRep, rectime= 0, rectimeRep, steps, midinote;
var groupSched= Group.new(s), groupWorld= Group.new(s); // groups for rec/aux sythns and objects synths respectively;
var inbus= 30, recBufStart, recBufStop, recSynth, isRecording, currFilename, currBufnum, currBuffer, startSynth, stopSynth, bufPool= List.new, loadBuf;

//--initial
skelObj= Array.fill(5, { nil }); // container for objects representing skeleton joints
skelCoords= Array.fill(5, { |i| [i*(width/6)+100, (i%2)*(height/15)+150, 0] }); // test coordinates
objects= Array.fill(5, { nil }); // container for physical objects
synths= Array.fill(5, { nil }); // container for synths connected to objects
fmsTrashClean= 60*fps; // trash cleaner starts every N seconds

//--speakers setup
speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring (in A6 use [ 135, 45, -45, -135 ])
speakerBuff= speakerArr.loadToBuffer;

//--scheduling
msetWait= MarkovSet([ // markov set for waiting time (1st order)
//	[\ss, [1, 1.5, 2, 2.5, 3], [1,2,2,4,5].normalizeSum], // super short
	[\s, [2.5, 3.5, 4, 4.5, 5, 5.5]], // short
	[\a, [5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 10, 12]], // ave
	[\l, [20, 25, 27, 32, 40, 45, 55, 60, 90, 120], [6,7,4,4,3,3,2,2,1,1].normalizeSum ] // long
]);

msetKey= MarkovSet([ // markov set for number of msetWait use (2nd order)
	[\n,
		[ 2, 5, 10, 12, 15, 25, 30 ], // number of repeats
		[ 6, 12, 9, 3, 2, 0.5, 0.1 ].normalizeSum // longer sequences are less probable
	]
]);
// first sequence
keySteps= msetKey.next(\n);
key= msetWait.dict.keys.asArray.choose;
steps= 0;
waitKey= msetWait.next(key);
waitRep= rrand(waitKey * 0.75, waitKey).max(1).round;
wait= waitRep* fps;
//--scheduling

//--kinect
responderKinectNewUser= OSCresponderNode(nil, '/new_skel', {arg t, r, msg;
	msg.postln;
	}).add;
responderKinectLostUser= OSCresponderNode(nil, '/lost_skel', {arg t, r, msg;
	msg.postln;
	}).add;
responderKinect= OSCresponderNode(nil, '/joint', {arg t, r, msg;
	var joint;
//	msg.postln;
	joint= msg[1];
	//!! WARNING !! Depth and Y can be re-allocated depending on where kinect is positioned:
	// - in front or behind the user: msg[4] is Y, msg[5] is Depth
	// - above the user: msg[4] is Depth, msg[5] is Y
	joint.switch(
		'r_hand', { // mirroring hands!
			skelCoords[0][0]= msg[3].linlin(0, 1, margin, width-margin); // X
			skelCoords[0][1]= msg[5].linlin(0.3, 2.7, margin, height-margin); // Depth
			skelCoords[0][2]= msg[4].linlin(0, 1, 1, 0); // Y
			},
		'r_elbow', {
			skelCoords[1][0]= msg[3].linlin(0, 1, margin, width-margin); // X
			skelCoords[1][1]= msg[5].linlin(0.3, 2.7, margin, height-margin); // Depth
			skelCoords[1][2]= msg[4].linlin(0, 1, 1, 0); // Y
			},
		'neck', {
			skelCoords[2][0]= msg[3].linlin(0, 1, margin, width-margin); // X
			skelCoords[2][1]= msg[5].linlin(0.3, 2.7, margin, height-margin); // Depth
			skelCoords[2][2]= msg[4].linlin(0, 1, 1, 0); // Y
			},
		'l_elbow', {
			skelCoords[3][0]= msg[3].linlin(0, 1, margin, width-margin); // X
			skelCoords[3][1]= msg[5].linlin(0.3, 2.7, margin, height-margin); // Depth
			skelCoords[3][2]= msg[4].linlin(0, 1, 1, 0); // Y
			},
		'l_hand', {
			skelCoords[4][0]= msg[3].linlin(0, 1, margin, width-margin); // X
			skelCoords[4][1]= msg[5].linlin(0.3, 2.7, margin, height-margin); // Depth
			skelCoords[4][2]= msg[4].linlin(0, 1, 1, 0); // Y
			}
		);
	}).add;
removeKinectResp= {
	responderKinectNewUser.remove;
	responderKinectLostUser.remove;
	responderKinect.remove;
	};
//--kinect

//--world
w= RedWindow("tracking", Rect(950, 20, width, height))
	.background_(Color.black) .front;
wgrav= RedVector2D[0, 0.28];
world= RedWorld3(RedVector2D[width, height], wgrav, 30, 0.8); //dim, grav, maxvel, damp

//--constant objects
// skeleton
skelObj.size.do({ |i|
	skelObj[i]= RedObject(world, RedVector2D[width, height].rand, RedVector2D[0, 0], RedVector2D[0, 0], 3000, 10);
	});
// rec guide
objNoisy= RedBoid(world, RedVector2D[width, height].rand, RedVector2D[1, 1], RedVector2D[0, 0], 5, 10)
	.maxForce_(1).wdistance_(3.rrand(13)).wchange_(0.75).wradius_(10.rrand(50));
// audio through
objAudioIn= RedBoid(world, RedVector2D[width, height].rand, RedVector2D[1, 1], RedVector2D[0, 0], 0.5, 10)
	.maxForce_(1).wdistance_(3.rrand(13)).wchange_(0.75).wradius_(10.rrand(50));
synAudioIn= Synth.head(groupSched, \audioin_1, [ \speakerBuffNum, speakerBuff.bufnum, \inbus, inbus ]); // audioin is persistent

//--draw objects
w.draw{
	frame= frame + 1;

	world.gravity= RedVector2D.newFrom(skelCoords[2][0..1]/([width, height]) - 0.5); // head's position defines vector of gravity

	//--user's skeleton
	skelObj.size.do({ |i|
		skelObj[i].loc= RedVector2D.newFrom(skelCoords[i][0..1]);
		skelObj[i].update;
		world.contain(skelObj[i]);
		//--render
		Pen.strokeColor= Color.blue;
		Pen.fillColor= Color.blue;
		Pen.fillOval(Rect.aboutRedObject2D(skelObj[i]));
		if( i>0, {
			Pen.line(skelObj[i].loc.asPoint, skelObj[i-1].loc.asPoint);
			Pen.stroke;
			});
		Pen.fillColor= Color.white;
		Pen.stringAtPoint(skelCoords[i][0..1].round.asString.[1..skelCoords[i][0..1].round.asString.size-2], (skelCoords[i][0..1]-5).asPoint);
		});

	//--objects
	world.objects.do({ |o, i|
		if(skelObj.includes(o).not && [objNoisy, objAudioIn].includes(o).not, {
			o.asString.switch(
				"a RedBoid", {
					o.addForceArrive(skelObj[0].loc);
					o.addForceArrive(skelObj[4].loc);
					color= Color.yellow(0.5, 0.8);
					},
				"a RedObject", {
					o.addForce(o.gravityForce(skelObj[0]));
					o.addForce(o.gravityForce(skelObj[4]));
					color= Color.gray(0.5, 0.8);
					}
				);
			o.addForce(world.gravity);
			o.update;
			world.contain(o);
			Pen.fillColor= color;
			Pen.fillOval(Rect.aboutRedObject2D(o));
			// control corresponding synth
			pos= Complex(
				o.loc[0].linlin(0, width, 1, -1), // x
				o.loc[1].linlin(0, height, -1, 1) // y
				);
			objInd= objects.indexOf(o) ? 0;
			if(synths[objInd] != nil, {
				synths[objInd].set(
					\azimuth, pos.theta.linlin(-pi,pi, -180, 180),
					\spread, ( 1-( (pos.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
					\frate, o.mass.linlin(0.5,5.0, 1.0,0.5),
					\amp, o.mass.linlin(0.5,5.0, 0.1,1.0), // (pos.magnitude / calibMag).clip(0.01, 1),
					\ax, o.loc[0].linlin(0,width, 0,1)
					);
				//bookmark
				if( skelObj[0].loc.distance(o.loc) < o.size, {
					synths[objInd].set( \ay, skelCoords[0][2].linlin(0,1, 0.01, 3) ); // objects wondering around right hand
					});
				if( skelObj[4].loc.distance(o.loc) < o.size, {
					synths[objInd].set( \ay, skelCoords[4][2].linlin(0,1, 0.01, 3) ); // objects wondering around left hand
					});
				});
			});
		});

	//--start recording
	if( frame == wait, {
		if(steps == keySteps, {
			keySteps= msetKey.next(\n);
			key= msetWait.dict.keys.asArray.choose;
			steps= 0;
			});

		rectimeRep= switch (key) // record time varies but depends on the current duration
			{ \ss } { 0.5 }
			{ \s } { rrand(0.5, 2).round(0.5) }
			{ \a } { rrand(2, 4).round(0.5) }
			{ \l } { rrand(2, 10).round(0.5) };
		rectime= fps * rectimeRep;

		Synth.head(groupSched, \rec_start, [ // signal for rec start
			\speakerBuffNum, speakerBuff.bufnum,
			\freq, 1300+130.0.bilinrand,
			\azimuth, 180.bilinrand,
			\spread, 10.rrand(50)
			]);
		synNoisy= Synth.head(groupSched, \noisy, [ // hold the noise while recording
			\speakerBuffNum, speakerBuff.bufnum,
			\freq,rrand(24, 240),
			\amp,rrand(0.01, 0.1),
			\dur, rectimeRep,
			\att, 0.5.rand,
			\rel,1.0.rand(rectimeRep)
			]);
		objNoisy.loc= RedVector2D[width, height].rand;

		//start recording
		currFilename= soundsDir++"kin_"++Date.getDate.stamp.asString++".aif";
		currBufnum= recBufStart.value(inbus: inbus, numchannels: 1, path: currFilename);

		steps= steps + 1; // counting steps
		});

	//--new object
	if( frame == (wait+rectime), { // object is created only when rec is finished
		waitKey= msetWait.next(key);
		waitRep= rrand(waitKey*0.75, waitKey).max(1).round;
		waitCurr= waitRep * fps;

		currObj.postln;

		mass= 0.5.rrand(5);
		objects.put(currObj,
			switch( ["a RedBoid", "a RedObject"].choose,
				"a RedBoid", {
					RedBoid(world, RedVector2D[width, height].rand, RedVector2D[0, 0], RedVector2D[0, 0], mass, mass*5)
							.maxForce_(1).wdistance_(3.rrand(13)).wchange_(0.75).wradius_(10.rrand(50))
					},
				"a RedObject", {
					RedObject(world, RedVector2D[width, height].rand, RedVector2D[0, 0], RedVector2D[0, 0], mass, mass*5)
					}
				);
			);
		currSynth= currObj;
		currObj= currObj+1;
		if(currObj == objects.size, { currObj= 0 }); // objects are in FIFO stack

		midinote= waitRep.linlin(0.5, 120, 10, 80); // the shorter dur, the higher the note
		Synth.head(groupSched, \ev_start, [ // end of recording
			\speakerBuffNum, speakerBuff.bufnum,
			\note, midinote,
			\azimuth, 180.bilinrand,
			\spread, 10.rrand(50)
			]); // signal for rec end

		recBufStop.value(currBufnum); // stop recording
		currBuffer= Buffer.read(s, currFilename);
		loadBuf.value(currBuffer);

		synNoisy= nil; // to prevent msg FAILURE /n_set Node not found

		wait= wait + waitCurr + rectime; // accumulating wait time
		});

	// synth vol depends on object's mass
	if(synths[currObj] != nil, { synths[currObj].set( \vol, objects[currObj].mass.linlin(0,0.5, 0,1) ) });

	//wind blowing and moving objNoisy and objAudioIn
	wind= 0.5*sin(2pi*((frame % fmsTrashClean).round/width));

	if(objNoisy != nil, { // process \noisy synth
		Pen.fillColor= Color.red;
		Pen.fillOval(Rect.aboutRedObject2D(objNoisy));
		objNoisy.addForce(wind);
		objNoisy.update;
		world.contain(objNoisy);

		posNoisy= Complex(
			objNoisy.loc[0].linlin(0, width, 1, -1), // x
			objNoisy.loc[1].linlin(0, height, -1, 1) // y
		);

		if( synNoisy != nil, {
			synNoisy.set(
				\azimuth, posNoisy.theta.linlin(-pi,pi, -180, 180),
				\spread, ( 1-( (posNoisy.magnitude / calibMag).pow(0.33) ) )*100
				)
			});
		});

	if(objAudioIn != nil, { // process \audio_in obj and synth
		Pen.fillColor= Color.green(0.7, 0.8);
		Pen.fillOval(Rect.aboutRedObject2D(objAudioIn));
		objAudioIn.addForce(wind)
			.addForce(world.gravity)
			.addForceArrive(skelObj[2].loc, 0.5); // head attracts audio_in

		world.objects.do({ |obj|
			if(( obj != objAudioIn) && skelObj.includes(obj).not, {
				objAudioIn.addForce(obj.gravityForce(objAudioIn));
				if(objAudioIn.loc.distance(obj.loc) < (obj.size*2), {
					objAudioIn.addForce(objAudioIn.gravityForce(obj).neg);
					});
				});
			});

		objAudioIn.update;
		world.contain(objAudioIn);

		posAudioIn= Complex(
			objAudioIn.loc[0].linlin(0, width, 1, -1), // x
			objAudioIn.loc[1].linlin(0, height, -1, 1) // y
		);

		if( synAudioIn != nil, {
			synAudioIn.set(
				\azimuth, posAudioIn.theta.linlin(-pi,pi, -180, 180),
				\spread, ( 1-( (posAudioIn.magnitude / calibMag).pow(0.33) ) )*100
				)
			});
		});

	//--trash cleaner
	trigTrashClean= frame % fmsTrashClean;
	if( trigTrashClean == 0, { trashCleaner.value(world) });
	// report trash clean
	if( frame > fmsTrashClean, {
		if( [20,60,100].includes(trigTrashClean.round(20)), {
			Pen.fillColor= Color.grey(0.7, 0.7);
			}, {
			Pen.fillColor= Color.black;
			});
		Pen.stringAtPoint("trash clean", [width-60, height-20].asPoint);
		});

	//--info line
	Pen.fillColor= Color.grey(0.7, 0.7); // key
	Pen.stringAtPoint("key: ", [10, height-20].asPoint);
	Pen.fillColor= Color.white;
	Pen.stringAtPoint(key.asString.toUpper, [35, height-20].asPoint);
	Pen.fillColor= Color.grey(0.7, 0.7); // key steps
	Pen.stringAtPoint("steps: ", [58, height-20].asPoint);
	Pen.fillColor= Color.white;
	Pen.stringAtPoint((keySteps-steps).asString++"/"++keySteps.asString, [93, height-20].asPoint);
	Pen.fillColor= Color.grey(0.7, 0.7); // wait time
	Pen.stringAtPoint("wait: ", [125, height-20].asPoint);
	Pen.fillColor= Color.white;
	Pen.stringAtPoint(waitRep.asString, [150, height-20].asPoint);
	Pen.fillColor= Color.grey(0.7, 0.7); // rec time
	Pen.stringAtPoint("rec: ", [180, height-20].asPoint);
	Pen.fillColor= Color.white;
	Pen.stringAtPoint(rectimeRep.asString, [200, height-20].asPoint);
	};
w.animate= true;

//--functions
recBufStart= { arg bnum, inbus, numchannels, path, headformat= 'aiff', bitdepth= 'int16';
	var bufnum;
	bufnum= bnum ? s.bufferAllocator.alloc(1);
	s.sendMsg("/b_alloc", bufnum, 32768 * numchannels, numchannels,
		["/b_write", bufnum, path, headformat, bitdepth, 0, 0, 1]
	);
	recSynth= Synth.tail(RootNode(Server.default), "recsyn_" ++ numchannels, [ \inbus, inbus, \bufnum, bufnum ]);
	isRecording= true;
	inform("RECORDING...");

	bufnum // returns bufnum
	};

recBufStop= { arg bnum;
	try{ recSynth.free };
	s.sendMsg("/b_close", bnum, ["/b_free", bnum]);
	isRecording= false;
	inform("RECORDING STOPPED.");
	};

loadBuf= { arg buff;
	var loadBufTask= Task({
		var hand, objtype;
		inf.do({ |j|
			if(buff.numChannels != nil, {
				bufPool.add(buff); // add to the pool
				// launch a new synth (object is already launched)
				try{ startSynth.value( buff ) };
				loadBufTask.stop;
				});
			0.01.wait;
			});
		}).start;
	};

startSynth= { arg buff= currBufnum, bus= 0, amp= 1, gate= 1;
	try{ stopSynth.value(2.0.rand, currSynth) }; // new synth clears out the sloth
	synths.put(
		currSynth, Synth.head(groupWorld, \granbufphas_1, [
			\speakerBuffNum, speakerBuff.bufnum,
			\busnum, bus,
			\bufnum, buff,
			\ax, 0.5, \ay, 0.5,
			\amp, amp,
			\gate, gate
			]);
		);
	};

stopSynth= { arg reltime, synthInd;
	if( synths[synthInd] != nil, {
		synths[synthInd].set(\rel, reltime, \gate, 0);
		synths[synthInd]= nil;
		});
	};

trashCleaner= { |world|
	world.objects.do({ |o|
		if( (skelObj.includes(o) || objects.includes(o)).not, { world.remove(o); o.free; o= nil; });
		});
	};
//--functions

w.onClose({
	removeKinectResp.value();
	bufPool.do{ |buff| buff.free };
	});

CmdPeriod.doOnce({
	removeKinectResp.value();
	bufPool.do{ |buff| buff.free };
	w.close;
	});
)

s.queryAllNodes



// synths
(
// mono recording synth
SynthDef(\recsyn_1, { arg inbus, bufnum= 0, amp= 1;
	DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).load(s);

// playback
SynthDef(\playbufphas_1, {
	arg bufnum= 0, busnum= 0, ax, ay, panidx= 0.7, panshift= 0, vol= 1, modf= 1, factor= 0, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, loop= 0;
	var timescale, ratescale, trig= 1, env, offset, fadeTime= 0.1, speed= 20.0, in, out, updateRate=30, speakerArr, speakerBuff;

	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid
//	speakerArr= VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]); // works in A6
	speakerBuff= speakerArr.loadToBuffer;

	timescale= ax * BufDur.kr(bufnum); // arg X: duration
	ratescale= (ay*1.99)+0.01; // 0..2
	env= Lag.kr(ToggleFF.kr(trig), fadeTime); // one signal to contol which channel is heard
	offset= Phasor.ar(0, timescale * BufRateScale.kr(bufnum), 0, BufFrames.kr(bufnum));
	in=	SelectL.ar( env,
		PlayBuf.ar(
			1,
			bufnum,
			ratescale * (SinOsc.kr(modf, 0, 0.5*modf, 440)/440),
			0,
			offset,
			loop, doneAction:2)
	);
	in=	vol *
		(in
		+PitchShift.ar(in, 0.2, factor, 0.01*panidx, factor.linlin(0, 1.5, 0.1, 0.5), factor.linlin(0, 1, 0, 4))
		+PitchShift.ar(in, 0.2, factor.linlin(0,1.5, 0.3,0.7), 0.01*panidx, factor.linlin(0, 1.5, 0.1, 0.5), factor.linlin(0, 1, 0, 2))
		);

	out= VBAP.ar(4, in, speakerBuff.bufnum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
}).load(s);

// playback
SynthDef(\loopbufphas_1, {
	arg bufnum= 0, busnum= 0, ax, ay, panidx= 0.7, panshift= 0, vol= 1, modf= 1, factor= 0, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, loop= 1;
	var timescale, ratescale, trig= 1, env, offset, fadeTime= 0.1, speed= 20.0, in, out, updateRate=30, speakerArr, speakerBuff;

	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid
//	speakerArr= VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]); // works in A6
	speakerBuff= speakerArr.loadToBuffer;

	timescale= ax * BufDur.kr(bufnum); // arg X: duration
	ratescale= (ay*1.99)+0.01; // 0..2
	env= Lag.kr(ToggleFF.kr(trig), fadeTime); // one signal to contol which channel is heard
	offset= Phasor.ar(0, timescale * BufRateScale.kr(bufnum), 0, BufFrames.kr(bufnum));
	in=	SelectL.ar( env,
		PlayBuf.ar(
			1,
			bufnum,
			ratescale * (SinOsc.kr(modf, 0, 0.5*modf, 440)/440),
			0,
			offset,
			loop, doneAction:2)
	);
	in=	vol *
		(in
		+PitchShift.ar(in, 0.2, factor, 0.01*panidx, factor.linlin(0, 1.5, 0.1, 0.5), factor.linlin(0, 1, 0, 4))
		+PitchShift.ar(in, 0.2, factor.linlin(0,1.5, 0.3,0.7), 0.01*panidx, factor.linlin(0, 1.5, 0.1, 0.5), factor.linlin(0, 1, 0, 2))
		);

	out= VBAP.ar(4, in, speakerBuff.bufnum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
}).load(s);

// simple 1 gran for particles system
SynthDef(\loopbufgran_1, {arg bufnum=0, rate=1, startPos=0.0, dur=0.08, vol= 0, busnum=0, azimuth= 0, elevation= 0, spread= 0;
	var grain, out, speakerArr, speakerBuff;
	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid
//	speakerArr= VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]); // works in A6
	speakerBuff= speakerArr.loadToBuffer;

	grain = PlayBuf.ar(1, bufnum, rate*BufRateScale.kr(bufnum), 1, BufFrames.ir(bufnum)*startPos, 0)
		*(EnvGen.kr(Env.sine(dur, vol),doneAction:2)-0.001);

	out= VBAP.ar(4, grain, speakerBuff.bufnum, azimuth, elevation, spread);

	Out.ar(busnum, out)
}).load(s);

// granulating
SynthDef( \granbufphas_1, {
	arg bufnum= 0, busnum= 0, ax, ay, amp, gate= 0, rate= 1, frate= 1, fdur= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var trate, dur, pos, in, out, clk;
	trate= frate.clip(0.5, 10);
	dur= 1 / trate;
	clk= Dust.kr(trate);
	pos= ax * Phasor.ar(0, ay/BufSampleRate.kr(bufnum), 0, BufDur.kr(bufnum)); // + TRand.kr(0, 0.01, clk);
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * rate,
		centerPos: pos,
		dur: dur,
		amp: amp
		);
	out= VBAP.ar(4, Mix.new(in), speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).load(s);

// audio in
SynthDef(\audioin_1, {arg rate=1, amp= 1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var in, out;
	in= InFeedback.ar(inbus, 1) * EnvGen.kr( Env.asr(att, amp, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	out= VBAP.ar(4, in, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(outbus, out)
	}
).load(s);

// synths for routine
SynthDef( \rec_start, { arg outbus= 0, freq= 60, dur=0.8, amp=0.05, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var signal, out;
	signal= SinOsc.ar( freq ) *
		EnvGen.kr( Env.new([0, amp-0.02, amp, amp, 0.001],[0.1, 0.01, dur-0.21, 0.1], 'welch'), doneAction: 2 );
	out= VBAP.ar(4, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).load(s);

SynthDef( \ev_start, { arg outbus= 0, note= 60, dur=1, amp=0.1, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var in, out, freq, env, signal;
	freq= note.midicps;
	env= EnvGen.kr( Env.perc, levelScale: 0.3, timeScale: dur, doneAction: 2 );
	in= env * RLPF.ar( LFSaw.ar( freq )
			+ Impulse.ar( XLine.kr(freq, freq + 100,1.5), 0.0, 0.7.rand)
			+ WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps,
		0.1
	);
 	signal= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4, amp) });
	out= VBAP.ar(4, Mix.new(signal), speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).load(s);

SynthDef( \noisy, { arg outbus= 0, freq= 20, dur=1, amp=0.2, att=0.5, rel= 0.1, gate=1, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var in, out, env, signal;
	env= EnvGen.kr( Env.linen(att, dur-att-rel, rel, amp, \sine), doneAction: 2 );
	in= env * RLPF.ar(
		Impulse.ar( XLine.kr(freq, freq + 100, dur-rel), 0.0, 0.7.rand) + WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps, 0.1
		);
 	signal= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4, amp) });
	out= VBAP.ar(4, Mix.new(signal), speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).load(s);
)
