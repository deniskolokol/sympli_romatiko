

// 2
// 2D - redUniverse: simple spring controlled with mouse in multichannel
(
	var width= 500, height= 500, w, world, wgrav, obj, trg, mp;
	var springStiff= 0.1, springDamp= 0.9, springLength= 50;
	var buf, snd, pos;

	//--multichannel setup:
	// 4 channel ring
	buf = VBAPSpeakerArray.new(2, [-45, -135, 135, 45]).loadToBuffer;

	//--sound src
	snd = { arg azimuth= 0, elevation= 0, spread= 0, amp=0.01;
		VBAP.ar(4, PinkNoise.ar(0.2, mul:amp), buf.bufnum, azimuth, elevation, spread);
	}.scope;

	//--world
	w= RedWindow("spring test", Rect(128, 64, width, height)).front;
	mp= w.mouse;
	wgrav= RedVector2D[0, 0.28];
	world= RedWorld1(RedVector2D[width, height], wgrav, 30, 0.8); //dim,grav,maxvel,damp

	//--objects
	obj= RedObject(world, RedVector2D[0, 0], RedVector2D[0, 0], RedVector2D[0, 0], 1.5, 10);
	trg= RedObject(world, RedVector2D[width*0.5, height*0.5]);

	//--loop
	w.draw{
		if(mp!=w.mouse, { //just to keep target in middle if no mouse input
			trg.loc= w.mouse;
		});

		obj.spring(trg, springStiff, springDamp, springLength); //target, stiffness, damping, length

		obj.addForce(world.gravity);
		obj.update;
		pos= Complex(
			obj.loc[0].linlin(0, w.bounds.width, 1, -1), // x
			obj.loc[1].linlin(0, w.bounds.height, -1, 1) // y
		);
		snd.set(
			\azimuth, pos.theta.linlin(-pi,pi, -180, 180),
			\spread, pos.magnitude.linlin(0, 1.41, 100, 0)
		);
		world.contain(obj);

		//--render
		Pen.strokeColor= Color.grey;
		Pen.line(obj.loc.asPoint, trg.loc.asPoint);
		Pen.stroke;
		Pen.fillColor= Color.red;
		Pen.fillOval(Rect.aboutRedObject2D(trg));
		Pen.fillColor= Color.white;
		Pen.fillOval(Rect.aboutRedObject2D(obj));
	};
	w.animate= true;
	w.onClose = {
		buf.free; snd.free;
	};
	CmdPeriod.doOnce({if(w.isOpen, { w.close })});
)
// 2D - redUniverse: spring and boids
(
	var width= 500, height= 500, w, world, wgrav, obj, trg, mp;
	var springStiff= 0.1, springDamp= 0.9, springLength= 50;
	var boidNum= 50, boidList= List.new;
	var buf, snd, pos;

	//--multichannel setup:
	// 4 channel ring
	buf = VBAPSpeakerArray.new(2, [-45, -135, 135, 45]).loadToBuffer;

	//--sound src
	snd = { arg azimuth= 0, elevation= 0, spread= 0, amp=0.01;
		VBAP.ar(4, PinkNoise.ar(0.2, mul:amp), buf.bufnum, azimuth, elevation, spread);
	}.scope;

	//--world
	w= RedWindow("spring test", Rect(128, 64, width, height)).front;
	mp= w.mouse;
	wgrav= RedVector2D[0, 0.28];
	world= RedWorld1(RedVector2D[width, height], wgrav, 30, 0.8); //dim,grav,maxvel,damp

	//--object & target on spring
	obj= RedObject(world, RedVector2D[0, 0], RedVector2D[0, 0], RedVector2D[0, 0], 1.5, 10);
	trg= RedObject(world, RedVector2D[width*0.5, height*0.5]);
	//--objects: boids
	{
		var loc= RedVector2D[width, height].rand;
		var vel= RedVector2D[0.5, 0.5].rand2;
		var mass= 0.3.rrand(4);
		boidList.add(
			RedBoid(world, loc, vel, RedVector2D[0, 0], mass, mass*3) //world,loc,vel,acc,mass,size
				.maxForce_(2);
			);
	}.dup(boidNum);


	//--loop
	w.draw{
		// spring
		if(mp!=w.mouse, { //just to keep target in middle if no mouse input
			trg.loc= w.mouse;
		});

		obj.spring(trg, springStiff, springDamp, springLength); //target, stiffness, damping, length

		obj.addForce(world.gravity);
		obj.update;
		pos= Complex(
			obj.loc[0].linlin(0, w.bounds.width, 1, -1), // x
			obj.loc[1].linlin(0, w.bounds.height, -1, 1) // y
		);
		snd.set(
			\azimuth, pos.theta.linlin(-pi,pi, -180, 180),
			\spread, pos.magnitude.linlin(0, 1.41, 100, 0)
		);
		world.contain(obj);
		//--render
		Pen.strokeColor= Color.grey;
		Pen.line(obj.loc.asPoint, trg.loc.asPoint);
		Pen.stroke;
		Pen.fillColor= Color.red;
		Pen.fillOval(Rect.aboutRedObject2D(trg));
		Pen.fillColor= Color.white;
		Pen.fillOval(Rect.aboutRedObject2D(obj));


		// boids
		boidList.size.do{|i|
			if(i!=0, {
				//boidList[i].addForceSeek(world.objects[0].loc);
				boidList[i].addForceArrive(world.objects[0].loc, 5);//everybody chase first boid
			}, {
				boidList[0].loc= w.mouse;
			});
			boidList[i].addForce(world.gravity);
			boidList[i].update;
			world.contain(boidList[i]);

			//--render
			Pen.fillColor= Color.grey(1-(i/boidNum), 0.5);
			Pen.fillOval(Rect.aboutRedObject2D(boidList[i]));
		};
	};
	w.animate= true;
	w.onClose = {
		buf.free; snd.free;
	};
	CmdPeriod.doOnce({if(w.isOpen, { w.close })});
)


// 3
// 2D - redUniverse: simple spring controlled with kinect in multichannel



// first do:
// $ cd ~/dev/kinect/OpenNI-Bin-MacOSX-v1.1.0.41/OSCeleton/
// $ ./osceleton -p 57120



(
var width= 500, height= 500, w, world, wgrav, obj, trg, mp;
var springStiff= 0.1, springDamp= 0.95, springLength= 50;
var buf, snd, pos, freq, coords= FloatArray[0, 0];
var responderKinect, responderKinectNewUser, responderKinectLostUser;

//--multichannel setup:
// 4 channel ring
buf = VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]).loadToBuffer;

//--sound src
snd = { arg freq= 440, amp=0.002, azimuth= 0, elevation= 0, spread= 0;
	VBAP.ar(4, LFSaw.ar(freq: freq, mul:amp), buf.bufnum, azimuth, elevation, spread);
}.scope;




//--kinect
responderKinectNewUser = OSCresponderNode(nil, '/new_skel', {arg t, r, msg;
	//msg.postln;
}).add;
responderKinectLostUser = OSCresponderNode(nil, '/lost_skel', {arg t, r, msg;
	//msg.postln;
}).add;
responderKinect = OSCresponderNode(nil, '/joint', {arg t, r, msg;
	var joint;
	joint = msg[1];
	joint.switch(
		'r_hand', {
			coords[0]= msg[3].linlin(0.1, 0.9, 0, width); // x
			coords[1]= msg[5].linlin(1.5, 2.5, 0, height); // depth
			freq= msg[4].linlin(0.01, 0.99, 500, 40); // y
//			msg[5].postln;
			},
		'l_hand', {
			// pass
			}
	);
}).add;



//--world
w= RedWindow("spring test", Rect(128, 64, width, height)).front;
//	mp= w.mouse;
mp= coords;
wgrav= RedVector2D[0, 0.28];
world= RedWorld1(RedVector2D[width, height], wgrav, 30, 0.8); //dim,grav,maxvel,damp

//--objects
obj= RedObject(world, RedVector2D[0, 0], RedVector2D[0, 0], RedVector2D[0, 0], 1.5, 10);
trg= RedObject(world, RedVector2D[width*0.5, height*0.5]);

//--loop
w.draw{
	if(mp!=w.mouse, { //just to keep target in middle if no mouse input
		trg.loc= w.mouse;
	});
	trg.loc= RedVector2D[coords[0], coords[1]];

	obj.spring(trg, springStiff, springDamp, springLength); //target, stiffness, damping, length

	obj.addForce(world.gravity);
	obj.update;
	pos= Complex(
		obj.loc[0].linlin(0, width, 1, -1), // x
		obj.loc[1].linlin(0, height, -1, 1) // y
	);
	snd.set(
		\azimuth, pos.theta.linlin(-pi,pi, -180, 180),
		\spread, pos.magnitude.linlin(0, 1.41, 100, 0),
		\freq, freq
	);
	world.contain(obj);

	//--render
	Pen.strokeColor= Color.grey;
	Pen.line(obj.loc.asPoint, trg.loc.asPoint);
	Pen.stroke;
	Pen.fillColor= Color.red;
	Pen.fillOval(Rect.aboutRedObject2D(trg));
	Pen.fillColor= Color.white;
	Pen.fillOval(Rect.aboutRedObject2D(obj));
};
w.animate= true;
CmdPeriod.doOnce({if(w.isOpen, {



	responderKinectNewUser.remove;
	responderKinectLostUser.remove;
	responderKinect.remove;
	buf.free;
	snd.free;


	w.close;
})});
)


// to-do:
// 1.
// boids - attractor controlled by kinect or in brownian motion (see examples boids2, boids3)
// the motion of a dancer: guiding attractor around, then loosing it, and trying to catch back as it wanders around
// 2.
// the position of the hands in Z axis (up-down) ctrls rate! not linearly, use sections: [-1, -0.8] - rate= , [-0.8, -0.6]




// setup for voice

// synths
(
// mono recording synth
SynthDef(\recsyn_1, { arg inbus, bufnum= 0, amp= 1;
	DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).load(s);

// playback
SynthDef(\playbufphas_1, {
	arg bufnum = 0, busnum = 0, ax, ay, panidx= 0.7, panshift= 0, vol= 1, modf= 1, factor= 0, trigID= 60, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, loop= 0;
	var timescale, ratescale, trig= 1, env, offset, fadeTime = 0.1, speed = 20.0, in, out, updateRate=30, speakerArr, speakerBuff;

//	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid
	speakerArr= VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]); // works in A6
	speakerBuff= speakerArr.loadToBuffer;

	timescale = ax * BufDur.kr(bufnum); // arg X: duration
	ratescale = (ay*1.99)+0.01; // 0..2
	env = Lag.kr(ToggleFF.kr(trig), fadeTime); // one signal to contol which channel is heard
	offset = Phasor.ar(0, timescale * BufRateScale.kr(bufnum), 0, BufFrames.kr(bufnum));
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
	SendTrig.kr(Impulse.kr(updateRate), trigID, Amplitude.kr(out.at(0)));
	SendTrig.kr(Impulse.kr(updateRate), trigID+1, Amplitude.kr(out.at(1)));
	Out.ar(busnum, out);
}).load(s);

// granulating - old
//SynthDef( \granbufphas_1, {
//	arg bufnum = 0, busnum = 0, bufdur, ax, ay, vol, trigID= 60, gate= 0, frate= 1, fpos= 1, fdur= 1, modf= 1, factor= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0;
//	var trate, dur, clk, pos, in, out, updateRate=30, speakerArr, speakerBuff;
//
//	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid
//	speakerBuff= speakerArr.loadToBuffer;
//
//	trate = ay.linlin(0,1, 1,50); //arg Y: trate 0.1..50
//	dur = 4 / trate;
//	clk = Impulse.kr(trate);
//	pos = Integrator.kr(BrownNoise.kr(ax)); //arg X: position control 0..1
//	in= TGrains.ar(
//			numChannels: 2,
//			trigger: clk,
//			bufnum: bufnum,
//			rate: BufRateScale.kr(bufnum) * frate * (LFSaw.kr(modf, 0, 0.5*modf, 440)/440),
//			centerPos: pos * fpos,
//			dur: SelectX.kr(BinaryOpUGen('==', fdur, 1), [fdur, dur ]),
//			amp: 1
//		);
//
//	in= vol *
//		(in[0]
//		+PitchShift.ar(in[0], 0.2, factor, 0.01, factor.linlin(0, 1.5, 0.1, 0.5), factor.linlin(0, 1, 0, 3))
//		+PitchShift.ar(in[0], 0.2, factor.linlin(0,1.5, 0.3,0.7), 0.01, factor.linlin(0, 1.5, 0.1, 0.5), factor.linlin(0, 1, 0, 2))
//		);
//
//	out= VBAP.ar(4, in, speakerBuff.bufnum, azimuth, elevation, spread);
//	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
//
//	SendTrig.kr(Impulse.kr(updateRate), trigID, Amplitude.kr(out.at(0)));
//	SendTrig.kr(Impulse.kr(updateRate), trigID+1, Amplitude.kr(out.at(1)));
//	Out.ar(busnum, out);
//}).load(s);


// granulating - new
SynthDef( \granbufphas_1, {
	arg bufnum= 0, busnum= 0, ax, ay, vol, trigID= 60, gate= 0, frate= 1, fdur= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0;
	var trate, dur, pos, in, out, clk, updateRate=30, speakerArr, speakerBuff;

	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid
	speakerBuff= speakerArr.loadToBuffer;

	trate= frate.linlin(0,5, 0.1,1);
	dur= 4 / trate;
	clk= Impulse.kr(trate);
	//pos= Integrator.kr(BrownNoise.kr(ax));
	pos= ax*BufDur.kr(bufnum); // + TRand.kr(0, 0.01, clk); //arg X: position + rand delta
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum),
		centerPos: pos,
		dur: dur,
		pan: -1, // always left as VBAP requires 1 channel
		amp: vol.linlin(0,1, 0,0.3)
	);

	out= VBAP.ar(4, in[0], speakerBuff.bufnum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );

	SendTrig.kr(Impulse.kr(updateRate), trigID, Amplitude.kr(out.at(0)));
	SendTrig.kr(Impulse.kr(updateRate), trigID+1, Amplitude.kr(out.at(1)));
	Out.ar(busnum, out);
}).load(s);
)

//boids and spring
(
var soundsDir= "~/Music/bibeast/sounds/";
var inBus= 0, isRecording= false;
var recBufStart, recBufStop, startStopSynth, recSynth, currBufnum, currBuffer, currFilename, loadBufTask, synthRightHand, synthLeftHand, granList= List.new;
var winCtrl, btRec, btPlay, btLoop;
var width= 500, height= 500, winSim, world, wgrav, objR, trgR, objL= List.new, mp;
var springStiff= 0.1, springDamp= 0.95, springLength= 50;
var calibMag= 1.41;
var buf, snd, posR, posL, timescale, trate, coordsR= FloatArray[0, 0], coordsL= FloatArray[0, 0], objLNum= 20.0.rand;
var responderKinect, responderKinectNewUser, responderKinectLostUser;

//test window - start
winCtrl= SCWindow("test ctrl", Rect(1200, 800, 200, 100), resizable:false);
btRec= Button(winCtrl, Rect(10, 10, 80, 40))
	.states_([
		["REC", Color.black, Color.white],
		["stop", Color.white, Color.red]
	])
	.canFocus_(false)
	.action_({ |bt|
		if(bt.value == 1, {
			currFilename= soundsDir++"kin_"++Date.getDate.stamp.asString++".aif";
			// count number of buffers to stack them!
			currBufnum= recBufStart.value(inbus: 0, numchannels: 1, path: currFilename);
		}, {
			recBufStop.value(currBufnum);
			currBuffer= Buffer.read(s, currFilename);

			loadBufTask = Task({
				inf.do({ |j|
					if(currBuffer.numChannels != nil, {
						rrand(0.5, 3.0).wait;
						{ startStopSynth.value(currBuffer, loop: btLoop.value); }.defer;
						loadBufTask.stop;
					});
				0.1.wait;
				});
			}).start;
		});
	});

btPlay= Button(winCtrl, Rect(10, 55, 80, 40))
	.states_([
		["play", Color.black, Color.white],
		["stop", Color.white, Color.black]
	])
	.canFocus_(false)
	.action_({ |bt|
		if(bt.value == 1, {
			startStopSynth.value(currBuffer, loop: btLoop.value);
		}, {
			startStopSynth.value(currBuffer, gate: 0);
		});
	});

btLoop= Button(winCtrl, Rect(95, 65, 40, 20))
	.states_([
		["one", Color.black, Color.white],
		["loop", Color.white, Color.black]
	])
	.canFocus_(false);

winCtrl.refresh;
winCtrl.front;
//test window - end




//--kinect
responderKinectNewUser = OSCresponderNode(nil, '/new_skel', {arg t, r, msg;
	//msg.postln;
}).add;
responderKinectLostUser = OSCresponderNode(nil, '/lost_skel', {arg t, r, msg;
	//msg.postln;
}).add;
responderKinect = OSCresponderNode(nil, '/joint', {arg t, r, msg;
	var joint;
	joint = msg[1];
	joint.switch(
		'l_hand', {
			coordsR[0]= msg[3].linlin(0.1, 0.9, 0, width); // x
			coordsR[1]= msg[5].linlin(1.5, 2.5, 0, height); // depth
			timescale= msg[4].linlin(0,1, 1,0); // y
		},
		'r_hand', {
			coordsL[0]= msg[3].linlin(0.1, 0.9, 0, width); // x
			coordsL[1]= msg[5].linlin(1.5, 2.5, 0, height); // depth
			trate= msg[4].linlin(0,1, -2,2); // y
		}
	);
}).add;



//--world
winSim= RedWindow("spring test", Rect(950, 64, width, height)).front;
//	mp= w.mouse;
mp= coordsR;
wgrav= RedVector2D[0, 0.28];
world= RedWorld1(RedVector2D[width, height], wgrav, 30, 0.8); //dim,grav,maxvel,damp

//--objects
//--object & target on spring
objR= RedObject(world, RedVector2D[0, 0], RedVector2D[0, 0], RedVector2D[0, 0], 1.5, 10);
trgR= RedObject(world, RedVector2D[width*0.5, height*0.5]);
//--object: boids
{
	var loc= RedVector2D[width, height].rand;
	var vel= RedVector2D[0.5, 0.5].rand2;
	var mass= 0.3.rrand(4);
	objL.add(
		RedBoid(world, loc, vel, RedVector2D[0, 0], mass, mass*3) //world,loc,vel,acc,mass,size
			.maxForce_(2);
		);
}.dup(objLNum);
//objLNum.do({ |i|
//	[objL[i].mass, objL[i].vel.mag].postln;
//});

//--loop
winSim.draw{
//	if(mp!=w.mouse, { //just to keep target in middle if no mouse input
//		trgR.loc= w.mouse;
//	});

	trgR.loc= RedVector2D[coordsR[0], coordsR[1]];
	objR.spring(trgR, springStiff, springDamp, springLength); //target, stiffness, damping, length

	objR.addForce(world.gravity);
	objR.update;
	posR= Complex(
		objR.loc[0].linlin(0, width, 1, -1), // x
		objR.loc[1].linlin(0, height, -1, 1) // y
	);
	world.contain(objR);

	//--render spring
	Pen.strokeColor= Color.grey;
	Pen.line(objR.loc.asPoint, trgR.loc.asPoint);
	Pen.stroke;
	Pen.fillColor= Color.red;
	Pen.fillOval(Rect.aboutRedObject2D(trgR));
	Pen.fillColor= Color.white;
	Pen.fillOval(Rect.aboutRedObject2D(objR));

	//--boids
	objLNum.do{|i|
		if(i!=0, {
			//objL[i].addForceSeek(objL[0].loc);
			objL[i].addForceArrive(objL[0].loc, 5);//everybody chase first boid
		}, {
			objL[0].loc= RedVector2D[coordsL[0], coordsL[1]];
		});
		objL[i].addForce(world.gravity);
		objL[i].update;
		world.contain(objL[i]);

		//--render
		Pen.fillColor= Color.grey(1-(i/objLNum), 0.5);
		Pen.fillOval(Rect.aboutRedObject2D(objL[i]));
	};
	posL= Complex( // mirroring what is going on with right hand
		objL[0].loc[0].linlin(0, width, -1, 1), // x
		objL[0].loc[1].linlin(0, height, 1, -1) // y
	);

	//controlling synths
	try{
		synthRightHand.set(
			\azimuth, posR.theta.linlin(-pi,pi, -180, 180),
//			\spread, posR.magnitude.linlin(0, 1.41, 100, 0),
			\spread, ( 1-( (posR.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
//			\vol, 1-( (posR.magnitude / calibMag).sqrt ),
			\ay, timescale
		);

		synthLeftHand.set(
			\azimuth, posL.theta.linlin(-pi,pi, -180, 180),
//			\spread, posL.magnitude.linlin(0, calibMag, 100, 0)
			\spread, ( 1-( (posL.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
			\vol, 1-( (posL.magnitude / calibMag).sqrt ) * objL[0].mass.linlin(0,4, 0,1)
		);

		(objLNum-1).do({ |i| // swarm of boids
			var posB;
			posB= Complex(
				objL[i+1].loc[0].linlin(0, width, -1, 1), // x
				objL[i+1].loc[1].linlin(0, height, 1, -1) // y
			);
			granList[i+1].set(
				\azimuth, posB.theta.linlin(-pi,pi, -180, 180),
//				\spread, posB.magnitude.linlin(0, calibMag, 100, 0),
				\spread, ( 1-( (posB.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
				\vol, 1-( (posB.magnitude / calibMag).sqrt ) * objL[i].mass.linlin(0,4, 0,1),
				\ax, objL[i+1].loc[0].linlin(0,width, 0,1)
			);
		});
	};

};
winSim.animate= true;

recBufStart= { arg bnum, inbus, numchannels, path, headformat= 'aiff', bitdepth= 'int16';
	var bufnum;
	bufnum = bnum ? s.bufferAllocator.alloc(1);
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

startStopSynth= { arg buff, bus= 0, vol= 0.02, gate= 1, loop= 0;
	if(gate == 1, {
		synthRightHand=
			Synth(\playbufphas_1, [
				\busnum, bus,
				\bufnum, buff,
				\ax, 0.5, \ay, 0.5,
				\vol, 0, //vol,
				\loop, loop,
				\gate, gate
			], s, \addToHead);
		granList= List.new; // re-initialize list of gran synths
		objLNum.do({ |i| // swarm of boids
			granList.add(
				Synth(\granbufphas_1, [
					\busnum, bus,
					\bufnum, buff,
					\ax, 0.5, \ay, 0.5,
					\frate, objL[i].vel.mag,
					\vol, objL[i].mass.linlin(0,4, 0,1),
					\gate, gate
				], s, \addToHead);
			)
		});
		synthLeftHand= granList[0]; // the leader gran (all the boids chase this one)
	}, {
		synthRightHand.set(\gate, gate);
		objLNum.do({ |i|
			granList[i].set(\gate, gate);
		});
	});
};

winCtrl.onClose({
//	synthRightHand.size.do({ |i|
//		synthRightHand[i].set(\gate, 0);
//	});
	synthRightHand.free;
	//synthLeftHand.free;
	objLNum.do({ |i|
		granList[i].free;
	});
	recSynth.free;




	responderKinectNewUser.remove;
	responderKinectLostUser.remove;
	responderKinect.remove;
	snd.free;


	winSim.close;

});

CmdPeriod.doOnce({
	winCtrl.close;
	winSim.close;
});
)

// spatial example:



SynthDef(\test, {
var src, loc, ienv, rev;
src = PinkNoise.ar(LFSaw.kr(-10, 0, 0.25, 0.25) ** 2);
loc = MouseX.kr(-1, 1);
ienv = IEnvGen.kr(InterplXYC([-1, 0, \sin], [0, 1, \sin], [1, 0]), loc);
src = LPF.ar(src, 100 + (ienv * 4000));
rev = FreeVerb.ar(src, 0.8, 0.6) * (1 - ienv) * 0.2;
Out.ar(0, Pan2.ar(src, loc) * ienv + rev.dup);
}).send(s);


a = Synth(\test);

a.free;
