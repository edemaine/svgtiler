all: coffee js graph
coffee:
	svgtiler -f map.coffee *.asc
js:
	svgtiler -f map.jsx *.asc
graph:
	svgtiler -f -o graph map.coffee graph.coffee *.asc
