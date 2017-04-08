#!/usr/bin/coffee --bare
`#!/usr/bin/env node
`
path = require 'path'
fs = require 'fs'
CoffeeScript = require 'coffee-script'
csvParse = require 'csv-parse/lib/sync'
xlsx = require 'xlsx'
xmldom = require 'xmldom'
DOMParser = xmldom.DOMParser
domImplementation = new xmldom.DOMImplementation()
XMLSerializer = xmldom.XMLSerializer
prettyXML = require 'prettify-xml'

SVGNS = 'http://www.w3.org/2000/svg'
XLINKNS = 'http://www.w3.org/1999/xlink'

splitIntoLines = (data) ->
  data.replace('\r\n', '\n').replace('\r', '\n').split('\n')
whitespace = /[\s\uFEFF\xA0]+/  ## based on https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/Trim

class SVGTilerException
  constructor: (@message) ->
  toString: ->
    "svgtiler: #{@message}"

overflowBox = (xml) ->
  if xml.documentElement.hasAttribute 'overflowBox'
    xml.documentElement.getAttribute('overflowBox').split /\s*,?\s+/
    .map parseFloat
  else
    null

svgBBox = (xml) ->
  ## xxx Many unsupported features!
  ##   - transformations
  ##   - used symbols/defs
  ##   - paths
  ##   - text
  ##   - line widths which extend bounding box
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

zIndex = (node) ->
  style = node.getAttribute 'style'
  return 0 unless style
  match = /(?:^|\W)z-index\s*:\s*([-\d]+)/i.exec style
  return 0 unless match?
  parseInt match[1]

class Symbol
  @svgEncoding: 'utf8'
  @parse: (key, data) ->
    unless data?
      throw new SVGTilerException "Attempt to create symbol '#{key}' without data"
    else if typeof data == 'function'
      new DynamicSymbol key, data
    else if data.function?
      new DynamicSymbol key, data.function
    else
      new StaticSymbol key,
        if typeof data == 'string'
          if data.indexOf('<') < 0  ## No <'s -> interpret as filename
            filename: data
            svg: fs.readFileSync data,
                   encoding: @svgEncoding
          else
            svg: data
        else
          data
  includes: (substring) ->
    @key.indexOf(substring) >= 0
    ## ECMA6: @key.includes substring

class StaticSymbol extends Symbol
  constructor: (@key, options) ->
    for own key, value of options
      @[key] = value
    @xml = new DOMParser().parseFromString @svg
    @viewBox = svgBBox @xml
    @overflowBox = overflowBox @xml
    @width = @height = null
    if @viewBox?
      @width = @viewBox[2]
      @height = @viewBox[3]
    if Symbol.forceWidth?
      @width = Symbol.forceWidth
    if Symbol.forceHeight?
      @height = Symbol.forceHeight
    warnings = []
    unless @width?
      warnings.push 'width'
      @width = 0 unless @width?
    unless @height?
      warnings.push 'height'
      @height = 0 unless @height?
    if warnings.length > 0
      console.warn "Failed to detect #{warnings.join ' and '} of SVG for symbol '#{@key}'"
    @zIndex = zIndex @xml.documentElement
  id: ->
    ## Valid Name characters: https://www.w3.org/TR/2008/REC-xml-20081126/#NT-Name
    ## Couldn't represent the range [\u10000-\uEFFFF]
    ## Removed colon (:) to avoid potential conflict with hex expansion.
    ## Also prepend 's' to avoid bad starting characters.
    's' +
      @key.replace /[^-\w.\xC0-\xD6\xD8-\xF6\xF8-\u02FF\u0370-\u037D\u037F-\u1FFF\u200C-\u200D\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD\xB7\u0300-\u036F\u203F-\u2040]/,
      (m) -> ':' + m.charCodeAt(0).toString 16
  #use: -> @  ## do nothing for static symbol

class DynamicSymbol extends Symbol
  constructor: (@key, @func) ->
    @versions = {}
    @nversions = 0
  use: (context) ->
    result = @func.call context
    if result of @versions
      @versions[result]
    else
      @versions[result] = Symbol.parse "#{@key}-v#{@nversions++}", result

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
    @map = {}
    if typeof data == 'function'
      @function = data
    else
      @merge data
  merge: (data) ->
    for own key, value of data
      unless value instanceof Symbol
        value = Symbol.parse key, value
      @map[key] = value
  lookup: (key) ->
    if key of @map
      @map[key]
    else if @function?
      ## Cache return value of function so that only one Symbol generated
      ## for each key.  It still may be a DynamicSymbol, which will allow
      ## it to make multiple versions, but keep track of which are the same.
      value = @function key
      if value?
        @map[key] = Symbol.parse key, value
      else
        value
    else
      undefined

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

class Mappings
  constructor: (@maps = []) ->
  push: (map) ->
    @maps.push map
  lookup: (key) ->
    return unless @maps.length
    for i in [@maps.length-1..0]
      value = @maps[i].lookup key
      return value if value?
    undefined

allBlank = (list) ->
  for x in list
    if x
      return false
  true

class Drawing extends Input
  constructor: (@data) ->
  @load: (data) ->
    ## Turn strings into arrays
    data = for row in data
             for cell in row
               cell
    unless Drawing.keepMargins
      ## Top margin
      while data.length > 0 and allBlank data[0]
        data.shift()
      ## Bottom margin
      while data.length > 0 and allBlank data[data.length-1]
        data.pop()
      if data.length > 0
        ## Left margin
        while allBlank (row[0] for row in data)
          for row in data
            row.shift()
        ## Right margin
        j = Math.max (row.length for row in data)...
        while j >= 0 and allBlank (row[j] for row in data)
          for row in data
            if j < row.length
              row.pop()
          j--
    new @ data
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
    svg.setAttribute 'xmlns:xlink', XLINKNS
    svg.setAttribute 'version', '1.1'
    #svg.appendChild defs = doc.createElementNS SVGNS, 'defs'
    ## Look up all symbols in the drawing.
    missing = {}
    symbols =
      for row in @data
        for cell in row
          symbol = mappings.lookup cell
          unless symbol?
            missing[cell] = true
          symbol
    missing =("'#{key}'" for own key of missing)
    if missing.length
      console.warn "Failed to recognize symbols:", missing.join ', '
    ## Instantiate (.use) all (dynamic) symbols in the drawing.
    symbolsByKey = {}
    symbols =
      for row, i in symbols
        for symbol, j in row
          if symbol?.use?
            symbol = symbol.use new Context symbols, i, j
          symbolsByKey[symbol?.key] = symbol
    ## Include all used symbols in SVG
    for key, symbol of symbolsByKey
      continue unless symbol?
      svg.appendChild node = doc.createElementNS SVGNS, 'symbol'
      node.setAttribute 'id', symbol.id()
      if symbol.viewBox?
        node.setAttribute 'viewBox', symbol.viewBox
      if symbol.xml.documentElement.tagName in ['svg', 'symbol']
        ## Remove a layer of indirection for <svg> and <symbol>
        for attribute in symbol.xml.documentElement.attributes
          unless attribute.name in ['version'] or attribute.name[...5] == 'xmlns'
            node.setAttribute attribute.name, attribute.value
        for child in symbol.xml.documentElement.childNodes
          node.appendChild child.cloneNode true
      else
        node.appendChild symbol.xml.documentElement.cloneNode true
    ## Lay out the symbols in the drawing via SVG <use>.
    viewBox = [0, 0, 0, 0]
    levels = {}
    y = 0
    for row, i in symbols
      rowHeight = 0
      x = 0
      for symbol, j in row
        continue unless symbol?
        levels[symbol.zIndex] ?= []
        levels[symbol.zIndex].push use = doc.createElementNS SVGNS, 'use'
        use.setAttribute 'xlink:href', '#' + symbol.id()
        use.setAttributeNS SVGNS, 'x', x
        use.setAttributeNS SVGNS, 'y', y
        use.setAttributeNS SVGNS, 'width', symbol.width
        use.setAttributeNS SVGNS, 'height', symbol.height
        if symbol.overflowBox?
          viewBox[0] = Math.min viewBox[0],
            x + symbol.overflowBox[0] - symbol.viewBox[0]
          viewBox[1] = Math.min viewBox[1],
            y + symbol.overflowBox[1] - symbol.viewBox[1]
          viewBox[2] = Math.max viewBox[2],
            x + symbol.overflowBox[2]
          viewBox[3] = Math.max viewBox[3],
            y + symbol.overflowBox[3]
        x += symbol.width
        viewBox[2] = Math.max viewBox[2], x
        if symbol.height > rowHeight
          rowHeight = symbol.height
      y += rowHeight
      viewBox[3] = Math.max viewBox[3], y
    ## Sort by level
    levelOrder = (level for level of levels).sort (x, y) -> x-y
    for level in levelOrder
      for node in levels[level]
        svg.appendChild node
    svg.setAttributeNS SVGNS, 'viewBox', viewBox.join ' '
    svg.setAttributeNS SVGNS, 'width', viewBox[2]
    svg.setAttributeNS SVGNS, 'height', viewBox[3]
    svg.setAttributeNS SVGNS, 'preserveAspectRatio', 'xMinYMin meet'
    '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">

''' +
      prettyXML new XMLSerializer().serializeToString doc

class ASCIIDrawing extends Drawing
  @title: "ASCII drawing (one character per symbol)"
  @parse: (data) ->
    @load splitIntoLines data

class DSVDrawing extends Drawing
  @parse: (data) ->
    ## Remove trailing newline / final blank line.
    if data[-2..] == '\r\n'
      data = data[...-2]
    else if data[-1..] in ['\r', '\n']
      data = data[...-1]
    ## CSV parser.
    @load csvParse data,
      delimiter: @delimiter
      relax_column_count: true

class SSVDrawing extends DSVDrawing
  @title: "Space-delimiter drawing (one word per symbol)"
  @delimiter: ' '
  @parse: (data) ->
    ## Coallesce non-newline whitespace into single space
    super data.replace /[ \t\f\v]+/g, ' '

class CSVDrawing extends DSVDrawing
  @title: "Comma-separated drawing (spreadsheet export)"
  @delimiter: ','

class TSVDrawing extends DSVDrawing
  @title: "Tab-separated drawing (spreadsheet export)"
  @delimiter: '\t'

class Drawings extends Input
  @filenameSeparator = '_'
  constructor: (@drawings) ->
  @load: (datas) ->
    new @ (
      for data in datas
        drawing = Drawing.load data
        drawing.subname = data.subname
        drawing
    )
  writeSVG: (mappings, filename) ->
    for drawing in @drawings
      drawing.writeSVG mappings,
        if @drawings.length > 1
          filename2 = path.parse filename ? @filename
          filename2.base = filename2.base[...-filename2.ext.length]
          filename2.base += @constructor.filenameSeparator + drawing.subname
          filename2.base += '.svg'
          path.format filename2
        else
          drawing.filename = @filename  ## use Drawing default if not filename?
          filename

class XLSXDrawings extends Drawings
  @encoding: 'binary'
  @title: "Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)"
  @parse: (data) ->
    workbook = xlsx.read data, type: 'binary'
    ## https://www.npmjs.com/package/xlsx#common-spreadsheet-format
    @load (
      for subname in workbook.SheetNames
        sheet = workbook.Sheets[subname]
        rows = xlsx.utils.sheet_to_json sheet,
          header: 1
          defval: ''
        rows.subname = subname
        rows
    )

class Context
  constructor: (@symbols, @i, @j) ->
    @symbol = @symbols[@i]?[@j]
    @key = @symbol?.key
  includes: (args...) ->
    @symbol? and @symbol.includes args...
  neighbor: (dj, di) ->
    new Context @symbols, @i + di, @j + dj

extension_map =
  '.txt': ASCIIMapping
  '.js': JSMapping
  '.coffee': CoffeeMapping
  '.asc': ASCIIDrawing
  '.ssv': SSVDrawing
  '.csv': CSVDrawing
  '.tsv': TSVDrawing
  ## Parsable by xlsx package:
  '.xlsx': XLSXDrawings  ## Excel 2007+ XML Format
  '.xlsm': XLSXDrawings  ## Excel 2007+ Macro XML Format
  '.xlsb': XLSXDrawings  ## Excel 2007+ Binary Format
  '.xls': XLSXDrawings   ## Excel 2.0 or 2003-2004 (SpreadsheetML)
  '.ods': XLSXDrawings   ## OpenDocument Spreadsheet
  '.fods': XLSXDrawings  ## Flat OpenDocument Spreadsheet
  '.dif': XLSXDrawings   ## Data Interchange Format (DIF)
  '.prn': XLSXDrawings   ## Lotus Formatted Text
  '.dbf': XLSXDrawings   ## dBASE II/III/IV / Visual FoxPro

help = ->
  console.log """
Usage: #{process.argv[1]} (...options and filenames...)
Documentation: https://github.com/edemaine/svgtiler#svg-tiler

Optional arguments:
  --help                Show this help message and exit.
  -m / --margin         Don't delete blank extreme rows/columns
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
  -> ...@key...:    function computing SVG, with `this` bound to Context with
                    `key` set to symbol name, `i` and `j` set to coordinates,
                    and supporting `neighbor` and `includes` methods.
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
      when '-m', '--margin'
        Drawing.keepMargins = true
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
        else if input instanceof Drawing or input instanceof Drawings
          input.writeSVG mappings
  unless files
    console.log 'Not enough filename arguments'
    help()

unless window?
  main()
