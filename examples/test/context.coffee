test = Symbol 'test'

(key) ->
  console.assert @ == svgtiler.getContext() != test
  svgtiler.runWithContext test, ->
    console.assert test == svgtiler.getContext() != @
  ''
