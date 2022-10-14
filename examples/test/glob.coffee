same = (array1, array2) ->
  return false unless array1.length == array2.length
  for item, index in array2
    return false unless item == array2[index]
  true

assertSame = (array1, array2, help) ->
  console.assert same(array1, array2), help

assertSame svgtiler.glob('glob.*'), ['glob.coffee'], 'glob'
assertSame svgtiler.match('glob.coffee', 'glob.*'), true, 'match 1'
assertSame svgtiler.match('glob.js', 'glob.*'), true, 'match 2'
assertSame svgtiler.match('foo.coffee', 'glob.*'), false, 'match 3'
assertSame svgtiler.filter(['glob.coffee', 'glob.js', 'foo.coffee'], 'glob.*'), ['glob.coffee', 'glob.js'], 'filter'
