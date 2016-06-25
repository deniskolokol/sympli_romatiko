

// proj title: Sympli Romatiko
// redUniverse objects (2D) controlled by Kinect (via OSCeleton) in surround sound (VBAP of BeastMulch)
//
// calibration
// $ cd ~/dev/kinect/libfreenect/build/bin
// $ ./glview



//
// OSCeleton (with multiplier for depth!):
// $ cd ~/dev/kinect/OpenNI-Bin-MacOSX-v1.1.0.41/OSCeleton/
// $ ./osceleton -p 57120 -mz 0.7


//
// keyboard:
//         M - manual/automatic mode switcher
//         N - new object (???)
//         X - clean all objects and synths
//         C - trash cleaner
//         F - (press and hold) remove all forces
//         I - info on objects and synths
//         L - start/stop "legs" synths - long
//         O - start/stop "legs" synths - hot
//         1, 2, .., 0 - delete obj by its index
//         --init objects (press & hold for rec into buffer or press for cyclic buffer):
//         Q - regular (fountain), light (mass <= 2)
//         W - drone, light (mass <= 2)
//         E - "gusts of wind" (stutter), heavy (2 < mass <= 5)
//         R - slicing, variable (0.5 < mass <= 5)
//         T - loop, variable (0.5 < mass <= 5)
//         Y - loop with random trigger time, variable (0.5 < mass <= 5)
//
//         A - trigger \ev_start
//
(


var calibMag= 1.41;
var soundsDir= "~/Music/bibeast/sounds/";
var speakerArr, speakerBuff;
var w, world, wgrav, width= 800, height= 800, margin= 0, trashCleaner;
var skelObj, skelCoords, feetCoords;
var worldCapacity, objects, synths, currObj= 0, currSynth= 0, currObjType, currSynType, objInd, mass, color, pos, objNoisy= nil, synNoisy= nil, posNoisy, objAudioIn= nil, synAudioIn= nil, posAudioIn, wind, windEngine= 0, springs, hand, applyForses= true;
var responderKinect, responderKinectNewUser, responderKinectLostUser, removeKinectResp;
var fps= 40, frame= 0, fmsTrashClean, trigTrashClean;
var msetWait, msetKey, key, keySteps, waitKey, wait, waitCurr, waitRep, rectime= 0, rectimeRep, steps, midinote;
var groupSched= Group.new(s), groupWorld= Group.new(s);
var inbus= 30, recBufStart, recBufStop, recSynth, isRecording= false, recProgress= 0, currFilename, currBufnum, currBuffer;
var startSynth, stopSynth, bufPool= List.new, loadBuf, cyclicBuf, cyclicSynth, initObj, prepInitObj;
var synForm= nil, synSaw= nil, posFeet= [nil, nil], synthCtrlArgs, synthCtrl, currFormCtl= nil, currSawCtl= nil, startFeetSynths; // "legs" and their "boots"
var autoMode= 0, loadBufRout, noisyNodeID= 0;
var fillStream, streamList= [nil], runTask1, runTask2, isActiveTask1= 0, isActiveTask2= 0, arrBase= #[0, 2, 3, 6], arrDer0= #[ 2, 3, 6, 7 ];
var keycodeObjType= #[ 12, 13, 14, 15, 17, 16 ], // keycodes for creating objects of dirrefent kinds
	keycodeObj= #[ 29, 18, 19, 20, 21, 23, 22, 26, 28, 25 ]; // keycodes for tracing objects 0-9. ORDER MATTERS!!!



//--initial
fmsTrashClean= 30*fps; // trash cleaner starts every N seconds
skelObj= Array.fill(5, { nil }); // container for objects representing skeleton joints
skelCoords= Array.fill(5, { |i| [i*(width/6)+100, (i%2)*(height/15)+150, 0] }); // test coordinates
feetCoords= Array.fill(2, { |i| [i*(width/3)+100, 200, 0] }); // test coordinates
worldCapacity= 10;
objects= Array.fill(worldCapacity, { nil }); // container for physical objects
synths= Array.fill(worldCapacity, { nil }); // container for synths connected to objects
springs= [List.new, List.new]; // container for springs on left (0) and right (1) hands
synthCtrlArgs= #[ [\kr_ml0, 0], [\kr_mg2, 1], [\kr_mg0, 2], [\kr_ml1, 3], [\kr_mg1, 4], [\kr_mh0, 5] ]; //[\synthName, ctrl bus]
synthCtrl= Array.fill(synthCtrlArgs.size, { nil });
cyclicBuf= Buffer.alloc(s, s.sampleRate, 1); // 1s single channel Buffer
loadBufRout= Routine({
	inf.do({ |j|
		if(cyclicBuf.numChannels != nil, {
			cyclicSynth= Synth.head(groupSched, \syninbuff, [ //recording synth
				\bufnum, cyclicBuf.bufnum, \busnum, inbus, \volIn, 1, \gate, 1, \dur, 1]);
			loadBufRout.stop;
			});
		0.01.wait;
		});
	}).play(AppClock);

//--speakers setup
speakerArr= VBAPSpeakerArray.new(2, [-45, -135, 135, 45]); // 4 channel ring (in A6 use [ 135, 45, -45, -135 ])
speakerBuff= speakerArr.loadToBuffer;

//--scheduling



msetWait= MarkovSet([ // markov set for waiting time (1st order)
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
keySteps= 10;
key= \a;
steps= 0;
waitKey= msetWait.next(key);
waitRep= rrand(waitKey * 0.75, waitKey).max(1).round;
wait= waitRep* fps;
//keySteps= msetKey.next(\n);
//key= msetWait.dict.keys.asArray.choose;
//steps= 0;


//waitKey= msetWait.next(key);



//waitRep= rrand(waitKey * 0.75, waitKey).max(1).round;
//wait= waitRep* fps;

//--kinect
responderKinectNewUser= OSCresponderNode(nil, '/new_skel', {arg t, r, msg;
	msg.postln;
	}).add;
responderKinectLostUser= OSCresponderNode(nil, '/lost_skel', {arg t, r, msg;
	msg.postln;
	}).add;
responderKinect= OSCresponderNode(nil, '/joint', {arg t, r, msg;
	var joint;
//	[t, r, msg].postln;
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
			},
		'r_foot', {
			feetCoords[0][0]= msg[3].linlin(0, 1, margin, width-margin); // X
			feetCoords[0][1]= msg[5].linlin(0.3, 2.7, margin, height-margin); // Depth
			feetCoords[0][2]= msg[4].linlin(0, 1, 1, 0); // Y
			},
		'l_foot', {
			feetCoords[1][0]= msg[3].linlin(0, 1, margin, width-margin); // X
			feetCoords[1][1]= msg[5].linlin(0.3, 2.7, margin, height-margin); // Depth
			feetCoords[1][2]= msg[4].linlin(0, 1, 1, 0); // Y
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
	.background_(Color.new255( 85, 26, 139 )) .front;
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
synAudioIn= Synth.head(groupSched, \audioin_1, [ \speakerBuffNum, speakerBuff.bufnum, \inbus, inbus, \amp, 0.6, \distance, 8 ]); // audioin is persistent

//--draw objects
w.draw{
	if(autoMode.booleanValue, { frame= frame + 1; }); // counting steps
	if(isRecording, {recProgress= recProgress+1}); // measuring len of rec
	if(windEngine > 1e+6, {windEngine= 0}); // don't grow too large
	windEngine= windEngine+1; // moving wind

	w.background= if(autoMode.booleanValue, { Color.black }, { Color.new255(0, 33, 74) });

	world.gravity= RedVector2D.newFrom(skelCoords[2][0..1]/([width, height]) - 0.5); // head's position defines vector of gravity

	//--user's skeleton
	skelObj.size.do({ |i|
		// WARNING! for testing purposes only!!!
//		if([0,4].includes(i), { skelObj[i].loc= w.mouse }, { skelObj[i].loc= RedVector2D.newFrom(skelCoords[i][0..1]); });
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
		/*
		// display coordinates
		Pen.fillColor= Color.white;
		Pen.stringAtPoint(
			skelCoords[i][0..1].round.asString.[1..skelCoords[i][0..1].round.asString.size-2],
			(skelCoords[i][0..1]-5).asPoint
			);
		*/
		});

	feetCoords.size.do({ |f|
		// no objects, just draw on window
		Pen.strokeColor= Color.white;
		Pen.fillColor= Color.white(0.5, 0.5);
		Pen.fillOval(
			Rect.new(
				feetCoords[f][0], feetCoords[f][1],
				feetCoords[f][2].linlin(0,1, 20, 50), feetCoords[f][2].linlin(0,1, 20, 50)
				)
			);
		});
	if(synForm != nil, { // presuming that they always started together, so cheking only one
		posFeet[0]= Complex( // left
			feetCoords[0][0].linlin(0, width, 1, -1), // x
			feetCoords[0][1].linlin(0, height, -1, 1) // y
			);
		posFeet[1]= Complex( // right
			feetCoords[1][0].linlin(0, width, 1, -1), // x
			feetCoords[1][1].linlin(0, height, -1, 1) // y
			);
		synForm.set( // left controls \formant
			\azimuth, posFeet[0].theta.linlin(-pi,pi, -180, 180),
			\spread, (1-((posFeet[0].magnitude/calibMag).pow(0.16)))*100,
			\amp, feetCoords[0][2].clip(0.4, 0.7),
			\mod, "c"++(currFormCtl ? "").asString
			);
		synSaw.set(	// right controls \saw
			\azimuth, posFeet[1].theta.linlin(-pi,pi, -180, 180),
			\spread, (1-((posFeet[1].magnitude/calibMag).pow(0.16)))*100,
			\amp, feetCoords[1][2].clip(0.3, 0.6),
			\mod, "c"++(currSawCtl ? "").asString
			);
		});

	//--objects
	world.objects.do({ |o, i|
		if(skelObj.includes(o).not && [objNoisy, objAudioIn].includes(o).not, {
			if(objects.indexOf(o) == nil, { // operative trash cleaner
				world.remove(o); o.free; o= nil;
				}, {
				if(applyForses, {
					o.asString.switch(
						"a RedBoid", {
							o.addForceArrive(skelObj[0].loc);
							o.addForceArrive(skelObj[4].loc);



							color= Color.yellow(0.5, 0.8);
							},
						"a RedObject", {
							if(o.mass <= 2, {
								o.addForce(o.gravityForce(skelObj[0]));
								o.addForce(o.gravityForce(skelObj[4]));
								});
							color= Color.gray(0.5, 0.8);
							}
						);
					o.addForce(world.gravity);
					});


					o.update;
					world.contain(o);
					Pen.fillColor= color;
					Pen.fillOval(Rect.aboutRedObject2D(o));
					Pen.fillColor= Color.white;
					Pen.stringAtPoint(objects.indexOf(o).asString, (o.loc-5).asPoint);

				//--render springs
				if(springs[0].includes(o), {
					o.spring(skelObj[0], 0.2.rand(0.5), 0.9, 20); //target, stiffness, damping, length
					Pen.strokeColor= Color.grey;
					Pen.line(o.loc.asPoint, skelObj[0].loc.asPoint);
					Pen.stroke;
					});
				if(springs[1].includes(o), {
					o.spring(skelObj[4], 0.1.rand(0.6), 0.9, 20);
					Pen.strokeColor= Color.grey;
					Pen.line(o.loc.asPoint, skelObj[4].loc.asPoint);
					Pen.stroke;
					});
				//--control synth
				pos= Complex(
					o.loc[0].linlin(0, width, 1, -1), // x
					o.loc[1].linlin(0, height, -1, 1) // y
					);
				objInd= objects.indexOf(o) ? 0;
				if(synths[objInd] != nil, {
					synths[objInd].set(
						\azimuth, pos.theta.linlin(-pi,pi, -180, 180),
						\spread, (1-((pos.magnitude/calibMag).pow(0.16)))*100, // exp shift: slower spread
						\amp, o.mass.linlin(0.5,5.0, 0.01,0.70) + o.vel[1].abs.linlin(0,30, 0,0.2), // the faster the louder
						\ax, o.loc[0].linlin(0,width, 0,1),
						\ay, 0.5, // middle as default
						\distance, hypot(o.loc[0].linlin(0,height, 30, 60), o.loc[1].linlin(0,width, -100, 100))
						);
					// if the distance from a hand to the object is less than half a distance between hands, hand's Y affect the synth
					if(
						(skelObj[0].loc.distance(o.loc) < ((skelObj[0].loc.distance(skelObj[4].loc))*0.5))
						||
						springs[0].includes(o), {
						synths[objInd].set( \ay, skelCoords[0][2].clip(0.01, 0.99) ); // objects wondering around right hand
						});
					if(
						(skelObj[4].loc.distance(o.loc) < ((skelObj[0].loc.distance(skelObj[4].loc))*0.5))
						||
						springs[1].includes(o), {
						synths[objInd].set( \ay, skelCoords[4][2].clip(0.01, 0.99) ); // objects wondering around left hand
						});
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

		objNoisy.loc= RedVector2D[width, height].rand;
		synNoisy= Synth.head(groupSched, \noisy, [ // hold the noise while recording
			\speakerBuffNum, speakerBuff.bufnum,
			\freq,rrand(24, 240),
			\amp,rrand(0.01, 0.1),
			\dur, rectimeRep,
			\att, 0.5.rand,
			\rel,1.0.rand(rectimeRep),
			\distance, hypot(skelObj[2].loc[0].linlin(0,height, 30, 60), objNoisy.loc[1].linlin(0,width, -100, 100))
			]);

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

		prepInitObj.value( [true, false].wchoose([0.7, 0.3]) ); // cyclic buffer is rare
		mass= 0.5.rrand(5);
		currObjType= ["a RedBoid", "a RedObject"].choose;
		currSynType= currObjType.switch(
			"a RedBoid", {
				[\syroslid, \syroloop].wchoose([0.9, 0.1])
				},
			"a RedObject", {
				if(mass <=2, { [\syroregu, \syrodron].choose }, { \syrogust })
				}
			);
		initObj.value( 0.5.rrand(2), currObjType);
		startSynth.value(cyclicBuf.bufnum, currSynType); // start synth with a cyclic buf as default

		wait= wait + waitCurr + rectime; // accumulating wait time
		});

	if(synths[currObj] != nil, { synths[currObj].set( // synth vol depends on object's mass and velocity
		\amp, objects[currObj].mass.linlin(0.5,5.0, 0.01,0.70) + objects[currObj].vel[1].abs.linlin(0,30, 0,0.2) ) });

	//--wind blowing
	wind= 0.5*sin(2pi*((windEngine % fmsTrashClean).round/width));

	//--noisy obj and synth
	if(objNoisy != nil, {
		Pen.fillColor= Color.red;
		Pen.fillOval(Rect.aboutRedObject2D(objNoisy));
		if(applyForses, { objNoisy.addForce(wind); });
		objNoisy.update;
		world.contain(objNoisy);

		posNoisy= Complex(
			objNoisy.loc[0].linlin(0, width, 1, -1), // x
			objNoisy.loc[1].linlin(0, height, -1, 1) // y
		);

		if( synNoisy != nil, {
			synNoisy.set(
				\azimuth, posNoisy.theta.linlin(-pi,pi, -180, 180),
				\spread, (1-((posNoisy.magnitude/calibMag).pow(0.16)))*100,
				\distance, hypot(objNoisy.loc[0].linlin(0,width, 5,10), objNoisy.loc[1].linlin(0,height, -100,100))
				)
			});
		});

	//--audio_in obj and synth
	if(objAudioIn != nil, {
		Pen.fillColor= Color.green(0.7, 0.8);
		Pen.fillOval(Rect.aboutRedObject2D(objAudioIn));
		if(applyForses, {
			objAudioIn.addForce(wind)
				.addForce(world.gravity)
				.addForceArrive(skelObj[2].loc, 0.5); // head attracts audio_in
			});
		/*
		// not sure about it
		world.objects.do({ |obj|
			if(( obj != objAudioIn) && skelObj.includes(obj).not, {
				objAudioIn.addForce(obj.gravityForce(objAudioIn));
				if(objAudioIn.loc.distance(obj.loc) < (obj.size*2), {
					objAudioIn.addForce(objAudioIn.gravityForce(obj).neg);
					});
				});
			});
		*/
		objAudioIn.update;
		world.contain(objAudioIn);
		posAudioIn= Complex(
			objAudioIn.loc[0].linlin(0, width, 1, -1), // x
			objAudioIn.loc[1].linlin(0, height, -1, 1) // y
			);
		if( synAudioIn != nil, {
			synAudioIn.set(
				\azimuth, posAudioIn.theta.linlin(-pi,pi, -180, 180),
				\spread, (1-((posAudioIn.magnitude/calibMag).pow(0.33)))*100, // exp shift: slower spread
				\distance, hypot(objAudioIn.loc[0].linlin(0,width, 5,10), objAudioIn.loc[1].linlin(0,height, 100, -100))
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
	if(autoMode.booleanValue, {
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
		});

	//--\syroform & \syrolsaw ctrl switch
	synthCtrlArgs.size.do({ |k|
		Pen.strokeColor= Color.red;
		Pen.fillColor= Color.green;
		if( k == currSawCtl, {
			Pen.fillOval( Rect.new( 80+(15*k), height*0.9, 10, 10) );
			}, {
			Pen.strokeOval( Rect.new( 80+(15*k), height*0.9, 10, 10) );
			});
		if( k == currFormCtl, {
			Pen.fillOval( Rect.new( 80+(15*k), height*0.9 + 15, 10, 10) );
			}, {
			Pen.strokeOval( Rect.new( 80+(15*k), height*0.9 + 15, 10, 10) );
			});
		});
	if(isActiveTask1.booleanValue, {
		Pen.fillOval( Rect.new( 190, height*0.9, 17, 17) );
		},
	{
		Pen.strokeOval( Rect.new( 190, height*0.9, 17, 17) );
		});
	if(isActiveTask2.booleanValue, {
		Pen.fillOval( Rect.new( 220, height*0.9, 17, 17) );
		},
	{
		Pen.strokeOval( Rect.new( 220, height*0.9, 17, 17) );
		});
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
	isRecording= true; recProgress= 0;

//	inform("RECORDING...");

	bufnum // returns bufnum
	};

recBufStop= { arg bnum;
	try{ recSynth.free };
	s.sendMsg("/b_close", bnum, ["/b_free", bnum]);
	isRecording= false;
//	inform("RECORDING STOPPED.");
	};

loadBuf= { arg buff;
	loadBufRout= Task({
		inf.do({ |j|
			if(buff.numChannels != nil, {
				bufPool.add(buff); // add to the pool
				startSynth.value( buff ); // launch a new synth (object is already launched)
				loadBufRout.stop;
				});
			0.01.wait;
			});
		}).start;
	};

startSynth= { arg buff= currBufnum, syntype= \syroregu, bus= 0, amp= 1, gate= 1;
	try{ stopSynth.value(2.0.rand, currSynth) }; // new synth clears out the sloth
	synths.put(
		currSynth, Synth.head(groupWorld, syntype, [ \speakerBuffNum, speakerBuff.bufnum, \busnum, bus, \bufnum, buff,
			\ax, 0.5, \ay, 0.5, \amp, amp, \gate, gate
			]);
		);
//	postf("obj: %\tmass: %\tsynth: %\n", objects[currSynth].asString, objects[currSynth].mass, synths[currSynth]);
	};

stopSynth= { arg reltime, synthInd;



	if( synths[synthInd] != nil, {
		synths[synthInd].set(\rel, reltime, \gate, 0);
		synths[synthInd]= nil;
		});
	};



trashCleaner= { |world|
	world.objects.do({ |o|
		if( (skelObj.includes(o) || objects.includes(o)).not, {
			2.do({ |j| // free from springs on the left and right hand
				if(springs[j].includes(o), { springs[j].removeAt(springs[j].indexOf(o)); });
				});
			world.remove(o); o.free; o= nil;
			});
		});
	};

initObj= { |mass, type|
	if(currObj == objects.size, { currObj= 0 }); // objects are in FIFO stack
	if(objects.at(currObj) != nil, { // check if currObj index already occupied
		if(objects.indexOf(nil) != nil, { currObj= objects.indexOf(nil) });
		});

	switch(type,
		"a RedBoid", {
			objects.put(currObj,
				RedBoid(world, RedVector2D[width, height].rand, RedVector2D[0, 0], RedVector2D[0, 0], mass, mass*5)
					.maxForce_(1).wdistance_(3.rrand(13)).wchange_(0.75).wradius_(10.rrand(50))
				);
			},
		"a RedObject", {
			objects.put(currObj,
				RedObject(world, RedVector2D[width, height].rand, RedVector2D[0, 0], RedVector2D[0, 0], mass, mass*5)
				);
			if(mass > 2, {
				hand= [0,1].choose;
				springs[hand].add(objects[currObj]);
				});
			}
		);
	currSynth= currObj;
	currObj= currObj+1;
	};

prepInitObj= { |updateBuf= false| // prepare world to the init of new object (synths, buffer, etc.)
	var buff;
	recBufStop.value(currBufnum); // stop recording
	if(updateBuf, { // load buffer
		buff= Buffer.read(s, currFilename);
		loadBufRout= Task({
			inf.do({ |j|
				if(buff.numChannels != nil, {
					bufPool.add(buff); // add newly created buf to the pool
					recProgress= 0;
					synths[currSynth].set(\bufnum, buff.bufnum);
					loadBufRout.stop;
					});
				0.01.wait;
				});
			}).start;
		});

	midinote= 10.rrand(80);
	if(autoMode.booleanValue, {
		Synth.head(groupSched, \ev_start, [ // end of recording signal
			\speakerBuffNum, speakerBuff.bufnum,
			\note, midinote,
			\azimuth, 180.bilinrand,
			\spread, 10.rrand(50)
			]);
		});

	synNoisy= nil; // to prevent msg FAILURE /n_set Node not found
	};

startFeetSynths= { |gate, tFormAttRel, tSawAttRel|
// synths controlled by legs enter slowly and remain quiet
	if(gate != 0, {
		if(synForm == nil, {
			synForm= Synth.head(groupWorld, \syroform, [ \speakerBuffNum, speakerBuff.bufnum, \att, tFormAttRel, \amp, 0.4,
				\azimuth, 180.bilinrand, \spread, 10.rrand(50), \mod, "c" ]);
			synSaw= Synth.head(groupWorld, \syrolsaw, [ \speakerBuffNum, speakerBuff.bufnum, \att, tSawAttRel, \amp, 0.4,
				\azimuth, 180.bilinrand, \spread, 10.rrand(50), \mod, "c" ]);
			synthCtrlArgs.size.do({ |i|
				synthCtrl[i]= s.nextNodeID;
				s.sendBundle(0.1, ["/s_new", synthCtrlArgs[i][0].asString, synthCtrl[i]],
					["/n_set", synthCtrl[i], "outbus", synthCtrlArgs[i][1]]);
				});
			});
		},
	{
		if(synForm != nil, {
			synForm.set(\gate, 0, \done, 2, \rel, tFormAttRel);
			synSaw.set(\gate, gate, \done, 2, \rel, tSawAttRel);
			synForm= nil; synSaw= nil;
			synthCtrl.size.do({ |i|
				s.sendMsg("/n_free", synthCtrl[i]); // clear if the synth is "stuck"
				synthCtrl[i]= nil;
				});
			});
		});
	};

//--tasks
fillStream= { arg curr;
	streamList[curr]= Prout({
		loop {
			rrand(2,10).do({
				0.yield;
				arrBase.choose.yield;
				2.yield;
				arrDer0.choose.yield;
			});
			rrand(3,6).do({
				(arrDer0.choose + #[12, 24].choose).yield;
			});
		}
	}).asStream
};

runTask1= { |on|
	if(on.booleanValue, {
		fillStream.value(0); // create the stream
		{
			streamList[0].do{ |val|
				var dur;
				val.postln;
				synForm.set(\mnote, val.midicps);
				synSaw.set(\mnote, (val * 0.2).midicps, \mod, val.linlin(0,32, 0, -1));
				dur= if(val < 18, {0.25}, {2.0.rand});
				dur.wait;
				}
			}.fork(TempoClock());
		},
	{
		streamList[0].stop; streamList[0]= nil;
		});
	};

runTask2= { |on|
	if(on.booleanValue, {
		fillStream.value(0); // create the stream
		{
			streamList[0].do{ |val|
				var dur;
				val.postln;
				synForm.set(\mnote, val.midicps, \mod, 0);
				synSaw.set(\mnote, (val * 0.2).midicps);
				synForm.set(\gate, 1, \att, 0.5);
				synSaw.set(\gate, 0, \done, 0, \rel, 0.5);
				if(val < 18, {
					synSaw.set(\gate, 1, \att, 0.5);
					2.0.rand.wait;
					synSaw.set(\gate, 0, \done, 0, \rel, 0.1);
					if(0.3.coin, {
						synForm.set(\mnote, val.midicps-12, \mod, val.linexp(0,18, 0.1, 0.6));
						[0.15, 0.5].choose.wait;
					});
				}, {
					synSaw.set(\gate, 0, \done, 0, \rel, 0.75);
					[0.25, 0.75].choose.wait;
					synSaw.set(\gate, 1, \att, 0.5);
					});
				dur= if(val < 18, {0.25}, {rrand(0.5, 1.5)});
				dur.wait;
				}
			}.fork(TempoClock());
		},
	{
		streamList[0].stop; streamList[0]= nil;
		});
	};

//--keyboard control
w.view.keyUpAction= { arg view, char, modifiers, unicode, keycode;
	case { keycodeObjType.includes(keycode) } { // stop rec, create obj, etc.
		if(isRecording, { // only if recording is on
			if(recProgress > 30, { prepInitObj.value(true) }, { prepInitObj.value(false) } );
			switch(keycode,
				12, { // Q
					initObj.value( 0.5.rrand(2), "a RedObject" );
					startSynth.value(cyclicBuf.bufnum, \syroregu); // start synth with a cyclic buf as default
					},
				13, { // W
					initObj.value( 0.5.rrand(2), "a RedObject" );
					startSynth.value(cyclicBuf.bufnum, \syrodron);
					},
				14, { // E
					initObj.value( 2.1.rrand(5), "a RedObject" );
					startSynth.value(cyclicBuf.bufnum, \syrogust);
					},
				15, { // R
					initObj.value( 0.5.rrand(5), "a RedBoid" );
					startSynth.value(cyclicBuf.bufnum, \syroslid);
					},
				17, { // T
					initObj.value( 0.5.rrand(2), "a RedBoid" );
					startSynth.value(cyclicBuf.bufnum, \syroloop);
					},
				16, { // Y
					initObj.value( 0.5.rrand(2), "a RedBoid" );
					startSynth.value(cyclicBuf.bufnum, \syrolopt);
					}
				);
			})
		}
		{ keycode == 3 } { // 'f' - remove all forces
			if( [0, 256].includes(modifiers), { applyForses= true });
			}
		{ keycode == 1 } { // S - release \noisy
			if(noisyNodeID != 0, { s.sendMsg("/n_set", noisyNodeID, "gate", 0, "rel", 2.0.rand); noisyNodeID= 0; });
			};
	};

w.view.keyDownAction= { arg view, char, modifiers, unicode, keycode;
	var checkRout, tmpInd;
	[char, modifiers, unicode, keycode].postln;
	case
		{ keycode == 46 } { autoMode= 1-autoMode } // M - manual/automatic mode switcher
		{ keycode == 45 } { // N - new object (???)
			if(autoMode.booleanValue.not, {
				autoMode= 1;
				checkRout= Routine({
					inf.do({
						if(rectimeRep != nil, {
							(rectimeRep+0.1).wait;
							autoMode= 0;
							checkRout.stop
							});
						0.01.wait;
						});
					}).play(AppClock);
				});
			}
		{ keycode == 7 } { // X - clean all objects and synths
			if( [0, 256].includes(modifiers), {
				world.objects.do({ |o|
					if(skelObj.includes(o).not && [objNoisy, objAudioIn].includes(o).not, {
						world.remove(o);
						o.free;
						o= nil;
						});
					});
				objects= Array.fill(worldCapacity, { nil }); // empty objects container
				synths.do({ |y|
					y.set(\rel, 1, \gate, 0);



					});


				synths= Array.fill(worldCapacity, { nil }); // empty synths
				});
			}
		{ keycode == 8 } { // C - trash cleaner
			if( [0, 256].includes(modifiers), { trashCleaner.value(world); });
			}
		{ keycode == 3 } { // F - remove all forces
			if( [0, 256].includes(modifiers), { applyForses= false });
			}
		{ keycode == 34 } { // (I)nfo
			if( [0, 256].includes(modifiers), { postf("objects: %\nsynths: %\n", objects, synths); });
			}
		{ keycode == 31 } { // O - hot start/stop "legs" synths
			if( [0, 256].includes(modifiers), { // synths controlled by legs enter slowly and remain quiet
				if(synForm == nil, {
					startFeetSynths.value(1, 0.1, 0.1);
					},
				{
					startFeetSynths.value(0, 0.1, 0.1);
					});
			})
			}
		{ keycode == 37 } { // L - start/stop "legs" synths
			if( [0, 256].includes(modifiers), { // synths controlled by legs enter slowly and remain quiet
				if(synForm == nil, {
					startFeetSynths.value(1, 120, 240);
					},
				{
					startFeetSynths.value(0, 30, 30);
					});
				});
			}
		{ keycode == 4 } { // H - run/stop Task 1
			if( [0, 256].includes(modifiers), {
				if(synForm != nil, {
					if(isActiveTask2.booleanValue, { // clear opposite task
						isActiveTask2= 0;
						runTask2.value( isActiveTask2 );
						});
					isActiveTask1= 1-isActiveTask1;
					runTask1.value( isActiveTask1 );
					});
				});
			}
		{ keycode == 38 } { // J - run/stop Task 2
			if( [0, 256].includes(modifiers), {
				if(synForm != nil, {
					if(isActiveTask1.booleanValue, { // clear opposite task
						isActiveTask1= 0;
						runTask1.value( isActiveTask1 );
						});
					isActiveTask2= 1-isActiveTask2;
					runTask2.value( isActiveTask2 );
					});
				});
			}
		{ keycode == 40 } { // K - reset synForm & synSaw after Tasks
			if( [0, 256].includes(modifiers), {
				if(synForm != nil, {
					synForm.set(\mnote, 0);
					synSaw.set(\mnote, 0);
					});
				});
			}
		{ keycode == 0 } { // A - trigger \ev_start
			if( [0, 256].includes(modifiers), {
				Synth.head(groupSched, \ev_start, [ // single blip
					\speakerBuffNum, speakerBuff.bufnum, \note, 10.rrand(80), \azimuth, 180.bilinrand, \spread, 10.rrand(50)
					]);
				});
			}
		{ keycode == 1 } { // S - press & hold for \noisy
			if( [0, 256].includes(modifiers), {
				if(noisyNodeID == 0, {
					s.sendMsg("/n_free", noisyNodeID); // clear if the synth is "stuck"
					s.sendMsg("/s_new", "noisyhold", noisyNodeID= s.nextNodeID, 0, 0,
						"speakerBuffNum", speakerBuff.bufnum, "freq",rrand(24, 240), "amp",rrand(0.01, 0.1), "att", 1.0.rand,
						"distance", hypot(
							skelObj[2].loc[0].linlin(0,height, 30, 60),
							objNoisy.loc[1].linlin(0,width, -100, 100)
							)
						);
					});
				});
			}
		{ keycode == 123 } { //[<-] prev ctrl for synSaw
			if(currSawCtl == nil, {
				currSawCtl= synthCtrlArgs.size-1
				},
			{
				currSawCtl= currSawCtl-1;
				if(currSawCtl < 0, { currSawCtl= nil });
				});
			}
		{ keycode == 124 } { //[->] next ctrl for synSaw
			if(currSawCtl == nil, {
				currSawCtl= 0
				},
			{
				currSawCtl= currSawCtl+1;
				if(currSawCtl == synthCtrlArgs.size, { currSawCtl= nil });
				});
			}
		{ keycode == 125 } { // [down] next ctrl for synForm
			if(currFormCtl == nil, {
				currFormCtl= 0
				},
			{
				currFormCtl= currFormCtl+1;
				if(currFormCtl == synthCtrlArgs.size, { currFormCtl= nil });
				});
			}
		{ keycode == 126 } { // [up] prev ctrl for synForm
			if(currFormCtl == nil, {
				currFormCtl= synthCtrlArgs.size-1
				},
			{
				currFormCtl= currFormCtl-1;
				if(currFormCtl < 0, { currFormCtl= nil });
				});
			}
		{ keycode == 51 } { // [return] - delete last created object
			if( [0, 256].includes(modifiers), {
				tmpInd= if(currObj > 0, { currObj-1 }, { 9 });
				2.do({ |j| // free from springs on the left and right hand
					if(springs[j].includes(objects[tmpInd]), {
						springs[j].removeAt(springs[j].indexOf(objects[tmpInd]));
						});
					});
				world.remove(objects.at( tmpInd ));
				objects.at( tmpInd ).free;
				objects.put( tmpInd, nil );
				stopSynth.value(5.0.rand, tmpInd);
				currObj= tmpInd; // reset counter
				})
			}
		{ keycodeObjType.includes(keycode) } { // start rec
			if(isRecording.not, { // only if there's no current rec
				currFilename= soundsDir++"kin_"++Date.getDate.stamp.asString++".aif";
				currBufnum= recBufStart.value(inbus: inbus, numchannels: 1, path: currFilename);
				})
			}
		{ keycodeObj.includes(keycode) } { // delete object with given index
			if(objects.at( keycodeObj.indexOf(keycode) ) != nil, {
				tmpInd= keycodeObj.indexOf(keycode);
				2.do({ |j| // free from springs on the left and right hand
					if(springs[j].includes(objects[tmpInd]), {
						springs[j].removeAt(springs[j].indexOf(objects[tmpInd]));
						});
					});
				world.remove(objects.at( tmpInd ));
				objects.at( tmpInd ).free;
				objects.put( tmpInd, nil );
				stopSynth.value(5.0.rand, tmpInd);
				});
			};
	};

w.onClose({



	removeKinectResp.value();
	bufPool.do{ |buff| buff.free };


	cyclicBuf.free;
	cyclicSynth.free;
	});



CmdPeriod.doOnce({
	removeKinectResp.value();
	bufPool.do{ |buff| buff.free };
	cyclicBuf.free;
	cyclicSynth.free;
	if(synForm != nil, {synForm.free});
	if(synSaw != nil, {synSaw.free});
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



// looper


SynthDef(\syroloop, {arg bufnum=0, busnum=0, ax, ay, gate= 0, amp= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
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
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5, mul: amp
		);
	out= VBAP.ar(4, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}).load(s);



// looper with random trigger time


SynthDef(\syrolopt, {arg bufnum=0, busnum=0, ax, ay, gate= 0, amp= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
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
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5, mul: amp
		);
	out= VBAP.ar(4, signal, speakerBuffNum, azimuth, elevation, spread);
	Out.ar(busnum, out)
}).load(s);



// granulating


SynthDef( \syroregu, { // regular
	arg bufnum= 0, busnum= 0, ax, ay, amp, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
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
					in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
					)
				), 110/344, distance/110
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5
		);
	out= VBAP.ar(4, signal, speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).load(s);

SynthDef( \syrodron, { // drone
	arg bufnum= 0, busnum= 0, ax, ay=0.5, amp=0.1, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
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
		amp: amp
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
				)
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5
		);
	out= VBAP.ar(4, signal, speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).load(s);

SynthDef( \syrogust, { // "gusts of wind"
	arg bufnum= 0, busnum= 0, ax, ay, amp, gate= 0, rate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
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
		amp: Dseq([1, 0, z.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf)*amp*ay.linlin(0,1, 0.3,1.1).fold(0,1)
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
				)
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5
		);
	out= VBAP.ar(4, signal, speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).load(s);

SynthDef( \syroslid, { // "slicing"
	arg bufnum= 0, busnum= 0, ax, ay, amp, gate= 0, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
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
		amp: amp * rateratio.linlin(0,4, 1,0.15)
		);
	signal= RLPF.ar(
		Mix.new(
			FreeVerb.ar(
				in, distance.linlin(44,110, 0.01, 0.99), distance/344, 0.2
				)
			), distance.linlin(44,110, 10000, 500).clip(500,10000), 0.5
		);
	out= VBAP.ar(4, signal, speakerBuffNum, azimuth, elevation, spread);
	out= out * EnvGen.kr( Env.asr(att, 1, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	Out.ar(busnum, out);
	}
).load(s);



// audio in


SynthDef(\audioin_1, {arg rate=1, amp= 1, outbus= 0, inbus= 0, gate= 1, att= 0.1, rel= 1, crva= -3, crvr= 3, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var in, out, env, vol;
	vol= 55/distance.squared;
	env= EnvGen.kr( Env.asr(att, amp, rel, [crva, crvr]), gate: gate, doneAction: 2 );
	//dl= DelayL.ar( InFeedback.ar(inbus, 1), 110/344, distance/344);
	in= RLPF.ar( InFeedback.ar(inbus, 1), distance.linlin(44,110, 10000,800).clip(800,10000), 0.5, vol.max(0.3)) * env;
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

SynthDef( \ev_start, { arg outbus= 0, note= 60, dur=1, amp=0.3, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var in, out, freq, env, signal;
	freq= note.midicps;
	env= EnvGen.kr( Env.perc, levelScale: 0.3, timeScale: dur, doneAction: 2 );
	in= env * RLPF.ar( LFSaw.ar( freq )
			+ Impulse.ar( XLine.kr(freq, freq + 100,1.5), 0.0, 0.7.rand)
			+ WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps,
		0.1,
		amp
	);
 	signal= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4) });
	out= VBAP.ar(4, Mix.new(signal), speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).load(s);

SynthDef( \noisy, { arg outbus= 0, freq= 20, dur=1, amp=0.2, att=0.5, rel= 0.1, gate=1, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var in, out, env, signal, filtout, vol;
	vol= 55/distance.squared;
	env= EnvGen.kr( Env.linen(att, dur-att-rel, rel, amp, \sine), doneAction: 2 );
	in= env * RLPF.ar(
		Impulse.ar( XLine.kr(freq, freq + 100, dur-rel), 0.0, 0.7.rand) + WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps, 0.1
		);
 	signal= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4, amp) });
	filtout= RLPF.ar( Mix.new(signal), distance.linlin(44,110, 10000,800).clip(800,10000), 0.5, vol.max(0.1));
	out= VBAP.ar(4, filtout, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).load(s);

SynthDef( \noisyhold, { arg outbus= 0, freq= 20, amp=0.2, att=0.5, rel= 0.1, gate=1, azimuth= 0, elevation= 0, spread= 0, distance, speakerBuffNum;
	var in, out, env, signal, filtout, vol;
	vol= 55/distance.squared;
	env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: 2 );
	in= env * RLPF.ar(
		Impulse.ar( XLine.kr(freq, freq + 100, Rand(1, 2)), 0.0, 0.7.rand) + WhiteNoise.ar(0.8.rand),
		LFNoise1.kr(1, 38, 115).midicps, 0.1
		);
 	signal= [in, DelayN.ar(in, 0.04, 0.04) ];
	4.do({ in= AllpassN.ar(in, 0.05, [0.05.rand, 0.05.rand], 4, amp*0.15) });
	filtout= RLPF.ar( Mix.new(signal), distance.linlin(44,110, 10000,800).clip(800,10000), 0.5, vol.max(0.1));
	out= VBAP.ar(4, filtout, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).load(s);

SynthDef(\syroform, { arg outbus= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var env, in, out;
	env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
	in= env * RLPF.ar(
		in: LFSaw.ar(mnote + freqBase + mod.linlin(-1,1, -40, 40)),
		freq: LinLin.kr(mod, -1, 1, 80, 30).midicps,
		rq: 0.1,
		mul: ( (amp**2) * mod.linlin(-1,1, 0.01, 0.99) ).clip(0.01, 0.99)
		);
	out= VBAP.ar(4, in, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).load(s);

SynthDef(\syrolsaw, { arg outbus= 0, mod= 0, mnote= 0, freqBase= 85, att=0.5, rel= 1, gate=1, done= 2, amp= 0.3, azimuth= 0, elevation= 0, spread= 0, speakerBuffNum;
	var env, in, out;
	env= EnvGen.kr( Env.asr(att, 1, rel, \sine), gate: gate, doneAction: done );
	in= env * LFSaw.ar(
		freq: mnote + freqBase + mod.linlin(-1,1, -50, 0),
		mul: ( (amp**3) * mod.linlin(-1,1, 0.01, 0.99) ).clip(0.01, 0.99)
		);
	out= VBAP.ar(4, in, speakerBuffNum, azimuth, elevation, spread);
	Out.ar( outbus, out );
	}
).load(s);
)
