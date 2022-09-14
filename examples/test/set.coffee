svgtiler.beforeRender ->
  console.log 'Before substitution:', @drawing.keys[0].join ''
svgtiler.afterRender ->
  console.log 'After substitution:', @drawing.keys[0].join ''

(key) ->
  # Remove any ?s in the next cell
  neighbor = @neighbor 1, 0
  if neighbor.key == '?'
    neighbor.set '!'
  # Support any character except ?, so we get an error if above failed.
  '' unless key == '?'
