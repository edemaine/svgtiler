all: build examples

build:
	npm run prepare

examples: ALWAYS
	node lib/svgtiler.js --tw 50 --th 50 examples/tilt/tilt.txt examples/tilt/*.asc
	node lib/svgtiler.js examples/witness/witness.coffee examples/witness/*.asc examples/witness/*.ssv
	node lib/svgtiler.js -P examples/tetris/NES_level7.txt examples/tetris/example.asc
	node lib/svgtiler.js examples/auto/auto.txt examples/auto/grid.asc
	node lib/svgtiler.js examples/unicode/maze.txt examples/unicode/maze.asc

ALWAYS:
