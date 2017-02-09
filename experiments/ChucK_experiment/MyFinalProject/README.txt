Final Project
Denis Kolokol
Physics Based Sound Synthesis at www.kadenze.com, 2016-2017

NIME for skeleton controlled instrument.

The inspiration for this one came from my project for MOON2 band: a bunch of
software synths controlled by a human body with the help of kinect sensor - see
http://moon2.org/. 
OSC data comes from OSCeleton https://github.com/Sensebloom/OSCeleton.

OSC Receiver / Converter
ChucK2OSC.ck receives signals from OSCeleton or any other program, whose OSC
messages format is similar (in this case - an augmented SuperCollider script
that captures Osceleton poutput and adds two yo-yo objects to both hands of the
skeleton).
ChucK2OSC.ck does all the conversion and prepares messages to control synths:

- hands' messages (left_hand, right_hand) provide control values for two
   instruments “attached” to left and right hands: 
  -- re-maps position X of each hand to pan (-1..1)
  -- position Y of each hand is being re-mapped and re-scaled in order to match
       the closest note in the `scale` array (the higher the hand, the higher the
       note it “touches”) 
  -- velocity parameter is being forwarded as is (0..1)
- /torso message:
  -- position Y controls filter frequency
  -- the same position Y, but squared is sent as `vel` parameter, and used as a
       control of filter's quality parameter. 

NB: re-mapping is done in the function `remap` and scaling in `mapToKey`. Most
probably ChucK has something like those ready. Nevertheless I have decided to
white them from scratch, sinse it is a good exercise.

After all the conversions it prepares new OSC messages and sends them further
using address in the following form:
- /inst/right - values converted from right hand
- /inst/left - left hand values
- /filt/lpf - values taken from /torso and made ready for controlling filters

OSCListener
ChucKSound.ck receives OSC messages from ChucK2OSC.ck and uses its values to
control synths. 

`pan` and `freq` have the same meaning for both Moog and Bowed instruments and
control their panorama and pitch respectively. 

- left hand - pulsing Moog sound:
  -- velocity (`vel`) controls filterQ param
  -- it also affects vibrato frequency (being multiplied by 100 for this
      purpose) and vibrato gain (high velocities make vibrato more pronounced)
  -- `pan` (in addition to its primary function) controls Moog's SweepRate
- right hand - Bowed sound:
  -- `pan` (in addition to panorama) control bow position
  -- `vel` controls bow pressure (thus crisp gestures produce more distorted
       output)
  -- vibrato is controlled in the same manner as in the case of Moog

In addition to it there is a delayed percussion line, whose filter and delay
effects depend on the parameters in /filt/lpf message (i.e. /torso joint)
