a = Dictionary[ (-744858701 -> 'a'), (-70322531 -> 'b'), (-868480251 -> 'c') ]
springs: Dictionary[ (-744858701 -> a RedAgent), (-70322531 -> a RedAgent), (-868480251 -> a RedAgent) ]

a = RedObject



k.keys.contains()
a.values.includes('c')


The projection of server nodes to the world objects:

nodes dict = (
    node_id: (
        age: <inf or some real age>
        ctrl: <can be RedBoid, RedObject or RedAgent(hand)>
        objNum: <number of the object for interface (0..9)>
    ),
    (
        ...
    )
)

when object is RedObject and is heavy enough (>= params[\heavy]) it is ready to be absorbed by one of the sceleton's hands:
- check if there sceletons around, simply skip the rest it if not
- pick up a hand (the hand with the smallest mass is most propbable to be choosen)
- add objects mass to the hand
- update nodes list - re-link node to a chosen hand's hash
- remove object from the world

when a synth should be removed, and controlling object is RedAgent (hand):
- clean up the synth
- remove some mass from hand
- from nodes dict removeAt nodeID

when sceleton disappears from the world:
- iterate over `nodes`, pick up all nodes connected to its hands
- calculate mass as ave
- create RedObjects from them
- substitute them in the `nodes` (saving age)

each frame:
- if hands are too light, add mass to them so that they would be not lighter than heaviest