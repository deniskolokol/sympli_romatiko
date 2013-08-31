TO FIX


----------

After many openings of the system:
  ERROR: No more buffer numbers -- free some buffers before allocating more.
Possible cause: speakerBuff of VBAP synths, see the line
    speakerBuff= VBAPSpeakerArray.new(2, speakerAzim).loadToBuffer;
It should be one buffer, only bufnum should be sent to synths, and it should be
cleared on shundown

----------

For objects and sceleton "ceiling" and "floor" are messed up in the
visualization (while being correct in sound processing).

----------

DONE: Creation of any synth results in a buffer allocation! Use this only in case of
granular synths.
