# TO-DO

## main.scd

Realize scheme in which an output of any Gen synth is mono directed to a
specific  internal audio bus. Map internal buses to spatialization synths
(Ambisonic2,  Ambisonic4, VBAP, etc.).

----------

Rename \outbus to \mainout in al spatializers to keep it in the different params
when sending to the whole group. Update corresponding functions.

----------

Control World parameters (gravity, viscosity, Star mass, etc) and trigger
creation of objects and particles with MIDI.

----------

get rid of groupAux, everything should get inserted to the root group. Change
aux synths creation from objects to Server messages, add to the head of
rootNodeID.

----------

Figure out currBusAr (in fillSynthGroup) not by incrementing current index, but
by looking for the first free slot in a_BUS_PULL.

----------

Add SoundScratcher to Gran synths (refer to XiiSynthDefs.sc for example).

----------

Infrastructure for changing synth's scale (via NamedControl).

----------

All conversions should be done on the lang side. Standardize the synth params,
each of which should fall in scope either 0..1, or 0..pi, or 0..2pi.

----------

Move constants c_KEY_OBJ, c_KEY_OBJ_SYNTH to params. More flexible and elegant
scheme of shortcuts appointment.

----------

Move constants o_SCHEDULER_ADDR, o_SKELETON_ADDR to params. Restart (refresh)
OSC communication after change.

----------

Replace params[\worldDim] (World dimensions) with params[\windowSize] related to
Visualisation. Visualization should get scaled to windowSize, not the World
dimensions.

----------

The solution with synthForm and synthSaw connected to feet is non-universal, and
basically ugly. Re-design and re-develop. But first get rid of startFeetSynths
fuction and do everything needed in fillSynthGroup.

----------

Implement synths INSERTs (such as compander).

----------

Clean out all Synth objects. Move Server communication to Server messages.

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

Synths:
- \sr__e__lowe to work with harmonic scale along entire Y axis, but with a very
narrow spectrum of notes.
- \sr__e__melo - make somehow sharper, it's way too pretty now. More emphasis on
its Impulse rather than on Saw.
- \sr__e__lfsaw - make it more interesting or resign from it at all, it is too
simple.

----------

Every object should be accopmpanied by the information of the forces that affect
it (dictionary or a binary vector with 1 indicating force and 0 - its
absence). Example: 

[World gravity, World viscosity, World friction, other objects attraction,
collision with other objects, other objects repulsion]

can be represended as [110011]

How will this affect mutual behavior?

----------

Re-work interface:
- QT paradigm
- drag and drop panels
- new panels for:
-- object vs. guide assignment



## scheduler.scd

Hook synth from node to the object and back (only change \busnum?)

----------

Move piece description to external JSON file.