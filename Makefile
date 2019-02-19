examples: ALWAYS
	npx coffee src/svgtiler.coffee --tw 50 --th 50 examples/tilt/*.txt examples/tilt/*.asc
	npx coffee src/svgtiler.coffee examples/witness/*.coffee examples/witness/*.asc examples/witness/*.ssv

ALWAYS:
