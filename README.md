Sympli Romatikó
===============

Solid physics in 3D (redUniverse)
controlled by Kinect (via OSCeleton)
in surround sound (Josh Parmenter's ambisonics)


SuperCollider 3.6

Right now it is a shameful pieces of code, but it's getting better, slowly but
surely.

Doc, dependencies and tests are to come shortly

calibration
$ cd /path/to/kinect/libfreenect/build/bin
$ ./glview

OSCeleton (with multiplier for depth!):
$ /path/to/OSCeleton/osceleton -p 57120 -mz 0.7

(notice the correction for depth, see OSCeleton help for more details)

## Keyboard shortcuts

N - new object (???)

X - clean all objects and synths

C - clean all buffer players

V - (press and hold) remove all forces

Z - info on objects and synths

L - start/stop "feet" synths - fade in/out

Alt+L - start/stop "feet" synths - hot

1, 2, .., 0 - delete obj by its index

Init objects (press & hold for rec into buffer or press for cyclic buffer):

        Q - regular (fountain), light (mass <= 2)

        W - drone, light (mass <= 2)

        E - "gusts of wind" (stutter), heavy (2 < mass <= 5)

        R - slicing, variable (0.5 < mass <= 5)

        T - loop, variable (0.5 < mass <= 5)

        Y - loop with random trigger time, variable (0.5 < mass <= 5)

        U - electronic "probe"

        I - electronic "CMB"

        O - electronic "star field"

        A - trigger \ev_start

