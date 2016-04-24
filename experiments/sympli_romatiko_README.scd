Sympli Ro̱matikó

Solid physics in 3D (redUniverse)
controlled by Kinect (via OSCeleton)
in surround sound (Josh Parmenter's ambisonics)

calibration
$ cd /path/to/kinect/libfreenect/build/bin
$ ./glview

OSCeleton (with multiplier for depth!):
$ cd /Users/deniskolokol/dev/kinect/OpenNI-Bin-MacOSX-v1.1.0.41/OSCeleton/
$ ./osceleton -p 57120 -mz 0.7

keyboard:
        N - new object (???)
        X - clean all objects and synths
        C - clean all buffer players
        V - (press and hold) remove all forces
        Z - info on objects and synths
        L - start/stop "feet" synths - fade in/out
        Alt+L - start/stop "feet" synths - hot
        1, 2, .., 0 - delete obj by its index
        --init objects (press & hold for, rec into buffer or press for cyclic buffer):
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

TO-DO:
* BUG! After many openings of the system:
  ERROR: No more buffer numbers -- free some buffers before allocating more.
  - this is caused by speakerBuff of VBAP synths, see:
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
    It should be one buffer, only bufnum should be sent to synths, and it should be cleared on shundown
