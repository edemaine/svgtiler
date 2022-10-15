palettes = ['castle', 'overworld', 'underground', 'underwater']

## Define individual palette rules and a default rule that builds them all.
for palette in palettes
  exports[palette] = do (palette) -> ->
    svgtiler "-f -s palette=#{palette} -O *_#{palette} mario.coffee door.tsv"

export default ->
  for palette in palettes
    exports[palette]()

## Example definition of just the "everything" rule.
export simple = ->
  for palette in palettes
    svgtiler "-f -s palette=#{palette} -O *_#{palette} mario.coffee door.tsv"

## Example definition using just s single call to svgtiler()
export singleCall = ->
  svgtiler '''
    -f
    ( -s palette=castle -O *_castle mario.coffee door.tsv )
    ( -s palette=overworld -O *_overworld mario.coffee door.tsv )
    ( -s palette=underground -O *_underground mario.coffee door.tsv )
    ( -s palette=underwater -O *_underwater mario.coffee door.tsv )
  '''
