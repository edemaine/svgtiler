kind =
  T: 'empty'
  O: 'empty'
  I: 'empty'
  J: 'filled'
  S: 'filled'
  L: 'other'
  Z: 'other'

(key) ->
  if key == ' '
    <rect fill="black" width="8" height="8"/>
  else
    require "./NES_level7_#{kind[key]}.png"
