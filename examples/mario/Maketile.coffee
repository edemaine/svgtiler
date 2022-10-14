palettes = ['castle', 'overworld', 'underground', 'underwater']

export default ->
  for palette in palettes
    svgtiler "-f -s palette=#{palette} -O *_#{palette} mario.coffee door.tsv"

export singleRule = ->
  svgtiler '''
    -f
    ( -s palette=castle -O *_castle mario.coffee door.tsv )
    ( -s palette=overworld -O *_overworld mario.coffee door.tsv )
    ( -s palette=underground -O *_underground mario.coffee door.tsv )
    ( -s palette=underwater -O *_underwater mario.coffee door.tsv )
  '''

###
castle:
	svgtiler -f -s palette=castle -O \*_castle mario.coffee door.tsv

overworld:
	svgtiler -f -s palette=overworld -O \*_overworld mario.coffee door.tsv

underground:
	svgtiler -f -s palette=underground -O \*_underground mario.coffee door.tsv

underwater:
	svgtiler -f -s palette=underwater -O \*_underwater mario.coffee door.tsv
###
