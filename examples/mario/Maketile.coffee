palettes = ['castle', 'overworld', 'underground', 'underwater']

## Define individual palette rules and a default rule that builds them all.
export make = (palette) ->
  if palette
    svgtiler "-f -s palette=#{palette} -O *_#{palette} mario.coffee door.tsv"
  else
    svgtiler palettes

## Example definition of just the "everything" rule.
#export make = ->
#  for palette in palettes
#    svgtiler "-f -s palette=#{palette} -O *_#{palette} mario.coffee door.tsv"

## Example definition using just a single call to svgtiler()
#export make = ->
#  svgtiler '''
#    -f
#    ( -s palette=castle -O *_castle mario.coffee door.tsv )
#    ( -s palette=overworld -O *_overworld mario.coffee door.tsv )
#    ( -s palette=underground -O *_underground mario.coffee door.tsv )
#    ( -s palette=underwater -O *_underwater mario.coffee door.tsv )
#  '''
