// fill scale
// dorian
d = [0, 2, 3, 5, 7, 9, 10];
c = d;

5.do { |i|
	if (i > 0) {
		((12 + c) * i).postln;
		d = d ++ ((12 + c) * i)
	}
}
