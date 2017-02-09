//  Listen for all incoming messages on port
OscIn oin;        // make an OSC receiver
6448 => oin.port;  // set port #
oin.listenAll();  //   any message at all

OscOut xmit;    // Make a new OSC sender object
6449 => int port; // set port number (important to remember this!!)
xmit.dest ( "localhost", port ); // open on local host

OscMsg msg;   // message holder

[
    0, 2, 3, 5, 7, 9, 10,
    12, 14, 15, 17, 19, 21, 22,
    24, 28, 30, 34, 38, 42, 44,
    36, 42, 45, 51, 57, 63, 66,
    48, 56, 60, 68, 76, 84, 88
] @=> int scale[];
(scale.cap()-1) $ float => float scaleCap;
12 => int key; // in the key of C3

0.0 => float panL;
0.0 => float panR;
432.0 => float freqL;
432.0 => float freqR;

while(true) {
    oin => now;   // wait for any OSC
    while(oin.recv(msg))
    {
        msg.address => string address;
        msg.getString(0) => string joint;
        msg.getInt(1) => int skelNum;
        msg.getFloat(2) => float posX;
        msg.getFloat(3) => float posY;
        msg.getFloat(4) => float posZ;
        msg.getFloat(5) => float vel;

        if (joint == "l_hand") {
            remap(posX, 0.0, 1.0, -1.0, 1.0) => float panL;
            remap(posY, 0.0, 1.0, scaleCap, 0.0) => float freqL;
            xmit.start("/inst/left");
            panL => xmit.add;
            mapToKey(freqL) => xmit.add;
            vel => xmit.add;
            xmit.send();
            <<< "message: /inst/left", panL, freqL, vel >>>;
        }
        if (joint == "r_hand") {
            remap(posX, 0.0, 1.0, -1.0, 1.0) => float panR;
            remap(posY, 0.0, 1.0, scaleCap, 0.0) => float freqR;
            xmit.start( "/inst/right");
            panR => xmit.add;
            mapToKey(freqR) => xmit.add;
            vel => xmit.add;
            xmit.send();
            <<< "message: /inst/right", panR, freqR, vel >>>;
        }
        if (joint == "torso") {
            xmit.start( "/filt/lpf");
            0 => xmit.add; // dummy
            remap(posY, 0.3, 0.7, 10000.0, 75.0) => float freq;
            freq => xmit.add; // filter freq
            Math.max(Math.sqrt(posY), 0.1) => float vel;
            Math.max(Math.sqrt(posY), 0.1) => xmit.add;
            xmit.send();
            <<< "message: /filt/lpf", 0.0, freq, vel >>>;
        }
    }
}

// Re-maps value x from [minFro, maxFro] to [minTo, maxTo].
// To scale to 0..1 and the like, minTo and maxTo should be floats.
fun float remap(float x, float minFro, float maxFro, float minTo, float maxTo) {
    // range check
    if (minFro == maxFro) {
        <<< "Warning: Zero input range" >>>;
        return x;
    }
    if (minTo == maxTo) {
        <<< "Warning: Zero output range" >>>;
        return x;
    }
    // check reversed input range
    0 => int reverseInput;
    Math.min(minFro, maxFro) => float minOld;
    Math.max(minFro, maxFro) => float maxOld;
    if (minOld != minFro) 1 => reverseInput;
    // check reversed output range
    0 => int reverseOutput;
    Math.min(minTo, maxTo) => float minNew;
    Math.max(minTo, maxTo) => float maxNew;
    if (minNew != minTo) 1 => reverseOutput;
    ((x - minOld) * (maxNew - minNew) / (maxOld - minOld)) => float portion;
    if (reverseInput) {
        ((maxOld - x) * (maxNew - minNew) / (maxOld - minOld)) => portion;
    }
    (portion + minNew) => float result;
    if (reverseOutput) {
        (maxNew - portion) => result;
    }
    return result;
}

// Re-maps val from [lo .. hi] to [0..len(rag)-1]
// warning! cheap and dirty
fun float mapToKey(float val) {
    val $ int => int pos;
    (scale[pos] + key) => float note;
    return Std.mtof(note);
}
