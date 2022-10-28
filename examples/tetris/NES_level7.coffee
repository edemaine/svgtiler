kind =
  T: 'empty'
  O: 'empty'
  I: 'empty'
  J: 'filled'
  S: 'filled'
  L: 'other'
  Z: 'other'

export preprocess = -> svgtiler.background 'black'

(key) ->
  if key.trim() == ''
    # allocate space for black background instead of lots of tiny rects
    <symbol width="8" height="8"/>
    #<rect fill="black" width="8" height="8"/>
  else
    # could just return "./NES_level7_#{kind[key]}.png" here
    # and SVG Tiler will do the same thing;
    # using `require` lets us manipulate/wrap the <image> tag if we want
    require "./NES_level7_#{kind[key]}.png"
