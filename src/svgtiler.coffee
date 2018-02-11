#!/usr/bin/coffee --bare
`#!/usr/bin/env node
`
path = require 'path'
fs = require 'fs'
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

extensionOf = (filename) -> path.extname(filename).toLowerCase()

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
        when 'rect', 'image'
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
          ry = parseFloat node.getAttribute('ry') or 0
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
  @forceWidth: null   ## default: no size forcing
  @forceHeight: null  ## default: no size forcing

  ###
  Attempt to render pixels as pixels, as needed for old-school graphics.
  SVG 1.1 and Inkscape define image-rendering="optimizeSpeed" for this.
  Chrome doesn't support this, but supports a CSS3 (or SVG) specification of
  "image-rendering:pixelated".  Combining these seems to work everywhere.
  ###
  @imageRendering:
    ' image-rendering="optimizeSpeed" style="image-rendering:pixelated"'

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
            extension = extensionOf data
            ## <image> tag documentation: "Conforming SVG viewers need to
            ## support at least PNG, JPEG and SVG format files."
            ## [https://svgwg.org/svg2-draft/embedded.html#ImageElement]
            switch extension
              when '.png', '.jpg', '.jpeg', '.gif'
                size = require('image-size') data
                svg: """
                  <image xlink:href="#{encodeURIComponent data}" width="#{size.width}" height="#{size.height}"#{@imageRendering}/>
                """
              when '.svg'
                filename: data
                svg: fs.readFileSync data,
                       encoding: @svgEncoding
              else
                throw new SVGTilerException "Unrecognized extension in filename '#{data}' for symbol '#{key}'"
          else
            svg: data
        else
          data
  includes: (substring) ->
    @key.indexOf(substring) >= 0
    ## ECMA6: @key.includes substring

zeroSizeReplacement = 1

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
      ###
      SVG's viewBox has a special rule that "A value of zero [in <width>
      or <height>] disables rendering of the element."  Avoid this.
      [https://www.w3.org/TR/SVG11/coords.html#ViewBoxAttribute]
      ###
      if @xml.documentElement.hasAttribute('style') and
         /overflow\s*:\s*visible/.test @xml.documentElement.getAttribute('style')
        if @width == 0
          @viewBox[2] = zeroSizeReplacement
        if @height == 0
          @viewBox[3] = zeroSizeReplacement
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
    ###
    id/href follows the IRI spec [https://tools.ietf.org/html/rfc3987]:
      ifragment      = *( ipchar / "/" / "?" )
      ipchar         = iunreserved / pct-encoded / sub-delims / ":" / "@"
      iunreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~" / ucschar
      pct-encoded    = "%" HEXDIG HEXDIG
      sub-delims     = "!" / "$" / "&" / "'" / "(" / ")"
                     / "*" / "+" / "," / ";" / "="
      ucschar        = %xA0-D7FF / %xF900-FDCF / #%xFDF0-FFEF
                     / %x10000-1FFFD / %x20000-2FFFD / %x30000-3FFFD
                     / %x40000-4FFFD / %x50000-5FFFD / %x60000-6FFFD
                     / %x70000-7FFFD / %x80000-8FFFD / %x90000-9FFFD
                     / %xA0000-AFFFD / %xB0000-BFFFD / %xC0000-CFFFD
                     / %xD0000-DFFFD / %xE1000-EFFFD
    We also want to escape colon (:) which seems to cause trouble.
    We use encodeURIComponent which escapes everything except
      A-Z a-z 0-9 - _ . ! ~ * ' ( )
    [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent]
    Unfortunately, Inkscape seems to ignore any %-encoded symbols; see
    https://bugs.launchpad.net/inkscape/+bug/1737778
    So we replace '%' with '$', an allowed character that's already escaped.
    ###
    encodeURIComponent @key
    .replace /%/g, '$'
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
    extension = extensionOf filename
    if extension of extensionMap
      extensionMap[extension].parseFile filename
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
        if separator[0].length == 1
          ## Single whitespace character at beginning defines blank character
          key = ''
        else
          ## Multiple whitespace at beginning defines first whitespace character
          key = line[0]
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
    new @ require('coffee-script').eval data

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

blankCells =
  '': true
  ' ': true  ## for ASCII art in particular

allBlank = (list) ->
  for x in list
    if x? and x not of blankCells
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
    filename
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
      if symbol.xml.documentElement.tagName in ['svg', 'symbol']
        ## Remove a layer of indirection for <svg> and <symbol>
        for attribute in symbol.xml.documentElement.attributes
          unless attribute.name in ['version'] or attribute.name[...5] == 'xmlns'
            node.setAttribute attribute.name, attribute.value
        for child in symbol.xml.documentElement.childNodes
          node.appendChild child.cloneNode true
      else
        node.appendChild symbol.xml.documentElement.cloneNode true
      ## Set/overwrite any viewbox attribute with one from symbol.
      if symbol.viewBox?
        node.setAttribute 'viewBox', symbol.viewBox
    ## Lay out the symbols in the drawing via SVG <use>.
    viewBox = [0, 0, 0, 0]  ## initially x-min, y-min, x-max, y-max
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
        use.setAttributeNS SVGNS, 'width', symbol.viewBox?[2] ? symbol.width
        use.setAttributeNS SVGNS, 'height', symbol.viewBox?[3] ? symbol.height
        if symbol.overflowBox?
          dx = symbol.overflowBox[0] - symbol.viewBox[0]
          dy = symbol.overflowBox[1] - symbol.viewBox[1]
          viewBox[0] = Math.min viewBox[0], x + dx
          viewBox[1] = Math.min viewBox[1], y + dy
          viewBox[2] = Math.max viewBox[2], x + dx + symbol.overflowBox[2]
          viewBox[3] = Math.max viewBox[3], y + dy + symbol.overflowBox[3]
        x += symbol.width
        viewBox[2] = Math.max viewBox[2], x
        if symbol.height > rowHeight
          rowHeight = symbol.height
      y += rowHeight
      viewBox[3] = Math.max viewBox[3], y
    ## Change from x-min, y-min, x-max, y-max to x-min, y-min, width, height
    viewBox[2] = viewBox[2] - viewBox[0]
    viewBox[3] = viewBox[3] - viewBox[1]
    ## Sort by level
    levelOrder = (level for level of levels).sort (x, y) -> x-y
    for level in levelOrder
      for node in levels[level]
        svg.appendChild node
    svg.setAttributeNS SVGNS, 'viewBox', viewBox.join ' '
    svg.setAttributeNS SVGNS, 'width', viewBox[2]
    svg.setAttributeNS SVGNS, 'height', viewBox[3]
    svg.setAttributeNS SVGNS, 'preserveAspectRatio', 'xMinYMin meet'
    out = new XMLSerializer().serializeToString doc
    ## Parsing xlink:href in user's SVG fragments, and then serializing,
    ## can lead to these null namespace definitions.  Remove.
    out = out.replace /\sxmlns:xlink=""/g, ''
    '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">

''' + prettyXML out

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
    @load require('csv-parse/lib/sync') data,
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
    xlsx = require 'xlsx'
    workbook = xlsx.read data, type: 'binary'
    ## https://www.npmjs.com/package/xlsx#common-spreadsheet-format
    @load (
      for subname in workbook.SheetNames
        sheet = workbook.Sheets[subname]
        if subname.length == 31
          console.warn "Warning: Sheet '#{subname}' has length exactly 31, which may be caused by Google Sheets export truncation"
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
  neighbor: (dj, di) ->
    new Context @symbols, @i + di, @j + dj
  includes: (args...) ->
    @symbol? and @symbol.includes args...
  row: (di = 0) ->
    i = @i + di
    for symbol, j in @symbols[i] ? []
      new Context @symbols, i, j
  column: (dj = 0) ->
    j = @j + dj
    for row, i in @symbols
      new Context @symbols, i, j

extensionMap =
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

svg2 = (format, svg) ->
  filename = path.parse svg
  if filename.ext == ".#{format}"
    filename.base += ".#{format}"
  else
    filename.base = "#{filename.base[...-filename.ext.length]}.#{format}"
  output = path.format filename
  console.log '=>', output
  output = require('child_process').spawnSync 'inkscape', [
    '-z'
    "--file=#{svg}"
    "--export-#{format}=#{output}"
  ]
  if output.error
    console.error output.error

help = ->
  console.log """
Usage: #{process.argv[1]} (...options and filenames...)
Documentation: https://github.com/edemaine/svgtiler#svg-tiler

Optional arguments:
  --help                Show this help message and exit.
  -m / --margin         Don't delete blank extreme rows/columns
  --tw TILE_WIDTH / --tile-width TILE_WIDTH
                        Force all symbol tiles to have specified width
  --th TILE_HEIGHT / --tile-height TILE_HEIGHT
                        Force all symbol tiles to have specified height
  -p / --pdf            Convert output SVG files to PDF via Inkscape
  -P / --png            Convert output SVG files to PNG via Inkscape

Filename arguments:  (mappings before drawings!)

"""
  for extension, klass of extensionMap
    if extension.length < 10
      extension += ' '.repeat 10 - extension.length
    console.log "  *#{extension}  #{klass.title}"
    console.log "               #{klass.help}" if klass.help?
  console.log """

SYMBOL specifiers:  (omit the quotes in anything except .js and .coffee files)

  'filename.svg':   load SVG from specified file
  'filename.png':   include PNG image from specified file
  'filename.jpg':   include JPEG image from specified file
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
  formats = []
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
      when '-p', '--pdf'
        formats.push 'pdf'
      when '-P', '--png'
        formats.push 'png'
      else
        files++
        console.log '*', arg
        input = Input.load arg
        if input instanceof Mapping
          mappings.push input
        else if input instanceof Drawing or input instanceof Drawings
          filenames = input.writeSVG mappings
          for format in formats
            if typeof filenames == 'string'
              svg2 format, filenames
            else
              for filename in filenames
                svg2 format, filename
  unless files
    console.log 'Not enough filename arguments'
    help()

unless window?
  main()
