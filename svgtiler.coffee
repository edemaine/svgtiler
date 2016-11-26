path = require 'path'
fs = require 'fs'
CoffeeScript = require 'coffee-script'
csvParse = require 'csv-parse'
xmldom = require 'xmldom'
DOMParser = xmldom.DOMParser
domImplementation = new xmldom.DOMImplementation()
XMLSerializer = xmldom.XMLSerializer

SVGNS = 'http://www.w3.org/2000/svg'
XLINKNS = 'http://www.w3.org/1999/xlink'

splitIntoLines = (data) ->
  data.replace('\r\n', '\n').replace('\r', '\n').split('\n')
whitespace = /[\s\uFEFF\xA0]+/  ## based on https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/Trim

class Symbol
  constructor: (@key, @svg) ->
    @xml = new DOMParser().parseFromString @svg
  @parse: (key, text) ->
    new @ key, text
  id: ->
    ## Valid Name characters: https://www.w3.org/TR/2008/REC-xml-20081126/#NT-Name
    ## Removed colon to avoid potential conflict with hex expansion.
    ## Also prepend 's' to avoid bad starting characters.
    's' +
      @key.replace /[^-\w.\xC0-\xD6\xD8-\xF6\xF8-\u02FF\u0370-\u037D\u037F-\u1FFF\u200C-\u200D\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD\xB7\u0300-\u036F\u203F-\u2040]/,
      (m) -> ':' + m.charCodeAt(0).toString 16
#[\u10000-\uEFFFF]

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
  constructor: (data) ->
    if data?
      for own key, value of data
        unless value instanceof Symbol
          value = Symbol.parse key, value
        @[key] = value

class ASCIIMapping extends Mapping
  @parse: (data) ->
    map = {}
    for line in splitIntoLines data
      separator = whitespace.exec line
      continue unless separator?
      if separator.index == 0
        key = line[0]  ## Whitespace at beginning means defining whitespace
      else
        key = line[...separator.index]
      value = Symbol.parse key, line[separator.index + separator[0].length..]
      map[key] = value
    new @ map

class JSMapping extends Mapping
  @parse: (data) ->
    new @ eval data

class CoffeeMapping extends Mapping
  @parse: (data) ->
    new @ CoffeeScript.eval data

class Drawing extends Input
  tileWidth: 50
  tileHeight: 50
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
    doc = domImplementation.createDocument SVGNS, 'svg'
    svg = doc.documentElement
    svg.setAttributeNS null, 'xmlns', SVGNS
    svg.setAttributeNS null, 'xmlns:xlink', XLINKNS
    svg.setAttributeNS null, 'version', '1.1'
    #svg.appendChild defs = doc.createElementNS SVGNS, 'defs'
    ## Find which symbols are actually used.
    symbols = {}
    for row, y in @data
      for cell, x in row
        symbol = mappings.lookup cell
        #continue unless symbol?
        symbols[symbol.key] = symbol
    ## Include the symbols
    for key, symbol of symbols
      svg.appendChild node = doc.createElementNS SVGNS, 'symbol'
      node.setAttribute 'id', symbol.id()
      node.appendChild symbol.xml
    ## Use the symbols according to the drawing
    width = 0
    for row, y in @data
      for cell, x in row
        symbol = mappings.lookup cell
        continue unless symbol?
        svg.appendChild use = doc.createElementNS SVGNS, 'use'
        use.setAttributeNS XLINKNS, 'xlink:href', '#' + symbol.id()
        use.setAttributeNS null, 'x', x * @tileWidth
        use.setAttributeNS null, 'y', y * @tileHeight
        use.setAttributeNS null, 'width', @tileWidth
        use.setAttributeNS null, 'height', @tileHeight
        #console.log i, j, cell, symbol
        if (x+1) * @tileWidth > width
          width = (x+1) * @tileWidth
    height = @data.length * @tileHeight
    svg.setAttributeNS null, 'viewBox', "0 0 #{width} #{height}"
    svg.setAttributeNS null, 'width', width
    svg.setAttributeNS null, 'height', height
    svg.setAttributeNS null, 'preserveAspectRatio', 'xMinYMin meet'
    '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">

''' +
      new XMLSerializer().serializeToString doc

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
  '.js': JSMapping
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
