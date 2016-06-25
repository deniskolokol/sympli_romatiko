

// 2D - redUniverse: simple spring controlled with kinect in multichannel



// first do:
// $ cd ~/dev/kinect/OpenNI-Bin-MacOSX-v1.1.0.41/OSCeleton/
// $ ./osceleton -p 57120



//ctrls and visualisation
(


var fontSmall= Font("Helvetica", 9), fontLarge= Font("Helvetica", 16), btColorBG = Color.new255(248, 248, 255);
var soundsDir= "~/Music/bibeast/sounds/";
var recBufStart, recBufStop, startSynth, stopSynth, recSynth, currBufnum, currBuffer, currFilename, loadBufTask, groupWorld;
var synLR= [nil, nil], granList;
var winCtrl, cvRec, btRec, btNewObj, btDelObj, btLR= Array.new(2), btLabel= #["L","R"], cvLaunch, cvBuff, lvBuffers, cvObj, lvObj, cvCtrl, btCtrl= Array.new(2), isMouse, cvSched, btSched, liWait, liRec, stKey, stSteps;
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


var objSynth= [\playonce, \loop, \flock, \particle, \audioin];
var initObj, initGuideObj, delObj, delGuideObj, objGrab= [nil, nil], objPos= [nil, nil]; // what is grabbed by hand and what controls the position of sound
var population= [5, 5], flockArr, particleSys= [nil, nil], particle, partSyn= (), currPartPos; // re-assigned for every new obj
var currObjType= [nil, nil];


//routine


var groupSched, showProgress;



var routEvents, msetKey, msetWait, rectime;
var totalTime= 0, cycles= rrand(30, 50);


var synNoisy, objNoisy= nil, wind, posNoisy, rp, cnt= 0;


//MIDI


var ccResp;

channels.do({ |i|
	chlistMono.put(i, i.asSymbol);
});



// default containers for L & R flocks
flockArr= [ Array.fill(population[0], { nil }), Array.fill(population[1], { nil }) ];
granList= [ Array.fill(population[0], { nil }), Array.fill(population[1], { nil }) ];

//--ctrl window
winCtrl= SCWindow("ctrls", Rect(1170, 800, 350, 300), resizable:false);



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
				var hand, objtype;
				inf.do({ |j|
					if(currBuffer.numChannels != nil, {
						bufPool.add(currBuffer); // add to the pool
						{
							updateBuffers.value(bufPool);
							// launch a new synth and object if in schedule mode
							if(btSched.value == 1, {
								hand= [0,1].choose;
								objtype= lvObj.items[lvObj.value]; // random pick instead of lvObj.items[lvObj.value] !!!
								initObj.value( btLR[hand].value, objtype );
								try{
									startSynth.value( bufPool[lvBuffers.value], lr: hand, objtype: objtype );
								};
							});
						}.defer;
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
	.font_(fontSmall)
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
	.canFocus_(false) .font_(fontSmall)
	.action_({ |lv|
		currBufnum= bufPool[lvBuffers.value] ? 1; // actual buf num for particles
	});





cvObj= CompositeView(winCtrl, Rect(140, 100, 120, 120))
	.background_(Color.gray(alpha:0.6));





lvObj= ListView.new(cvObj, Rect(5, 5, cvObj.bounds.width-10, cvObj.bounds.height-10))
	.font_(fontSmall) .canFocus_(false) .items_(objSynth);



cvCtrl= CompositeView(winCtrl, Rect(270, 100, 50, 40))


	.background_(Color.gray(alpha:0.6));



2.do({ |i|
	btCtrl.add(
		Button(cvCtrl, Rect(5, 15*i+5, 40, 15))
			.font_(fontSmall) .canFocus_(false)
			.states_([
				[ [\mouse, \kinect][i], Color.black, Color.white ],
				[ [\mouse, \kinect][i], Color.white, Color.black ]
			])
			.action_({ |bt|
				btCtrl[1-i].value= 1-bt.value;
				isMouse= btCtrl[0].value.booleanValue;
			})
	);
});
btCtrl[1].valueAction_(1); //mouse is default

cvSched= CompositeView(winCtrl, Rect(10, 190, 120, 80))
	.background_(Color.gray(alpha:0.6));



btSched= Button(cvSched, Rect(5, 5, 40, 30))


	.canFocus_(false)
	.states_([
		[ \sched, Color.black, Color.white ],
		[ \stop, Color.white, Color.red ]
	])
	.action_({ |bt|
		if(bt.value==1, {
			groupSched= Group.new(s);
			routEvents.play;
		}, {
			groupSched.free;
			routEvents.stop;
		});
	});



StaticText(cvSched, Rect(50, 5, 30, 15))
	.string_("key")
	.font_(fontSmall);
stKey= StaticText(cvSched, Rect(85, 1, 30, 20))
	.font_(fontLarge);

StaticText(cvSched, Rect(50, 25, 30, 15))
	.string_("steps")
	.font_(fontSmall);
stSteps= StaticText(cvSched, Rect(85, 15, 30, 30))
	.font_(fontLarge);

StaticText(cvSched, Rect(5, 40, 30, 15))
	.string_("wait")
	.font_(fontSmall);
liWait= LevelIndicator(cvSched, Rect(25, 40, 90, 17))
	.canFocus_(false) .value_(0) .warning_(0.7) .critical_(0.9);

StaticText(cvSched, Rect(5, 60, 30, 15))
	.string_("rec")
	.font_(fontSmall);
liRec= LevelIndicator(cvSched, Rect(25, 60, 90, 17))
	.canFocus_(false) .value_(0) .warning_(0.7) .critical_(0.9);

groupWorld= Group.new(s); // creating the group for synths connected to objects

winCtrl.refresh;
winCtrl.front;


//--ctrl window

//--routine



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

routEvents= Routine.new({
	var keySteps, key, waitKey, wait, midinote, ns;

	var resArr= [ List.new(), List.new() ];

	cycles.do({ |i|
		key= msetWait.dict.keys.asArray.choose;
		keySteps= msetKey.next(\n);
//		postf("---\nkey: %\tsteps: %\n", key, keySteps);

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

//			postf("%:% - wait time: %\trec time: %\t\tmidinote: %\n", i, j, wait, rectime, midinote);

			Synth.head(groupSched, \rec_start, [ \pan, 1.0.bilinrand, \freq, 1300+130.0.bilinrand ]);
			synNoisy= Synth.head(groupSched, \noisy, [ \freq, rrand(24, 240), \amp, rrand(0.01, 0.1), \att, 0.5.rand ]); // hold the noise while recording
			initGuideObj.value(\noisy); // noisy obj can also move

			{ // activate indicators
				stKey.string= key.toUpper; // current key
				stSteps.string= keySteps-j; // remaining steps
				btRec.valueAction_(1); // start recording into buffer
				showProgress.value(rectime, ind: liRec); // recording (in quaters of a second, default)
				showProgress.value(wait, 1, liWait); // waiting (in seconds)
			}.defer;

			rectime.wait;

			synNoisy.set(\gate, 0, \rel, 2.0.rand);
			synNoisy= nil;
			Synth.head(groupSched, \ev_start, [ \note, midinote ]);

			(wait-rectime).max(0.1).wait;
//
//			0.001.wait;
		});
		0.001.wait;
	});
	0.001.wait;
//	postf("---\ncycles: %\ttotal min: %\n", cycles, totalTime/60);
	{
		Plotter("markov chain", Rect(600, 30, 1000, 400))
			.superpose_(true)
			.plotMode_(\plines)
			.value= resArr;
	}.defer;
});

showProgress= { arg time, quant= 0.25, ind;
	var routRec, cnt, sp;

	ind.value= 0;
	cycles = round(time/quant).max(1);
	sp = [0, cycles, \lin].asSpec;

	routRec = Routine({
		cycles.do({ |i|
			cnt = i+1;
			ind.value= sp.unmap(cnt);
			quant.wait;
		});
		if(ind.value < 1, { ind.value= 1 });
		if(btRec.value == 1, { btRec.valueAction_(0) }); // stop recording
		delGuideObj.value(\noisy);
	}).play(AppClock);
};


//--routine end




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
//--kinect end



//--world
winSim= RedWindow("tracking", Rect(950, 20, width, height)).front;
mp= coords[1];
wgrav= RedVector2D[0, 0.28];
world= RedWorld3(RedVector2D[width, height], wgrav, 30, 0.8); //dim, grav, maxvel, damp
rp= RedPerlin.new;
//----objects
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
		\audioin, { //--simple object for SoundIn: grab and the position controlled by the same object
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



		},
		\particle, { //--particle system
			try { particleSys[lr].free };
			particleSys[lr]= RedParticleSystem.new;
			particleSys[lr].removeAction= { |o| partSyn.at(o.hash).release }; //free synth when particle dies
			// in case of particle system pos and grab are the same, created artificially to have obj.loc


			objGrab[lr]= RedObject(world, RedVector2D[0, 0], RedVector2D[0, 0], RedVector2D[0, 0], 0.5, 5);
			objPos[lr]= objGrab[lr];



		}
	);
	objGrab[lr].addForce(world.gravity);
	objGrab[lr].loc= RedVector2D[coords[lr][0], coords[lr][1]];
	objGrab[lr].update;


};

initGuideObj= { |type| //lr: left=0, right= 1



	type.switch(
		\noisy, { //--noisy synth: background for recording
			if(objNoisy != nil, { objNoisy.free; objNoisy= nil }); // first clear existing objects
			objNoisy= RedObject(world, RedVector2D[width, height].rand, RedVector2D[1, 1].rand, RedVector2D[0, 0], 1.5, 10);
		}
	);


};

delObj= { |lr|



	currObjType[lr].switch(
		nil, { },
		\playonce, {
			objGrab[lr].free;


		},
		\audioin, {
			objGrab[lr].free;
		},
		\loop, {



			objGrab[lr].free; objPos[lr].free;


		},
		\flock, {
			population[lr].do({ |j|
				if(j != 0, {
					flockArr[lr][j].free;
				});
				flockArr[lr][0].free;
			});
		},



		\particle, { //--particle system
			particleSys[lr].do{ |o| partSyn.at(o.hash).free };
			particleSys[lr].free; particleSys[lr]= nil;
			objGrab[lr].free;
		}


	);
	objGrab[lr]= nil; objPos[lr]= nil;
};

delGuideObj= { |type|



	type.switch(
		nil, { },
		\noisy, { //--noisy guide
			if( objNoisy != nil, { objNoisy.free });
		}


	);
};

//----loop
winSim.draw{
	cnt= if(cnt > 400, { 0 }, { cnt+1 } );
	if(isMouse, { // only "one hand", let's say, left one
		coords[0]= winSim.mouse;
	});

	world.gravity= RedVector2D.newFrom(coords[0]/([width, height]) - 0.5);
	2.do({ |i| // 0 and 1 - left and right hand
		if(objGrab[i] != nil, {
			objGrab[i].loc= RedVector2D[coords[i][0], coords[i][1]];




			currObjType[i].switch(
				nil, { },
				\playonce, { //--render object


					Pen.fillColor= Color.white;
					Pen.fillOval(Rect.aboutRedObject2D(objGrab[i]));
				},



				\audioin, { //--render object


					Pen.fillColor= Color.red;
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
				},
				\particle, {
					//--object with loc from where particles emerge
					Pen.fillColor= Color.white;
					Pen.fillOval(Rect.aboutRedObject2D(objGrab[i]));
					//--add new particles and update old
					particle= RedParticle( world, objGrab[i].loc + 5.rand2, 0, RedVector2D[2.rand2, 10.rand], 1.5, 5.rand).age_( 40.rrand(50) );
					particleSys[i].add( particle );
					partSyn.put( particle.hash, //WARNING!! should be another synth for particles, the same as in gran wave!! otherwise there's no any particular effect
						Synth.head(groupWorld, \loopbufgran_1, [
							\bufnum, currBuffer,
							\rate, 1,
							\vol, 1,
							\dur, (particle.age/50)
						])
					);
					particleSys[i].addForce(world.gravity);
					particleSys[i].update;

					//--render
					particleSys[i].do{|o| //iterate all particles in the system
						Pen.fillColor= Color.grey((o.age/50), 1);
						Pen.fillOval(Rect.aboutRedObject2D(o));
					};
				};
			);
		});
	});

	// process \noisy synth
	if(objNoisy != nil, {
		Pen.fillColor= Color.blue;
		Pen.fillOval(Rect.aboutRedObject2D(objNoisy));
		// RedPerlin continuosly changing noisy obj position
//		wind= switch([0, 1, 2].choose) //wind blowing
//			{ 0 } { 0.5*sin(2pi*(cnt/400)) }
//			{ 1 } { 0.5*cos(2pi*(cnt/400)) }
//			{ 2 } { atan(pi*(cnt/400)) };
//
//		wind.postln;

		wind= rp.noise1D(cnt/400, 0.75, 9, 1);

		objNoisy.addForce(wind);
		objNoisy.addForce(world.gravity);
		objNoisy.update;
		world.contain(objNoisy);

		posNoisy= Complex(
			objNoisy.loc[0].linlin(0, width, 1, -1), // x
			objNoisy.loc[1].linlin(0, height, -1, 1) // y
		);

		if( synNoisy != nil, {
			synNoisy.set(
				\azimuth, posNoisy.theta.linlin(-pi,pi, -180, 180),
//				\spread, posR.magnitude.linlin(0, 1.41, 100, 0),
				\spread, ( 1-( (posNoisy.magnitude / calibMag).pow(0.33) ) )*100 // exp shift: slower spread
			)
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
			\vol, (posL.magnitude / calibMag).sqrt
//			\ay, timescale
		)
	});

	if(synLR[1] != nil, {
		synLR[1].set(
			\azimuth, posR.theta.linlin(-pi,pi, -180, 180),
//			\spread, posR.magnitude.linlin(0, 1.41, 100, 0),
			\spread, ( 1-( (posR.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
			\vol, (posR.magnitude / calibMag).sqrt
//			\ay, timescale
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
					\vol, (posB.magnitude / calibMag).sqrt * flockArr[0][i].mass.linlin(0,4, 0,1),
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
					\vol, (posA.magnitude / calibMag).sqrt * flockArr[1][i].mass.linlin(0,4, 0,1),
					\ax, flockArr[1][i+1].loc[0].linlin(0,width, 0,1)
				);
			});
		};
	});

	2.do({ |lr|
		if(particleSys[lr] != nil, {
			particleSys[lr].do{ |o| //iterate all particles
				currPartPos= Complex( // mirroring what is going on with right hand
					o.loc[0].linlin(0, width, 1, -1), // x
					o.loc[1].linlin(0, height, -1, 1) // y
				);

				partSyn.at(o.hash).set( //find corresponding synth and set params
					\azimuth, currPartPos.theta.linlin(-pi,pi, -180, 180),
		//			\spread, posB.magnitude.linlin(0, calibMag, 100, 0),
					\spread, ( 1-( (currPartPos.magnitude / calibMag).pow(0.33) ) )*100, // exp shift: slower spread
					\vol, (1/40)*(o.age/50)*(o.vel.mag/10),
					\rate, (o.age/50).linlin(0,1,1,1+bilinrand(0.2));
				)
			};
		});
	})
};
winSim.animate= true;
//--world

//--func
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

startSynth= { arg buff= currBufnum, bus= 0, vol= 1, gate= 1, lr= 0, objtype= nil;
	try { stopSynth.value(2.0.rand, lr) }; // first stopping active synth, if any
	objtype.switch(
		nil, { },




		\playonce, {


			synLR[lr]= Synth.head(groupWorld, \playbufphas_1, [
				\busnum, bus,
				\bufnum, buff,
				\ax, 0.5, \ay, 0.5,
				\vol, 0.8,
				\gate, gate
			], s, \addToHead);
		},

		\audioin, {
			synLR[lr]= Synth.head(groupWorld, \audioin_1, [
				\busnum, bus,
				\inbusnum, monoChList.value,
				\ax, 0.5, \ay, 0.5,
				\vol, 0.8,
				\gate, gate
			], s, \addToHead);
		},

		\loop, {
			synLR[lr]= Synth.head(groupWorld, \loopbufphas_1, [
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
				granList[lr][i]= Synth.head(groupWorld, \granbufphas_1, [
					\busnum, bus,
					\bufnum, buff,
					\ax, 0.5, \ay, 0.5,
					\frate, flockArr[lr][i].vel.mag,
					\vol, flockArr[lr][i].mass.linlin(0,4, 0,1),
					\gate, gate
				], s, \addToHead);
			});
			synLR[lr]= granList[lr][0]; // the leader gran (all the boids chase this one)
		},

		\particle, { } // particles are specific
	);
};

stopSynth= { arg reltime, lr;



	if( synLR[lr] != nil, {synLR[lr].set(\rel, reltime, \gate, 0)} );
	synLR[lr]= nil;
	if(currObjType[lr] == \flock, {
		population[lr].do({ |i| // swarm of boids
			granList[lr][i].set(\rel, reltime + bilinrand(5.0), \gate, 0);
		});
	});

	synLR[lr]


};
//--func end

//--midi ctrl


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
				if(lvBuffers.items.size > 1, {
					lvBuffers.value= if(lvBuffers.value > 0, { lvBuffers.value-1 }, { lvBuffers.items.size-1 } );
				});
			}.defer;
		},
		88,{ //navigation through samples - down
			{
				if(lvBuffers.items.size > 1, {
					lvBuffers.value= if(lvBuffers.value < (lvBuffers.items.size-1), { lvBuffers.value+1 }, { 0 } );
				});
			}.defer;
		}
	);
	},
	nil, nil, nil, nil // X-Session
);



//--
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

// granulating


SynthDef( \granbufphas_1, {
	arg bufnum= 0, busnum= 0, ax, ay, vol, gate= 0, frate= 1, fdur= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0;
	var trate, dur, pos, in, out, clk, updateRate=30, speakerArr, speakerBuff;

	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid


//	speakerArr= VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]); // works in A6
	speakerBuff= speakerArr.loadToBuffer;

	trate= frate.linlin(0,1, 0.1,1);
	dur= 4 / trate;
	clk= Impulse.kr(trate);
	//pos= Integrator.kr(BrownNoise.kr(ax));
	pos= ax*BufDur.kr(bufnum); // + TRand.kr(0, 0.01, clk); //arg X: position + rand delta
	in= TGrains.ar(
		numChannels: 2,
		trigger: clk,
		bufnum: bufnum,
		rate: BufRateScale.kr(bufnum) * frate.linlin(0,1, 1, 2),
		centerPos: pos,
		dur: dur,
		pan: -1, // always left as VBAP requires 1 channel
		amp: vol.linlin(0,1, 0,0.3)
	);

	out= VBAP.ar(4, in[0], speakerBuff.bufnum, azimuth, elevation, spread);
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

// audio in


SynthDef(\audioin_1, {arg rate=1, vol= 0, busnum= 0, inbusnum= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0;
	var in, out, speakerArr, speakerBuff;
	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid


//	speakerArr= VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]); // works in A6
	speakerBuff= speakerArr.loadToBuffer;

	in= InFeedback.ar(inbusnum, 1) * EnvGen.kr( Env.asr(att, vol, rel, [crva, crvr]), gate: gate, doneAction: 2 );

	out= VBAP.ar(4, in, speakerBuff.bufnum, azimuth, elevation, spread);

	Out.ar(busnum, out)
}).load(s);

// synths for routine


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
).load(s);

SynthDef( \rec_start, { arg outbus= 0, freq= 60, dur=0.8, amp=0.1, pan= 0;
	var env, signal;

	env= EnvGen.kr( Env.new([0, 0.8, amp, amp, 0.001],[0.1, 0.01, dur-0.21, 0.1], 'welch'), doneAction: 2 );
	signal= env * SinOsc.ar( freq );
	Out.ar( outbus, Pan2.ar(signal, pan) );
	}
).load(s);



////working stereo version
//SynthDef( \noisy, { arg outbus= 0, freq= 20, dur=1, amp=0.2, att=0.5, rel=0.2, gate=1;
//	var out, env, signal;
//
//	env= EnvGen.kr( Env.asr(att, amp, rel, -4), gate: gate, doneAction: 2 );
//	out= env * RLPF.ar( Impulse.ar( XLine.kr(freq, freq + 100,1.5), 0.0, 0.7.rand)
//			+ WhiteNoise.ar(0.8.rand),
//		LFNoise1.kr(1, 38, 115).midicps,
//		0.1
//	);
// 	signal = [out, DelayN.ar(out, 0.04, 0.04) ];
//	4.do({ out = AllpassN.ar(out, 0.05, [0.05.rand, 0.05.rand], 4, amp) });
//	signal.poll; out.poll;
//	Out.ar( outbus, signal );
//	}
//).load(s);



SynthDef( \noisy, { arg busnum= 0, freq= 20, dur=1, amp=0.2, att=0.5, rel=0.2, gate=1, azimuth= 0, elevation= 0, spread= 0;
	var in, out, env, signal, speakerArr, speakerBuff;

	speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring: WARNING! this setup is the best for UI 2d-slid


//	speakerArr= VBAPSpeakerArray.new(2, [ 135, 45, -45, -135 ]); // works in A6
	speakerBuff= speakerArr.loadToBuffer;

	env= EnvGen.kr( Env.asr(att, amp, rel, -4), gate: gate, doneAction: 2 );
	in= env * RLPF.ar( Impulse.ar( XLine.kr(freq, freq + 100,1.5), 0.0, 0.7.rand)
			+ WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps,
		0.1
	);
 	signal = [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in = AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4, amp) });

	out= VBAP.ar(4, Mix.new(signal), speakerBuff.bufnum, azimuth, elevation, spread);

	Out.ar( busnum, out );
	}
).load(s);
)
