// 2D - redUniverse: simple spring controlled with kinect in multichannel
// first do:
// $ cd ~/dev/kinect/OpenNI-Bin-MacOSX-v1.1.0.41/OSCeleton/
// $ ./osceleton -p 57120

//ctrls and visualisation
(
var globalFont1= Font("Helvetica", 9), btColorBG = Color.new255(248, 248, 255);
var soundsDir= "~/Music/bibeast/sounds/";
var recBufStart, recBufStop, startSynth, stopSynth, recSynth, currBufnum, currBuffer, currFilename, loadBufTask;
var synLR= [nil, nil], granList;
var winCtrl, cvRec, btRec, btNewObj, btDelObj, btLR= Array.new(2), btLabel= #["L","R"], cvLaunch, cvBuff, lvBuffers, cvObj, lvObj, cvCtrl, btCtrl= Array.new(2), isMouse;
var width= 500, height= 500, winSim, world, wgrav, objR, trgR, objL= List.new, mp;
var springStiff= 0.1, springDamp= 0.95, springLength= 50;
var calibMag= 1.41;
var buf, snd, posR, posL, timescale, trate, coords= [ FloatArray[0, 0], FloatArray[0, 0] ];
var inBus= 0, isRecording= false, channels= 32, chlistMono= Array.fill(channels, nil), monoChList;
// kinect
var responderKinect, responderKinectNewUser, responderKinectLostUser;
//buffers
var bufPool= List.new, updateBuffers;
//objects & synths: playonce controlled by a pos of simple object, loop "hangs" on spring (target), flock is flock
var objSynth= Dictionary[\playonce -> \playbufphas_1, \loop -> \loopbufphas_1, \flock -> \granbufphas_1];
var initObj, delObj, objGrab= [nil, nil], objPos= [nil, nil]; // what is grabbed by hand and what controls the position of sound
var population= [5, 5], flockArr; // re-assigned for every new flock
var currObjType= [nil, nil];
//MIDI
var ccResp;

channels.do({ |i|
	chlistMono.put(i, i.asSymbol);
});

// default containers for L & R flocks
flockArr= [ Array.fill(population[0], { nil }), Array.fill(population[1], { nil }) ];
granList= [ Array.fill(population[0], { nil }), Array.fill(population[1], { nil }) ];

//test window - start
winCtrl= SCWindow("test ctrl", Rect(1170, 800, 350, 200), resizable:false);

cvRec= CompositeView(winCtrl, Rect(10, 10, 120, 80))
	.background_(Color.gray(alpha:0.6));

btRec= Button(cvRec, Rect(20, 10, 80, 40))
	.states_([
		["REC", Color.black, Color.white],
		["stop", Color.white, Color.red]
	])
	.canFocus_(false)
	.action_({ |bt|
		if(bt.value == 1, {
			currFilename= soundsDir++"kin_"++Date.getDate.stamp.asString++".aif";
			currBufnum= recBufStart.value(inbus: monoChList.value, numchannels: 1, path: currFilename);
		}, {
			recBufStop.value(currBufnum);
			currBuffer= Buffer.read(s, currFilename);

			loadBufTask= Task({
				inf.do({ |j|
					if(currBuffer.numChannels != nil, {
						bufPool.add(currBuffer); // add to the pool
						{ updateBuffers.value(bufPool) }.defer;
						loadBufTask.stop;
					});
				0.1.wait;
				});
			}).start;
		});
	});

monoChList= PopUpMenu(cvRec, Rect(20, 55, 50, 15))
	.background_(btColorBG)
	.canFocus_(false)
	.font_(globalFont1)
	.items_(chlistMono)
	.value_(30)
	.action_({ |pm|
		if(recSynth != nil, { recSynth.set(\inbus, pm.value) });
});

cvLaunch= CompositeView(winCtrl, Rect(10, 100, 120, 80))
	.background_(Color.gray(alpha:0.6));

btNewObj= Button(cvLaunch, Rect(10, 10, 100, 20))
	.states_([
		["new obj", Color.black, Color.white]
	])
	.canFocus_(false)
	.action_({ |bt|
		initObj.value( btLR[1].value, lvObj.items[lvObj.value] );
		try{
			startSynth.value( bufPool[lvBuffers.value], lr: btLR[1].value, objtype: lvObj.items[lvObj.value] );
		};
	});

btDelObj= Button(cvLaunch, Rect(10, 55, 100, 20))
	.states_([
		["del obj", Color.black, Color.white]
	])
	.canFocus_(false)
	.action_({ |bt|
		delObj.value(btLR[1].value);
		stopSynth.value(10.0.rand, btLR[1].value);
	});

2.do({ |i|
	btLR.add(
		Button(cvLaunch, Rect(80*i+10, 32, 20, 20))
			.value_(0)
			.canFocus_(false)
			.states_([
				[ btLabel[i], Color.black, Color.white ],
				[ btLabel[i], Color.white, Color.black ]
			])
			.action_({ |bt|
				btLR[1-i].value= 1-bt.value;
			})
	);
});
btLR[ [0,1].choose ].valueAction_(1); //sthn has to be the first one

cvBuff= CompositeView(winCtrl, Rect(140, 10, 120, 80))
	.background_(Color.gray(alpha:0.6));

lvBuffers= ListView.new(cvBuff, Rect(5, 5, cvBuff.bounds.width-10, cvBuff.bounds.height-10))
	.canFocus_(false) .font_(globalFont1);

cvObj= CompositeView(winCtrl, Rect(140, 100, 120, 80))
	.background_(Color.gray(alpha:0.6));

lvObj= ListView.new(cvObj, Rect(5, 5, cvObj.bounds.width-10, cvObj.bounds.height-10))
	.font_(globalFont1) .canFocus_(false) .items_(objSynth.keys.asArray);

cvCtrl= CompositeView(winCtrl, Rect(270, 100, 50, 80))
	.background_(Color.gray(alpha:0.6));

2.do({ |i|
	btCtrl.add(
		Button(cvCtrl, Rect(5, 20*i+10, 40, 15))
			.font_(globalFont1) .canFocus_(false)
			.states_([
				[ [\mouse, \hands][i], Color.black, Color.white ],
				[ [\mouse, \hands][i], Color.white, Color.black ]
			])
			.action_({ |bt|
				btCtrl[1-i].value= 1-bt.value;
				isMouse= btCtrl[0].value.booleanValue;
			})
	);
});
btCtrl[1].valueAction_(1); //mouse is default

winCtrl.refresh;
winCtrl.front;
//test window - end

//--kinect
responderKinectNewUser= OSCresponderNode(nil, '/new_skel', {arg t, r, msg;
	msg.postln;
}).add;
responderKinectLostUser= OSCresponderNode(nil, '/lost_skel', {arg t, r, msg;
	msg.postln;
}).add;
responderKinect= OSCresponderNode(nil, '/joint', {arg t, r, msg;
	var joint;
	joint= msg[1];
	joint.switch(
		'r_hand', { // mirroring hands!
			coords[0][0]= msg[3].linlin(0.1, 0.9, 0, width); // x
			coords[0][1]= msg[5].linlin(1.5, 2.5, 0, height); // depth
			timescale= msg[4].linlin(0,1, 1,0); // y
		},
		'l_hand', {
			coords[1][0]= msg[3].linlin(0.1, 0.9, 0, width); // x
			coords[1][1]= msg[5].linlin(1.5, 2.5, 0, height); // depth
			trate= msg[4].linlin(0,1, -2,2); // y
		}
	);
}).add;

//--world
winSim= RedWindow("spring test", Rect(950, 64, width, height)).front;
//	mp= w.mouse;
mp= coords[1];
wgrav= RedVector2D[0, 0.28];
world= RedWorld1(RedVector2D[width, height], wgrav, 30, 0.8); //dim,grav,maxvel,damp
//--objects
initObj= { |lr= 0, type| //lr: left=0, right= 1
	var loc, vel, mass;
	currObjType[lr]= type;

	if( objGrab[lr] != nil, { objGrab[lr].free; objGrab[lr]= nil });

	type.switch(
		\playonce, { //--simple object: grab and the position of sound controlled by the same object
			try{ objGrab[lr].free; objPos[lr].free }; // first clear existing objects
			objGrab[lr]= RedObject(world, RedVector2D[0, 0], RedVector2D[0, 0], RedVector2D[0, 0], 1.5, 10);
			objPos[lr]= objGrab[lr];
			world.contain(objGrab[lr]);
		},
		\loop, { //--object controlled by hand & target on spring controlling sound pos
			try{ objGrab[lr].free; objPos[lr].free };
			objGrab[lr]= RedObject(world, RedVector2D[0, 0], RedVector2D[0, 0], RedVector2D[0, 0], 1.5, 10);
			objPos[lr]= RedObject(world, RedVector2D[width*0.5, height*0.5]);
			world.contain(objGrab[lr]);
		},
		\flock, { //--flock of boids
			// first clear existing boids, if there are any
			population[lr].do({ |cnt| try { flockArr[lr].free } });
			population[lr]= rrand(5, 15);
			flockArr[lr]= Array.fill(population[lr], { nil });
			population[lr].do({ |i|
				loc= RedVector2D[width, height].rand;
				vel= RedVector2D[0.5, 0.5].rand2;
				mass= 0.3.rrand(4);

				flockArr[lr][i]= RedBoid(world, loc, vel, RedVector2D[0, 0], mass, mass*3) //world,loc,vel,acc,mass,size
					.maxForce_(2);
				flockArr[lr][i].update;
			});
			flockArr[lr][0].loc= RedVector2D[coords[lr][0], coords[lr][1]];
			world.contain(flockArr[lr][0]);

			objGrab[lr]= flockArr[lr][0];
			objPos[lr]= objGrab[lr]; // position is calculated differently for a flock, but need a default
		}
	);
	objGrab[lr].addForce(world.gravity);
	objGrab[lr].loc= RedVector2D[coords[lr][0], coords[lr][1]];
	objGrab[lr].update;
};

delObj= { |lr|
	currObjType[lr].switch(
		nil, { },
		\playonce, {
			objGrab[lr].free;
		},
		\loop, { //--render spring
			objGrab[lr].free; objPos[lr].free;
		},
		\flock, {
			population[lr].do({ |j| //--render flock
				if(j != 0, {
					flockArr[lr][j].free;
				});
				flockArr[lr][0].free;
			});
		}
	);
	objGrab[lr]= nil; objPos[lr]= nil;
};

//--loop
winSim.draw{
	if(isMouse, { // only "one hand", let's say, left one
		coords[0]= winSim.mouse;
	});
	2.do({ |i| // 0 and 1 - left and right hand

		if(objGrab[i] != nil, {
			objGrab[i].loc= RedVector2D[coords[i][0], coords[i][1]];

			currObjType[i].switch(
				nil, { },
				\playonce, { //--render object
					Pen.strokeColor= Color.grey;
					Pen.line(objGrab[i].loc.asPoint, objGrab[i].loc.asPoint);
					Pen.stroke;
					Pen.fillColor= Color.white;
					Pen.fillOval(Rect.aboutRedObject2D(objGrab[i]));
				},
				\loop, { //--render spring
					objPos[i].spring(objGrab[i], springStiff, springDamp, springLength);
					objPos[i].addForce(world.gravity);
					objPos[i].update;
					world.contain(objPos[i]);

					Pen.strokeColor= Color.grey;
					Pen.line(objGrab[i].loc.asPoint, objPos[i].loc.asPoint);
					Pen.stroke;
					Pen.fillColor= Color.red;
					Pen.fillOval(Rect.aboutRedObject2D(objPos[i]));
					Pen.fillColor= Color.white;
					Pen.fillOval(Rect.aboutRedObject2D(objGrab[i]));
				},
				\flock, {
					population[i].do{ |j| //--render flock
						if(j != 0, {
							flockArr[i][j].addForceArrive(flockArr[i][0].loc, 5);//everybody chase first boid
						});
						flockArr[i][j].addForce(world.gravity);
						flockArr[i][j].update;
						world.contain(flockArr[i][j]);

						Pen.fillColor= Color.grey(1-(i/population[i][j]), 0.5);
						Pen.fillOval(Rect.aboutRedObject2D(flockArr[i][j]));
					};
				}
			);
		});
	});

	posL= [0, 0]; posR= [0, 0];

	//objects coordinates
	try{
		posL= Complex( // mirroring what is going on with right hand
			objPos[0].loc[0].linlin(0, width, 1, -1), // x
			objPos[0].loc[1].linlin(0, height, -1, 1) // y
		);
	};

	try{
		posR= Complex(
			objPos[1].loc[0].linlin(0, width, 1, -1), // x
			objPos[1].loc[1].linlin(0, height, -1, 1) // y
		);
	};

	//controlling synths
	if(synLR[0] != nil, {
		synLR[0].set(
			\azimuth, posL.theta.linlin(-pi,pi, -180, 180),
//			\spread, posR.magnitude.linlin(0, 1.41, 100, 0),
			\spread, ( 1-( (posL.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
//			\vol, 1-( (posR.magnitude / calibMag).sqrt ),
			\ay, timescale
		)
	});

	if(synLR[1] != nil, {
		synLR[1].set(
			\azimuth, posR.theta.linlin(-pi,pi, -180, 180),
//			\spread, posR.magnitude.linlin(0, 1.41, 100, 0),
			\spread, ( 1-( (posR.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
//			\vol, 1-( (posR.magnitude / calibMag).sqrt ),
			\ay, timescale
		)
	});

	(population[0]-1).do({ |i| // swarm of boids
		var posB;
		try {
			if(granList[0][i+1] != nil, {
				posB= Complex(
					flockArr[0][i+1].loc[0].linlin(0, width, -1, 1), // x
					flockArr[0][i+1].loc[1].linlin(0, height, 1, -1) // y
				);
				granList[0][i+1].set(
					\azimuth, posB.theta.linlin(-pi,pi, -180, 180),
	//				\spread, posB.magnitude.linlin(0, calibMag, 100, 0),
					\spread, ( 1-( (posB.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
//					\vol, 1-( (posB.magnitude / calibMag).sqrt ) * flockArr[0][i].mass.linlin(0,4, 0,1),
					\ax, flockArr[0][i+1].loc[0].linlin(0,width, 0,1)
				);
			});
		};
	});

	(population[1]-1).do({ |i| // swarm of boids
		var posA;
		try {
			if(granList[1][i+1], {
				posA= Complex(
					flockArr[1][i+1].loc[0].linlin(0, width, -1, 1), // x
					flockArr[1][i+1].loc[1].linlin(0, height, 1, -1) // y
				);
				granList[1][i+1].set(
					\azimuth, posA.theta.linlin(-pi,pi, -180, 180),
//					\spread, posA.magnitude.linlin(0, calibMag, 100, 0),
					\spread, ( 1-( (posA.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
//					\vol, 1-( (posA.magnitude / calibMag).sqrt ) * flockArr[1][i].mass.linlin(0,4, 0,1),
					\ax, flockArr[1][i+1].loc[0].linlin(0,width, 0,1)
				);
			});
		};
	});
};
winSim.animate= true;

updateBuffers= { |bPool|
	var filenameList= List.new;
	bPool.size.do({ |i| filenameList.add(bPool[i].path.basename) });
	lvBuffers.items_(filenameList.asArray);
	lvBuffers.value_(lvBuffers.items.size-1);
};

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

startSynth= { arg buff, bus= 0, vol= 1, gate= 1, lr= 0, objtype= nil;
	if(gate == 1, {
		objtype.switch(
			nil, { },

			\playonce, {
				if(synLR[lr] != nil, { synLR[lr].set(\gate, 0); synLR[lr]= nil });
				synLR[lr]= Synth(\playbufphas_1, [
					\busnum, bus,
					\bufnum, buff,
					\ax, 0.5, \ay, 0.5,
					\vol, 0.8,
					\gate, gate
				], s, \addToHead);
			},

			\loop, {
				if(synLR[lr] != nil, { synLR[lr].set(\gate, 0); synLR[lr]= nil });
				synLR[lr]= Synth(\loopbufphas_1, [
					\busnum, bus,
					\bufnum, buff,
					\ax, 0.5, \ay, 0.5,
					\vol, 0.8,
					\gate, gate
				], s, \addToHead);
			},

			\flock, {
				if(granList[lr].size > 0, { granList[lr].size.do({ |i| granList[lr][i].set(\gate, 0)}) });
				granList[lr]= Array.fill(population[lr], { nil }); // re-initialize list of gran synths
				population[lr].do({ |i| // swarm of boids
					granList[lr][i]= Synth(\granbufphas_1, [
						\busnum, bus,
						\bufnum, buff,
						\ax, 0.5, \ay, 0.5,
						\frate, flockArr[lr][i].vel.mag,
						\vol, flockArr[lr][i].mass.linlin(0,4, 0,1),
						\gate, gate
					], s, \addToHead);
				});
				synLR[lr]= granList[lr][0]; // the leader gran (all the boids chase this one)
			}
		);
	});
};

stopSynth= { arg reltime, lr;
	currObjType[lr].switch(
		nil, { },

		\playonce, {
			if( synLR[lr] != nil, {synLR[lr].set(\rel, reltime, \gate, 0)} );
			synLR[lr]= nil;
		},

		\loop, {
			if( synLR[lr] != nil, {synLR[lr].set(\rel, reltime, \gate, 0)} );
			synLR[lr]= nil;
		},

		\flock, {
			if( synLR[lr] != nil, {synLR[lr].set(\rel, reltime, \gate, 0)} );
			synLR[lr]= nil;
			population[lr].do({ |i| // swarm of boids
				granList[lr][i].set(\rel, reltime + bilinrand(5.0), \gate, 0);
			});
		}
	);
};

MIDIClient.init; // intialize the client
13.do({ arg i; MIDIIn.connect(i, MIDIClient.sources.at(i)); });
ccResp= CCResponder({ |src, chan, num, val|
	[src,chan,num,val].postln;
	num.switch(
		14, { //record
			{ btRec.valueAction_(1-btRec.value) }.defer;
		},
		87, { //new obj - left
			{ btLR[0].valueAction_(1); btNewObj.valueAction_(1); }.defer;
		},
		89, { //new obj - right
			{ btLR[1].valueAction_(1); btNewObj.valueAction_(1); }.defer;
		},
		90, { //del obj - left
			{ btLR[0].valueAction_(1); btDelObj.valueAction_(1); }.defer;
		},
		119,{ //del obj - right
			{ btLR[1].valueAction_(1); btDelObj.valueAction_(1); }.defer;
		},
		118,{ //navigation through synths
			{
				lvObj.value= if(lvObj.value < (lvObj.items.size-1), { lvObj.value+1 }, { 0 } );
			}.defer;
		},
		85,{ //navigation through samples - up
			{
				lvBuffers.value.postln;
				if(lvBuffers.items.size > 1, {
					lvBuffers.value= if(lvBuffers.value > 0, { lvBuffers.value-1 }, { lvBuffers.items.size-1 } );
				});
			}.defer;
		},
		88,{ //navigation through samples - down
			{
				lvBuffers.value.postln;
				if(lvBuffers.items.size > 1, {
					lvBuffers.value= if(lvBuffers.value < (lvBuffers.items.size-1), { lvBuffers.value+1 }, { 0 } );
				});
			}.defer;
		}
	);
	},
	nil, nil, nil, nil // X-Session
);

winCtrl.onClose({
	2.do({ |i|
		if(synLR[i] != nil, { synLR[i].set(\gate, 0); synLR[i]= nil });
		if(granList[i].size > 0, { granList[i].size.do({ |j| granList[i][j].set(\gate, 0)}) });
	});
	recSynth.free;

	responderKinectNewUser.remove;
	responderKinectLostUser.remove;
	responderKinect.remove;
	ccResp.remove;
	snd.free;
	winSim.close;

});

CmdPeriod.doOnce({
	winCtrl.close;
	winSim.close;
});
)



// to-do:
// 1.
// the motion of a dancer: guiding attractor around, then loosing it, and trying to catch back as it wanders around
// 2.
// the position of the hands in Z axis (up-down) ctrls rate! not linearly, use sections: [-1, -0.8] - rate= , [-0.8, -0.6]


// synths
(
// mono recording synth
SynthDef(\recsyn_1, { arg inbus, bufnum= 0, amp= 1;
	DiskOut.ar(bufnum, Limiter.ar(amp * InFeedback.ar(inbus, 1), 0.99, 0.01) );
}).load(s);

// playback
SynthDef(\playbufphas_1, {
	arg bufnum= 0, busnum= 0, ax, ay, panidx= 0.7, panshift= 0, vol= 1, modf= 1, factor= 0, trigID= 60, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, loop= 0;
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
	SendTrig.kr(Impulse.kr(updateRate), trigID, Amplitude.kr(out.at(0)));
	SendTrig.kr(Impulse.kr(updateRate), trigID+1, Amplitude.kr(out.at(1)));
	Out.ar(busnum, out);
}).load(s);

// playback
SynthDef(\loopbufphas_1, {
	arg bufnum= 0, busnum= 0, ax, ay, panidx= 0.7, panshift= 0, vol= 1, modf= 1, factor= 0, trigID= 60, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, loop= 1;
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
	SendTrig.kr(Impulse.kr(updateRate), trigID, Amplitude.kr(out.at(0)));
	SendTrig.kr(Impulse.kr(updateRate), trigID+1, Amplitude.kr(out.at(1)));
	Out.ar(busnum, out);
}).load(s);

// granulating
SynthDef( \granbufphas_1, {
	arg bufnum= 0, busnum= 0, ax, ay, vol, trigID= 60, gate= 0, frate= 1, fdur= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0;
	var trate, dur, pos, in, out, clk, updateRate=30, speakerArr, speakerBuff;

	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid
//	speakerArr= VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]); // works in A6
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
