coffee: ->
  svgtiler '-f map.coffee *.asc'
js: ->
  svgtiler '-f map.jsx *.asc'
graph: ->
  svgtiler '-f -O graph-* map.coffee graph.coffee *.asc'
'': ->
  svgtiler 'coffee js graph'
