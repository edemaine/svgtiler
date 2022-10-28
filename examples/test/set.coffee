showRow = (row) ->
  (
    for char in row
      if char
        char
      else
        '⎵'
  ).join ''

export preprocess = ->
  console.assert @drawing.keys.length == 1
  console.log 'Before substitution:', showRow @drawing.keys[0]
export postprocess = ->
  console.assert @drawing.keys.length == 2
  console.log 'After substitution: ', showRow @drawing.keys[0]
  console.log '                    ', showRow @drawing.keys[1]

(key) ->
  # Remove any ?s in the next cell
  neighbor = @neighbor 1, 0
  if neighbor.key == '?'
    neighbor.set '!'
  # Add upper-case version below us.
  if @i == 0 and @key != @key.toUpperCase()
    @neighbor(0, 1).set @key.toUpperCase()
  # Support any character except ?, so we get an error if above failed.
  '' unless key == '?'
