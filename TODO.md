# TO-DO

## main.scd

Realize scheme in which an output of any Gen synth is mono directed to a
specific  internal audio bus. Map internal buses to spatialization synths
(Ambisonic2,  Ambisonic4, VBAP, etc.).

----------

Rename \outbus to \mainout in all spatializers to keep it in the different params
when sending to the whole group. Update corresponding functions.

----------

Every object should be accopmpanied by the information of the forces that affect
it (dictionary or a binary vector with 1 indicating force and 0 - its
absence). Example: 

[World gravity, World viscosity, World friction, other objects attraction,
collision with other objects, other objects repulsion]

can be represended as [110011]

How will this affect mutual behavior of the objects?

----------

Control World parameters (gravity, viscosity, Star mass, etc) and trigger
creation of objects and particles with MIDI.

This WILL affect params, so, there should be a command 'Revert to factory
settings' available in the interface for both each param and (with warning!)
all params.

----------

get rid of groupAux, everything should get inserted to the root group. Change
aux synths creation from objects to Server messages, add to the head of
rootNodeID.

----------

Obtain currBusAr (in fillSynthGroup) not by incrementing current index, but by
looking for the first free slot in a_BUS_PULL.

----------

Infrastructure for changing synth's scale (via NamedControl).

----------

All conversions should be done on the lang side. Standardize synth params, each 
of which should fall in scope either 0..1, or 0..pi, or 0..2pi.

----------

Move constants c_KEY_OBJ, c_KEY_OBJ_SYNTH to params. More flexible and elegant
scheme of shortcuts appointment.

----------

Move constants o_SCHEDULER_ADDR, o_SKELETON_ADDR to params. Restart (refresh)
OSC communication after change.

----------

Visualization should get scaled to windowSize, not the World dimensions. Replace
params[\worldDim] (World dimensions) with params[\windowSize] related to
Visualisation.

----------

The solution with synthForm and synthSaw connected to feet is non-universal, and
basically ugly. Re-design and re-develop. But first get rid of startFeetSynths
fuction and do everything needed in fillSynthGroup.

----------

Get rid of all Synth objects. Move Server communication to Server messages entirely.

----------

Get rid of the \noisy synth, don't need it anymore. Make it more interesting
sounding, convert into ordinary electronic synth and make available for use (for
example, instead of _doors, which is useless). 

----------

There should not be a limitation of the World capasity. Manage objects in a
separate panel / window, allow for any number of objects, dynamically create
controls, scroll if necessary.

----------

The whole concept of tasks here is ultimately detached from the rest of
infrastructure and features. Make it available for any chosen synth. Before
starting a Task on a Synth, send it a Scale (via Buffer). Scale can be updated,
while playing, via NamedControl.

----------

Visualization: finish idea about "shady" colors as close to the back wall of the
World.

----------

Re-work interface:

* QT paradigm

* drag and drop panels

* new panels for:

** object vs. guide assignment

** internal bus vs. synth vs. object monitoring

----------

On the opening check required files (settings.conf, synthdefs.scd, etc.). If not
found, propose to choose using a dialog.

----------

settings.conf - create a real editable conf file, not just Dictionary
params.asCompileString 

----------

Move TOFIX to git Issues


## synthdef.scd

Add SoundScratcher to Gran synths (there is a good example in XiiSynthDefs.sc).

----------

* \sr__e__lowe to work with harmonic scale along entire Y axis, but with a very
narrow spectrum of notes.

* \sr__e__melo - make somehow sharper, it's way too pretty now. More emphasis on
its Impulse rather than on Saw.

* \sr__e__lfsaw - make it more interesting or resign from it at all, it is too
simple.

----------

Implement synths INSERTs (such as compander).

----------


## scheduler.scd

Hook synth from node to the object and back (only change \busnum?)

----------

Move piece description to external JSON file.
