path = require 'path'
fs = require 'fs'
CoffeeScript = require 'coffee-script'
csvParse = require 'csv-parse'
xmldom = require 'xmldom'
DOMParser = xmldom.DOMParser
domImplementation = new xmldom.DOMImplementation()
XMLSerializer = xmldom.XMLSerializer
prettyXML = require('prettify-xml')

SVGNS = 'http://www.w3.org/2000/svg'
XLINKNS = 'http://www.w3.org/1999/xlink'

splitIntoLines = (data) ->
  data.replace('\r\n', '\n').replace('\r', '\n').split('\n')
whitespace = /[\s\uFEFF\xA0]+/  ## based on https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/Trim

class SVGTilerException
  constructor: (@message) ->
  toString: ->
    "svgtiler: #{@message}"

svgBBox = (xml) ->
  ## xxx Many unsupported features!
  ##   - transformations
  ##   - used symbols/defs
  ##   - paths
  ##   - text
  if xml.documentElement.hasAttribute 'viewBox'
    xml.documentElement.getAttribute('viewBox').split /\s*,?\s+/
    .map parseFloat
  else
    recurse = (node) ->
      if node.nodeType != node.ELEMENT_NODE or
         node.tagName in ['defs', 'symbol', 'use']
        return [null, null, null, null]
      switch node.tagName
        when 'rect'
          [parseFloat node.getAttribute('x') or 0
           parseFloat node.getAttribute('y') or 0
           parseFloat node.getAttribute('width') or '100%'
           parseFloat node.getAttribute('height') or '100%']
        when 'circle'
          cx = parseFloat node.getAttribute('cx') or 0
          cy = parseFloat node.getAttribute('cy') or 0
          r = parseFloat node.getAttribute('r') or 0
          [cx - r, cy - r, 2*r, 2*r]
        when 'ellipse'
          cx = parseFloat node.getAttribute('cx') or 0
          cy = parseFloat node.getAttribute('cy') or 0
          rx = parseFloat node.getAttribute('rx') or 0
          ry = parseFloat node.getAttribute('rx') or 0
          [cx - rx, cy - ry, 2*rx, 2*ry]
        when 'line'
          x1 = parseFloat node.getAttribute('x1') or 0
          y1 = parseFloat node.getAttribute('y1') or 0
          x2 = parseFloat node.getAttribute('x2') or 0
          y2 = parseFloat node.getAttribute('y2') or 0
          xmin = Math.min x1, x2
          ymin = Math.min y1, y2
          [xmin, ymin, Math.max(x1, x2) - xmin, Math.max(y1, y2) - ymin]
        when 'polyline', 'polygon'
          points = for point in node.getAttribute('points').trim().split /\s+/
                     for coord in point.split /,/
                       parseFloat coord
          xs = (point[0] for point in points)
          ys = (point[1] for point in points)
          xmin = Math.min xs...
          ymin = Math.min ys...
          [xmin, ymin, Math.max(xs...) - xmin, Math.max(ys...) - ymin]
        else
          viewBoxes = (recurse(child) for child in node.childNodes)
          xmin = Math.min (viewBox[0] for viewBox in viewBoxes when viewBox[0])...
          ymin = Math.min (viewBox[1] for viewBox in viewBoxes when viewBox[1])...
          xmax = Math.max (viewBox[0]+viewBox[2] for viewBox in viewBoxes when viewBox[0] and viewBox[2])...
          ymax = Math.max (viewBox[1]+viewBox[3] for viewBox in viewBoxes when viewBox[1] and viewBox[3])...
          [xmin, ymin, xmax - xmin, ymax - ymin]
    viewBox = recurse xml.documentElement
    if Infinity in viewBox or -Infinity in viewBox
      null
    else
      viewBox

class Symbol
  constructor: (@key, options) ->
    for own key, value of options
      @[key] = value
    @xml = new DOMParser().parseFromString @svg
    @viewBox = svgBBox @xml
    @width = @height = null
    if @viewBox?
      @width = @viewBox[2]
      @height = @viewBox[3]
    if @constructor.forceWidth?
      @width = @constructor.forceWidth
    if @constructor.forceHeight?
      @height = @constructor.forceHeight
    warnings = []
    unless @width?
      warnings.push 'width'
      @width = 0 unless @width?
    unless @height?
      warnings.push 'height'
      @height = 0 unless @height?
    if warnings.length > 0
      console.warn "Failed to detect #{warnings.join ' and '} of SVG for symbol '#{@key}'"
  @parse: (key, text) ->
    new @ key,
      if typeof text == 'string'
        if text.indexOf('<') < 0  ## No <'s -> interpret as filename
          filename: text
          svg: fs.readFileSync filename,
                 encoding: @encoding
        else
          svg: text
  id: ->
    ## Valid Name characters: https://www.w3.org/TR/2008/REC-xml-20081126/#NT-Name
    ## Couldn't represent the range [\u10000-\uEFFFF]
    ## Removed colon (:) to avoid potential conflict with hex expansion.
    ## Also prepend 's' to avoid bad starting characters.
    's' +
      @key.replace /[^-\w.\xC0-\xD6\xD8-\xF6\xF8-\u02FF\u0370-\u037D\u037F-\u1FFF\u200C-\u200D\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD\xB7\u0300-\u036F\u203F-\u2040]/,
      (m) -> ':' + m.charCodeAt(0).toString 16

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
      throw new SVGTilerException "Unrecognized extension in filename #{filename}"

class Mapping extends Input
  constructor: (data) ->
    if data?
      for own key, value of data
        unless value instanceof Symbol
          value = Symbol.parse key, value
        @[key] = value

class ASCIIMapping extends Mapping
  @title: "ASCII mapping file"
  @help: "Each line is <symbol-name><space><raw SVG or filename.svg>"
  @parse: (data) ->
    map = {}
    for line in splitIntoLines data
      separator = whitespace.exec line
      continue unless separator?
      if separator.index == 0
        key = line[0]  ## Whitespace at beginning means defining whitespace
      else
        key = line[...separator.index]
      map[key] = line[separator.index + separator[0].length..]
    new @ map

class JSMapping extends Mapping
  @title: "JavaScript mapping file"
  @help: "Object mapping symbol names to SYMBOL e.g. dot: 'dot.svg'"
  @parse: (data) ->
    new @ eval data

class CoffeeMapping extends Mapping
  @title: "CoffeeScript mapping file"
  @help: "Object mapping symbol names to SYMBOL e.g. dot: 'dot.svg'"
  @parse: (data) ->
    new @ CoffeeScript.eval data

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
      if symbol.viewBox?
        node.setAttribute 'viewBox', symbol.viewBox
      if symbol.xml.documentElement.tagName in ['svg', 'symbol']
        ## Remove a layer of indirection for <svg> and <symbol>
        for attribute in symbol.xml.documentElement.attributes
          unless attribute in ['version'] or attribute[...5] == 'xmlns'
            node.setAttribute attribute.name, attribute.value
        for child in symbol.xml.documentElement.childNodes
          node.appendChild child.cloneNode true
      else
        node.appendChild symbol.xml.documentElement.cloneNode true
    ## Use the symbols according to the drawing
    width = 0
    y = 0
    for row in @data
      rowHeight = 0
      x = 0
      for cell in row
        symbol = mappings.lookup cell
        continue unless symbol?
        svg.appendChild use = doc.createElementNS SVGNS, 'use'
        #console.log i, j, cell, symbol
        use.setAttributeNS XLINKNS, 'xlink:href', '#' + symbol.id()
        use.setAttributeNS null, 'x', x
        use.setAttributeNS null, 'y', y
        use.setAttributeNS null, 'width', symbol.width
        use.setAttributeNS null, 'height', symbol.height
        x += symbol.width
        if symbol.height > rowHeight
          rowHeight = symbol.height
      if x > width
        width = x
      y += rowHeight
    height = y
    svg.setAttributeNS null, 'viewBox', "0 0 #{width} #{height}"
    svg.setAttributeNS null, 'width', width
    svg.setAttributeNS null, 'height', height
    svg.setAttributeNS null, 'preserveAspectRatio', 'xMinYMin meet'
    '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">

''' +
      prettyXML new XMLSerializer().serializeToString doc

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
  @title: "ASCII drawing (one character per symbol)"
  @parse: (data) ->
    new @ splitIntoLines data

class DSVDrawing extends Drawing
  @parse: (data) ->
    new @ csvParse data,
      delimeter: @delimeter

class SSVDrawing extends DSVDrawing
  @title: "Space-delimeter drawing (one word per symbol)"
  @delimeter: ' '

class CSVDrawing extends DSVDrawing
  @title: "Comma-separated drawing (spreadsheet export)"
  @delimeter: ','

class TSVDrawing extends DSVDrawing
  @title: "Tab-separated drawing (spreadsheet export)"
  @delimeter: '\t'

extension_map =
  '.txt': ASCIIMapping
  '.js': JSMapping
  '.coffee': CoffeeMapping
  '.asc': ASCIIDrawing
  '.ssv': SSVDrawing
  '.csv': CSVDrawing
  '.tsv': TSVDrawing

help = ->
  console.log """
Usage: #{process.argv[0]} #{process.argv[1]} (...options and filenames...)
--help [-h] [-tw TILE_WIDTH] [-th TILE_HEIGHT] ...

Optional arguments:
  --help                Show this help message and exit.
  --tw TILE_WIDTH / --tile-width TILE_WIDTH
                        Force all symbol tiles to have specified width
                        (default: null, which means read width from SVG)
  --th TILE_HEIGHT / --tile-height TILE_HEIGHT
                        Force all symbol tiles to have specified height
                        (default: null, which means read height from SVG)

Filename arguments:  (mappings before drawings!)

"""
  for extension, klass of extension_map
    if extension.length < 10
      extension += ' '.repeat 10 - extension.length
    console.log "  *#{extension}  #{klass.title}"
    console.log "               #{klass.help}" if klass.help?
  console.log """

SYMBOL specifiers:

  'filename.svg':   load SVG from specifies file
  '<svg>...</svg>': raw SVG
  (context) -> ...: function computing SVG
"""
  #object with one or more attributes
  process.exit()

main = ->
  mappings = new Mappings
  args = process.argv[2..]
  files = skip = 0
  for arg, i in args
    if skip
      skip--
      continue
    switch arg
      when '-h', '--help'
        help()
      when '--tw', '--tile-width'
        Symbol.forceWidth = parseFloat args[i+1]
        skip = 1
      when '--th', '--tile-height'
        Symbol.forceHeight = parseFloat args[i+1]
        skip = 1
      else
        files++
        console.log '*', arg
        input = Input.load arg
        if input instanceof Mapping
          mappings.push input
        else if input instanceof Drawing
          input.writeSVG mappings
  unless files
    console.log 'Not enough filename arguments'
    help()

unless window?
  main()
