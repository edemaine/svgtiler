export coffee = ->
  svgtiler '-f map.coffee *.asc'
export js = ->
  svgtiler '-f map.jsx *.asc'
export graph = ->
  svgtiler '-f -O graph-* map.coffee graph.coffee *.asc'

export default ->
  coffee()
  js()
  graph()
