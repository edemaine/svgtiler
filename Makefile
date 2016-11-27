examples: ALWAYS
	coffee svgtiler.coffee --tw 50 --th 50 examples/tilt/*.txt examples/tilt/*.asc
	coffee svgtiler.coffee examples/witness/*.coffee examples/witness/*.asc examples/witness/*.ssv

ALWAYS:
