export txt = ->
  svgtiler '-f -P --bg black NES_level7.txt example.asc'

export coffee = ->
  svgtiler '-f -P NES_level7.coffee example.asc'

export default ->
  txt()
  coffee()
