keepUneven = null
export init = ->
  keepUneven = svgtiler.getSettings().keepUneven
  console.log 'Testing with --uneven =', keepUneven

->
  margins = @drawing.margins
  console.assert 1 == margins.top and
    2 == margins.bottom == margins.left == margins.right, 'margins'

  console.assert undefined == @at(0, -4).key == @at(0, -5).key, 'row -1'
  console.assert 'a' == @at(0, 0).key == @at(-3, 0).key == @at(0, -3).key == @at(-3, -3).key, 'a'
  console.assert 'b' == @at(1, 0).key == @at(-2, 0).key == @at(1, -3).key == @at(-2, -3).key, 'b'
  console.assert 'c' == @at(2, 0).key == @at(-1, 0).key == @at(2, -3).key == @at(-1, -3).key, 'c'
  console.assert undefined == @at(3, 0).key == @at(-4, 0).key == @at(3, -3).key == @at(-4, -3).key, 'row 0'

  if keepUneven
    console.assert 'd' == @at(0, 1).key == @at(-2, 1).key == @at(0, -2).key == @at(-2, -2).key, 'd'
    console.assert 'e' == @at(1, 1).key == @at(-1, 1).key == @at(1, -2).key == @at(-1, -2).key, 'e'
    console.assert undefined == @at(2, 1).key == @at(-3, 1).key == @at(2, -2).key == @at(-3, -2).key, 'row 1'
    console.assert 'f' == @at(0, 2).key == @at(-1, 2).key == @at(0, -1).key == @at(-1, -1).key, 'f'
    console.assert undefined == @at(1, 2).key == @at(-2, 2).key == @at(1, -1).key == @at(-2, -1).key, 'row 2'
    console.assert undefined == @at(0, 3).key == @at(1, 3).key == @at(-1, 3).key == @at(-2, 3).key, 'row 3'
    console.assert undefined == @at(0, 4).key == @at(1, 4).key == @at(-1, 4).key == @at(-2, 4).key, 'row 4'

  else
    unevenLengths = @drawing.unevenLengths
    console.assert unevenLengths?.length == 3 and unevenLengths[0] == 3 and
      unevenLengths[1] == 2 and unevenLengths[2] == 1, 'unevenLengths'

    console.assert 'd' == @at(0, 1).key == @at(-3, 1).key == @at(0, -2).key == @at(-3, -2).key, 'd'
    console.assert 'e' == @at(1, 1).key == @at(-2, 1).key == @at(1, -2).key == @at(-2, -2).key, 'e'
    console.assert '' == @at(2, 1).key == @at(-1, 1).key == @at(2, -2).key == @at(-1, -2).key, 'row 1 blank'
    console.assert undefined == @at(3, 1).key == @at(-4, 1).key == @at(3, -2).key == @at(-4, -2).key, 'row 1'
    console.assert 'f' == @at(0, 2).key == @at(-3, 2).key == @at(0, -1).key == @at(-3, -1).key, 'f'
    console.assert '' == @at(1, 2).key == @at(1, -1).key == @at(-2, 2).key == @at(-2, -1).key == @at(2, 2).key == @at(-1, 2).key == @at(2, -1).key == @at(-1, -1).key, 'row 2 blank'
    console.assert undefined == @at(3, 2).key == @at(-4, 2).key == @at(3, -1).key == @at(-4, -1).key, 'row 2'
    console.assert undefined == @at(0, 3).key == @at(1, 3).key == @at(-1, 3).key == @at(-2, 3).key, 'row 3'
    console.assert undefined == @at(0, 4).key == @at(1, 4).key == @at(-1, 4).key == @at(-2, 4).key, 'row 4'
  ''
