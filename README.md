# Sympli Romatikó

Simple solid physics in 3D controlled by Kinect in surround sound.

## Install packages
* Install **Sensebloom OSCeleton** https://github.com/Sensebloom/OSCeleton
* Install **SuperCollider** http://supercollider.github.io/download  **WARNING!** As of time of writing, it has been tested only on OS X with SuperCollider 3.6.6. Use on your own risk with newer versions of SuperCollider and/or different systems (at this stage no support for Windows).
* In SuperCollider add quarks **MathLib** and **TraerPhysics** (Cmd+E -> Quarks.gui -> mark quarks and hit "Recompile Class Library" after finishing)
* Install **sc3-plugins** https://github.com/supercollider/sc3-plugins
* Optional: you might also want to install **libfreenect** https://github.com/OpenKinect/libfreenect (useful for calibration)

## Working?
In **SuperCollider** open `envi.scd` from this repo, select all and run it (`Cmd + Return`). If everything went smooth, you will see the following image. This means it is working.
 ...
## Calibrate your sound system
* Add as many speakers as you need by holding `Ctrl` button and clicking somewhere on the central area withing the purple circle.
* Using the "max dist" slider on the control panel (the right side), set up a distance to the furthest speaker (in meters)
* Drag speakers by mouse so that they would be in a relative positions to you, as if you were sitting in the center of the dark purple cirle
* Test the configuration: any button on the bottom of the screen launches an object with a certain Synth. If you hear a sound "following" an object (yellow dot), all is good.
* Delete objects and synths by pressing `X` button (on the keyboard or control panel on the right).

## Add skeleton
* Connect Kinect sensor to the computer and place it at a distance of 2.5 - 3 meters from where you standing.
* Run Osceleton `$ /path/to/OSCeleton/osceleton -p 57120`
* Make sure you see something like "Tracking user 1" on the screen
* Switch to SuperCollider and wait a second or two - a "skeleton" should appear automatically.
* Now launching objects from the bottom panel will cause them to "stick" to skeletons hands. Play!

## Calibration
Ensure your "avatar" is standing in the center and facing the speakers. You might move your kinect forth and back to achieve this. You can also add depth multiplier **-mz** or offset **-oz**, for example:

`$ /path/to/OSCeleton/osceleton -p 57120 -oz 0.3`

If you installed **libfreenect**, run a glview utility:

`$ /path/to/libfreenect/build/bin/freenect-glview`. 

By pressing continuously `W` or `X` keys on the keyboard set up the most suitable angle of view for the camera. Then run osceleton again, return to the program  and play!
