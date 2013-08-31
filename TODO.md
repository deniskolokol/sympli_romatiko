TO CONSIDER

for future development


----------

Move physics to Python module, run it on Raspberry PI(s), connect with it via OSC

----------

Move sound design part into a different module, build it on a modular
principle. Every time a World object is created, it should build the hierarchy
of all defined Groups, Nodes, Synths and Buses for a defined synth.

'Main' module should become a control center for:

* assigning objects' properties to synth params

* assigning World properties 

* signal visualization of each synth module

* 3-D visualization of the World
