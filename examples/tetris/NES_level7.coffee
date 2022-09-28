kind =
  T: 'empty'
  O: 'empty'
  I: 'empty'
  J: 'filled'
  S: 'filled'
  L: 'other'
  Z: 'other'

(key) ->
  if key.trim() == ''
    <rect fill="black" width="8" height="8"/>
  else
    # could just return "./NES_level7_#{kind[key]}.png" here
    # and SVG Tiler will do the same thing;
    # using `require` lets us manipulate/wrap the <image> tag if we want
    require "./NES_level7_#{kind[key]}.png"
