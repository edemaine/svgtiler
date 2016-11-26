path = require 'path'
fs = require 'fs'
csvParse = require 'csv-parse'

splitIntoLines = (data) ->
  data.replace('\r\n', '\n').replace('\r', '\n').split('\n')
whitespace = /[\s\uFEFF\xA0]+/  ## based on https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/Trim

class Input
  @encoding: 'utf8'
  @parseFile: (filename) ->
    input = @parse fs.readFileSync filename,
      encoding: @encoding
    input.filename = filename
    input
  @load: (filename) ->
    extension = path.extname filename
    if extension of extension_map
      extension_map[extension].parseFile filename
    else
      throw new UserException "svgtiler: unrecognized extension in filename #{filename}"

class Mapping extends Input

class ASCIIMapping extends Mapping
  @parse: (data) ->
    map = new @
    for line in splitIntoLines data
      separator = whitespace.exec line
      continue unless separator?
      if separator.index == 0
        key = line[0]  ## Whitespace at beginning means defining whitespace
      else
        key = line[...separator.index]
      value = line[separator.index + separator[0].length..]
      map[key] = value
    map

class CoffeeMapping extends Mapping

class Drawing extends Input
  constructor: (@data) ->
  writeSVG: (mappings, filename) ->
    ## Default filename is the input filename with extension replaced by .svg
    unless filename?
      filename = path.parse @filename
      if filename.ext == '.svg'
        filename.base += '.svg'
      else
        filename.base = filename.base[...-filename.ext.length] + '.svg'
      filename = path.format filename
    console.log '->', filename
    fs.writeFileSync filename, @renderSVG mappings
  renderSVG: (mappings) ->
    for row, i in @data
      for cell, j in row
        console.log i, j, cell, mappings.lookup cell

class Mappings
  constructor: (@maps = []) ->
  push: (map) ->
    @maps.push map
  lookup: (key) ->
    for i in [@maps.length-1..0]
      map = @maps[i]
      if key of map
        return map[key]
    null

class ASCIIDrawing extends Drawing
  @parse: (data) ->
    new @ splitIntoLines data

class DSVDrawing extends Drawing
  @parse: (data) ->
    new @ csvParse data,
      delimeter: @delimeter

class SSVDrawing extends DSVDrawing
  @delimeter: ' '

class CSVDrawing extends DSVDrawing
  @delimeter: ','

class TSVDrawing extends DSVDrawing
  @delimeter: '\t'

extension_map =
  '.txt': ASCIIMapping
  '.coffee': CoffeeMapping
  '.asc': ASCIIDrawing
  '.ssv': SSVDrawing
  '.csv': CSVDrawing
  '.tsv': TSVDrawing

main = ->
  mappings = new Mappings
  for filename in process.argv[2..]
    console.log '*', filename
    input = Input.load filename
    if input instanceof Mapping
      mappings.push input
    else if input instanceof Drawing
      input.writeSVG mappings

unless window?
  main()
