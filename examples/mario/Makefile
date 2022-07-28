all: castle underground underwater overworld

castle:
	svgtiler -P palette_castle.js mario.coffee door.tsv
	mv door.svg door_castle.svg
	mv door.png door_castle.png

overworld:
	svgtiler -P palette_overworld.js mario.coffee door.tsv
	mv door.svg door_overworld.svg
	mv door.png door_overworld.png

underground:
	svgtiler -P palette_underground.js mario.coffee door.tsv
	mv door.svg door_underground.svg
	mv door.png door_underground.png

underwater:
	svgtiler -P palette_underwater.js mario.coffee door.tsv
	mv door.svg door_underwater.svg
	mv door.png door_underwater.png
