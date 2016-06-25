

// do first:
// $ cd ~/dev/kinect/OpenNI-Bin-MacOSX-v1.1.0.41/OSCeleton/
// $ ./osceleton -p 57120

(
Server.default.quit;
Server.default.options.memSize = 99000;
Server.default.options.maxNodes = 65536;
Server.default.options.maxSynthDefs = 65536;
Server.default.options.numBuffers = 8192;
Server.default.options.numAudioBusChannels = 1024;
Server.default.boot;
)


// model - RedUniverse - springs_interconnected
(
s.waitForBoot{
	var responderKinect, responderKinectNewUser, responderKinectLostUser;
 	var springCoords= FloatArray.fill(2, { |i| 0});
	var width= 640, height= 480, w, wgrav, world, n= 18, mp, objs, sprs, syns;

	//--synthesis
	SynthDef(\imp, {|out= 0, freq= 0, phase= 0, cutoff= 800, amp= 0, pan= 0|
		var z;
		z= Ringz.ar(SinOsc.ar(freq, phase.lag(0.1), amp), cutoff, 0.01);
		Out.ar(out, Pan2.ar(z, pan));
	}).send(s);
	s.sync;
	//--kinect
	if(responderKinect != nil, { responderKinect.remove });
	if(responderKinectNewUser != nil, { responderKinectNewUser.remove });
	if(responderKinectLostUser != nil, { responderKinectLostUser.remove });
	responderKinectNewUser = OSCresponderNode(nil, '/new_skel', {arg t, r, msg;
		//msg.postln;
	}).add;
	responderKinectLostUser = OSCresponderNode(nil, '/lost_skel', {arg t, r, msg;
		//msg.postln;
	}).add;
	responderKinect = OSCresponderNode(nil, '/joint', {arg t, r, msg;
		var coords, joint;
		joint = msg[1];
		coords = msg.shift(-3).clipExtend(3);
		joint.switch(
			'torso', {  },
			'l_hand', {
				springCoords[0]= msg[3].linlin(0.16, 0.60, 0, width);
				},
			'r_hand', {
				springCoords[1]= msg[4].linlin(0.5, 0.7, 0, width);
				}
		);
		msg.postln;
	}).add;
	//--world
	w= RedWindow("springs interconnected", Rect(128, 64, width, height)).front;
	//mp= w.mouse;
	mp= springCoords;
	wgrav= RedVector2D[0, 0]; //world xy gravity
	world= RedWorld2(RedVector2D[width, height], wgrav, 99, 0); //dim,grav,maxvel,damp

	//--objects
	objs= {
		var mass= 1.rrand(10);
		RedObject(world, RedVector2D[width.rand, height.rand], RedVector2D[0, 0], RedVector2D[0, 0], mass, mass);
	}.dup(n);
	sprs= objs.collect{|x|
		objs.collect{|y|
			if(x!=y, {
				RedSpring(x, y, 0.2.linrand, 1.0.linrand, 200.rrand(300));
			});
		}.select{|x| x.notNil};
	}.flat;
	syns= {Synth(\imp)}.dup(n);

	//--loop
	w.draw{
		//--render
		Pen.smoothing= true;
		Pen.strokeColor= Color.white;
		sprs.do{|spr|
			spr.update;

			//--render springs
			Pen.moveTo(spr.object.loc.asPoint);
			//Pen.quadCurveTo(spr.target.loc.asPoint, w.mouse.asPoint);
			Pen.quadCurveTo(spr.target.loc.asPoint, springCoords.asPoint);
		};
		Pen.stroke;

		Pen.fillColor= Color.grey(0, 0.5);
		objs.do{|obj, i|
			obj.update;
			world.contain(obj);

			syns[i].set(
				//\cutoff, obj.loc.distance(w.mouse).abs.linexp(0, width.max(height), 200, 2000),
				\cutoff, obj.loc.distance(springCoords).abs.linexp(0, width.max(height), 200, 2000),
				\freq, obj.size,
				\phase, obj.vel.abs.maxItem*1000,
				\amp, 0.01,
				\pan, obj.loc[0].linlin(0, width, -1, 1)
			);

			//--render objects
			Pen.addOval(Rect.aboutRedObject2D(obj));
		};
		Pen.fill;
	};
	w.animate= true;
	CmdPeriod.doOnce({if(w.isOpen, {
		w.close;
		responderKinectNewUser.remove;
		responderKinectLostUser.remove;
		responderKinect.remove;
	})});
}
)

//base
//(
//var responderKinect, responderKinectNewUser, responderKinectLostUser;
//
//responderKinect = OSCresponderNode(nil, '/joint', {arg t, r, msg;
//		var coords, joint;
//		joint = msg[1];
//		coords = msg.shift(-3).clipExtend(3);
//		joint.switch(
//			'torso', {  },
//			'r_hand', { msg.postln },
//			'l_hand', {  }
//		);
////		msg.postln;
//	}).add;
//
//responderKinectNewUser = OSCresponderNode(nil, '/new_skel', {arg t, r, msg;
//	//msg.postln;
//	}).add;
//
//responderKinectLostUser = OSCresponderNode(nil, '/lost_skel', {arg t, r, msg;
//	//msg.postln;
//	}).add;
//)
