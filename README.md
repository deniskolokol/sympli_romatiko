Sympli Romatikó
===============

Solid physics in 3D (redUniverse)
controlled by Kinect (via OSCeleton)
in surround sound (Josh Parmenter's ambisonics)

Requirements:

* SuperCollider 3.6
* Quarks > TraerPhysics
* Quarks > MathLib
* Extensions > SC3plugins > JoshUGens

calibration:

    $ cd /path/to/kinect/libfreenect/build/bin
    $ ./freenect-glview

OSCeleton (here with multiplier for depth):

    $ /path/to/OSCeleton/osceleton -p 57120 -mz 0.7

(notice the correction for depth, see OSCeleton help for more details)
