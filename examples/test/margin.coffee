export preprocess = ->
  {keepMargins, keepUneven} = svgtiler.getSettings()
  console.log 'Testing with --margin =', keepMargins, 'and --uneven =', keepUneven
  if keepMargins
    console.assert @drawing.keys.length == 5
    if keepUneven
      for i in [0...5]
        console.assert @drawing.keys[i].length == i
    else
      for i in [0...5]
        console.assert @drawing.keys[i].length == 4
  else
    console.assert @drawing.keys.length == 1
    console.assert @drawing.keys[0].length == 4

x: <rect width="50" height="50" fill="blue"/>
' ': <rect width="50" height="50" fill="red"/>
'': <rect width="50" height="50" fill="purple"/>
