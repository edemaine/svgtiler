path = require 'path'
fs = require 'fs'
csvParse = require 'csv-parse'

class Input
  @parseFile: (filename) ->
    input = @parse fs.readFileSync filename
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

class CoffeeMapping extends Mapping

class Drawing extends Input
  constructor: (@data) ->

class ASCIIDrawing extends Drawing
  @parse: (data) ->
    new @ data.replace('\r\n', '\n').replace('\r', '\n').split('\n')

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


