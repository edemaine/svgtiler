examples: ALWAYS
	npm run prepare
	node lib/svgtiler.js --tw 50 --th 50 examples/tilt/*.txt examples/tilt/*.asc
	node lib/svgtiler.js examples/witness/*.coffee examples/witness/*.asc examples/witness/*.ssv

ALWAYS:
