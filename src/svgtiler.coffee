`#!/usr/bin/env node
(function() {
`
unless window?
  path = require 'path'
  fs = require 'fs'
  xmldom = require 'xmldom'
  DOMParser = xmldom.DOMParser
  domImplementation = new xmldom.DOMImplementation()
  XMLSerializer = xmldom.XMLSerializer
  prettyXML = require 'prettify-xml'
  graphemeSplitter = new require('grapheme-splitter')()
else
  DOMParser = window.DOMParser # escape CoffeeScript scope
  domImplementation = document.implementation
  path =
    extname: (x) -> /\.[^/]+$/.exec(x)[0]
    dirname: (x) -> /[^]*\/|/.exec(x)[0]

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

parseNum = (x) ->
  parsed = parseFloat x
  if isNaN parsed
    null
  else
    parsed

svgBBox = (xml) ->
  ## xxx Many unsupported features!
  ##   - transformations
  ##   - used symbols/defs
  ##   - paths
  ##   - text
  ##   - line widths which extend bounding box
  if xml.documentElement.hasAttribute 'viewBox'
    viewBox = xml.documentElement.getAttribute('viewBox').split /\s*,?\s+/
    .map parseNum
    if null in viewBox
      null
    else
      viewBox
  else
    recurse = (node) ->
      if node.nodeType != node.ELEMENT_NODE or
         node.tagName in ['defs', 'symbol', 'use']
        return null
      switch node.tagName
        when 'rect', 'image'
          ## For <image>, should autodetect image size (#42)
          [parseNum(node.getAttribute 'x') ? 0
           parseNum(node.getAttribute 'y') ? 0
           parseNum(node.getAttribute 'width') ? 0
           parseNum(node.getAttribute 'height') ? 0]
        when 'circle'
          cx = parseNum(node.getAttribute 'cx') ? 0
          cy = parseNum(node.getAttribute 'cy') ? 0
          r = parseNum(node.getAttribute 'r') ? 0
          [cx - r, cy - r, 2*r, 2*r]
        when 'ellipse'
          cx = parseNum(node.getAttribute 'cx') ? 0
          cy = parseNum(node.getAttribute 'cy') ? 0
          rx = parseNum(node.getAttribute 'rx') ? 0
          ry = parseNum(node.getAttribute 'ry') ? 0
          [cx - rx, cy - ry, 2*rx, 2*ry]
        when 'line'
          x1 = parseNum(node.getAttribute 'x1') ? 0
          y1 = parseNum(node.getAttribute 'y1') ? 0
          x2 = parseNum(node.getAttribute 'x2') ? 0
          y2 = parseNum(node.getAttribute 'y2') ? 0
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
          if isNaN(xmin) or isNaN(ymin) # invalid points attribute; don't render
            null
          else
            [xmin, ymin, Math.max(xs...) - xmin, Math.max(ys...) - ymin]
        else
          viewBoxes = (recurse(child) for child in node.childNodes)
          viewBoxes = (viewBox for viewBox in viewBoxes when viewBox?)
          xmin = Math.min ...(viewBox[0] for viewBox in viewBoxes)
          ymin = Math.min ...(viewBox[1] for viewBox in viewBoxes)
          xmax = Math.max ...(viewBox[0]+viewBox[2] for viewBox in viewBoxes)
          ymax = Math.max ...(viewBox[1]+viewBox[3] for viewBox in viewBoxes)
          [xmin, ymin, xmax - xmin, ymax - ymin]
    viewBox = recurse xml.documentElement
    if Infinity in viewBox or -Infinity in viewBox
      null
    else
      viewBox

isAuto = (xml, prop) ->
  xml.documentElement.hasAttribute(prop) and
  /^\s*auto\s*$/i.test xml.documentElement.getAttribute prop

zIndex = (node) ->
  ## Check whether DOM node has a specified z-index, defaulting to zero.
  ## Note that z-index must be an integer.
  ## 1. https://www.w3.org/Graphics/SVG/WG/wiki/Proposals/z-index suggests
  ## a z-index="..." attribute.  Check for this first.
  if z = node.getAttribute 'z-index'
    return parseInt z
  ## 2. Look for style="z-index:..." as in HTML.
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

  @parse: (key, data, dirname) ->
    unless data?
      throw new SVGTilerException "Attempt to create symbol '#{key}' without data"
    else if typeof data == 'function'
      new DynamicSymbol key, data, dirname
    else if data.function?
      new DynamicSymbol key, data.function, dirname
    else
      ## Render Preact virtual dom nodes (e.g. from JSX notation) into strings.
      ## Serialization + parsing shouldn't be necessary, but this lets us
      ## deal with one parsed format (xmldom).
      if typeof data == 'object' and data.type? and data.props?
        data = require('preact-render-to-string') data
      new StaticSymbol key,
        if typeof data == 'string'
          if data.trim() == ''  ## Blank SVG treated as 0x0 symbol
            svg: '<symbol viewBox="0 0 0 0"/>'
          else if data.indexOf('<') < 0  ## No <'s -> interpret as filename
            if dirname?
              filename = path.join dirname, data
            else
              filename = data
            extension = extensionOf data
            ## <image> tag documentation: "Conforming SVG viewers need to
            ## support at least PNG, JPEG and SVG format files."
            ## [https://svgwg.org/svg2-draft/embedded.html#ImageElement]
            switch extension
              when '.png', '.jpg', '.jpeg', '.gif'
                size = require('image-size') filename
                svg: """
                  <image xlink:href="#{encodeURIComponent data}" width="#{size.width}" height="#{size.height}"#{@imageRendering}/>
                """
              when '.svg'
                filename: filename
                svg: fs.readFileSync filename,
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
    super()
    for own key, value of options
      @[key] = value
    ## Force SVG namespace when parsing, so nodes have correct namespaceURI.
    ## (This is especially important on the browser, so the results can be
    ## reparented into an HTML Document.)
    @svg = @svg.replace /^\s*<(?:[^<>'"\/]|'[^']*'|"[^"]*")*\s*(\/?\s*>)/,
      (match, end) ->
        unless 'xmlns' in match
          match = match[...match.length-end.length] +
            " xmlns='#{SVGNS}'" + match[match.length-end.length..]
        match
    @xml = new DOMParser
      locator:  ## needed when specifying errorHandler
        line: 1
        col: 1
      errorHandler: (level, msg, indent = '  ') =>
        msg = msg.replace /^\[xmldom [^\[\]]*\]\t/, ''
        msg = msg.replace /@#\[line:(\d+),col:(\d+)\]$/, (match, line, col) =>
          lines = @svg.split '\n'
          (if line > 1 then indent + lines[line-2] + '\n' else '') +
          indent + lines[line-1] + '\n' +
          indent + ' '.repeat(col-1) + '^^^' +
          (if line < lines.length then '\n' + indent + lines[line] else '')
        console.error "SVG parse ${level} in symbol '#{@key}': #{msg}"
    .parseFromString @svg, 'image/svg+xml'
    @viewBox = svgBBox @xml
    @overflowBox = overflowBox @xml
    @overflowVisible =
      @xml.documentElement.hasAttribute('style') and
      /overflow\s*:\s*visible/.test @xml.documentElement.getAttribute 'style'
    @width = @height = null
    if @viewBox?
      @width = @viewBox[2]
      @height = @viewBox[3]
      ###
      SVG's viewBox has a special rule that "A value of zero [in <width>
      or <height>] disables rendering of the element."  Avoid this.
      [https://www.w3.org/TR/SVG11/coords.html#ViewBoxAttribute]
      ###
      if @overflowVisible
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
      @width = 0
    unless @height?
      warnings.push 'height'
      @height = 0
    if warnings.length > 0
      console.warn "Failed to detect #{warnings.join ' and '} of SVG for symbol '#{@key}'"
    ## Detect special `width="auto"` and/or `height="auto"` fields for future
    ## processing, and remove them to ensure valid SVG.
    @autoWidth = isAuto @xml, 'width'
    @autoHeight = isAuto @xml, 'height'
    @xml.documentElement.removeAttribute 'width' if @autoWidth
    @xml.documentElement.removeAttribute 'height' if @autoHeight
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
  constructor: (@key, @func, @dirname) ->
    super()
    @versions = {}
    @nversions = 0
  use: (context) ->
    result = @func.call context
    unless result?
      throw new Error "Function for symbol #{@key} returned #{result}"
    ## We use JSON serialization to detect duplicate symbols.  This enables
    ## return values like {filename: ...} and JSX virtual dom elements,
    ## in addition to raw SVG strings.
    string = JSON.stringify result
    if string of @versions
      @versions[string]
    else
      @versions[string] =
        Symbol.parse "#{@key}-v#{@nversions++}", result, @dirname

## Symbol to fall back to when encountering an unrecognized symbol.
## Path from https://commons.wikimedia.org/wiki/File:Replacement_character.svg
## by Amit6, released into the public domain.
unrecognizedSymbol = new StaticSymbol 'UNRECOGNIZED', svg: '''
  <symbol viewBox="0 0 200 200" preserveAspectRatio="none" width="auto" height="auto">
    <rect width="200" height="200" fill="yellow"/>
    <path xmlns="http://www.w3.org/2000/svg" stroke="none" fill="red" d="M 200,100 100,200 0,100 100,0 200,100 z M 135.64709,74.70585 q 0,-13.52935 -10.00006,-22.52943 -9.99999,-8.99999 -24.35289,-8.99999 -17.29415,0 -30.117661,5.29409 L 69.05879,69.52938 q 9.764731,-6.23528 21.52944,-6.23528 8.82356,0 14.58824,4.82351 5.76469,4.82351 5.76469,12.70589 0,8.5883 -9.94117,21.70588 -9.94117,13.11766 -9.94117,26.76473 l 17.88236,0 q 0,-6.3529 6.9412,-14.9412 11.76471,-14.58816 12.82351,-16.35289 6.9412,-11.05887 6.9412,-23.29417 z m -22.00003,92.11771 0,-24.70585 -27.29412,0 0,24.70585 27.29412,0 z"/>
  </symbol>
'''

class Input
  @encoding: 'utf8'
  @parseFile: (filename, filedata) ->
    ## Generic method to parse file once we're already in the right class.
    input = new @
    input.filename = filename
    unless filedata?
      filedata = fs.readFileSync filename, encoding: @encoding
    input.parse filedata
    input
  @recognize: (filename, filedata) ->
    ## Recognize type of file and call corresponding class's `parseFile`.
    extension = extensionOf filename
    if extension of extensionMap
      extensionMap[extension].parseFile filename, filedata
    else
      throw new SVGTilerException "Unrecognized extension in filename #{filename}"

class Mapping extends Input
  load: (data) ->
    @map = {}
    if typeof data == 'function'
      @function = data
    else
      @merge data
  merge: (data) ->
    dirname = path.dirname @filename if @filename?
    for own key, value of data
      unless value instanceof Symbol
        value = Symbol.parse key, value, dirname
      @map[key] = value
  lookup: (key) ->
    key = key.toString()  ## Sometimes get a number, e.g., from XLSX
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
  parse: (data) ->
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
    @load map

class JSMapping extends Mapping
  @title: "JavaScript mapping file"
  @help: "Object mapping symbol names to SYMBOL e.g. dot: 'dot.svg'"
  parse: (data) ->
    {code} = require('@babel/core').transform data,
      filename: @filename
      plugins: [[require.resolve('@babel/plugin-transform-react-jsx'),
        useBuiltIns: true
        pragma: 'preact.h'
        pragmaFrag: 'preact.Fragment'
        throwIfNamespace: false
      ]]
      sourceMaps: 'inline'
      retainLines: true
    if 0 <= code.indexOf 'preact.'
      code = "var preact = require('preact'), h = preact.h; #{code}"
    ## Mimick NodeJS module's __filename and __dirname variables
    __filename = path.resolve @filename
    code =
      "var __filename = #{JSON.stringify __filename},
           __dirname = #{JSON.stringify path.dirname __filename};
       #{code}\n//@ sourceURL=#{@filename}"
    @load eval code

class CoffeeMapping extends JSMapping
  @title: "CoffeeScript mapping file"
  @help: "Object mapping symbol names to SYMBOL e.g. dot: 'dot.svg'"
  parse: (data) ->
    #try
      super.parse require('coffeescript').compile data,
        bare: true
        filename: @filename
        sourceFiles: [@filename]
        inlineMap: true
    #catch err
    #  throw err
    #  if err.stack? and err.stack.startsWith "#{@filename}:"
    #    sourceMap = require('coffeescript').compile(data,
    #      bare: true
    #      filename: @filename
    #      sourceFiles: [@filename]
    #      sourceMap: true
    #    ).sourceMap
    #    err.stack = err.stack.replace /:([0-9]*)/, (m, line) ->
    #      ## sourceMap starts line numbers at 0, but we want to work from 1
    #      for col in sourceMap?.lines[line-1]?.columns ? [] when col?.sourceLine?
    #        unless sourceLine? and sourceLine < col.sourceLine
    #          sourceLine = col.sourceLine
    #          line = sourceLine + 1
    #      ":#{line}"
    #  throw err

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
  load: (data) ->
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
    @data = data
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
  renderSVGDOM: (mappings) ->
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
          if symbol?
            lastSymbol = symbol
          else
            missing[cell] = true
            unrecognizedSymbol
    missing = ("'#{key}'" for own key of missing)
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
          unless attribute.name in ['version', 'id'] or attribute.name[...5] == 'xmlns'
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
    colWidths = {}
    for row, i in symbols
      rowHeight = 0
      for symbol in row when not symbol.autoHeight
        if symbol.height > rowHeight
          rowHeight = symbol.height
      x = 0
      for symbol, j in row
        continue unless symbol?
        levels[symbol.zIndex] ?= []
        levels[symbol.zIndex].push use = doc.createElementNS SVGNS, 'use'
        use.setAttribute 'xlink:href', '#' + symbol.id()
        use.setAttributeNS SVGNS, 'x', x
        use.setAttributeNS SVGNS, 'y', y
        scaleX = scaleY = 1
        if symbol.autoWidth
          colWidths[j] ?= Math.max 0, ...(
            for row2 in symbols when row2[j]? and not row2[j].autoWidth
              row2[j].width
          )
          scaleX = colWidths[j] / symbol.width unless symbol.width == 0
          scaleY = scaleX unless symbol.autoHeight
        if symbol.autoHeight
          scaleY = rowHeight / symbol.height unless symbol.height == 0
          scaleX = scaleY unless symbol.autoWidth
        ## Scaling of symbol is relative to viewBox, so use that to define
        ## width and height attributes:
        use.setAttributeNS SVGNS, 'width',
          (symbol.viewBox?[2] ? symbol.width) * scaleX
        use.setAttributeNS SVGNS, 'height',
          (symbol.viewBox?[3] ? symbol.height) * scaleY
        if symbol.overflowBox?
          dx = (symbol.overflowBox[0] - symbol.viewBox[0]) * scaleX
          dy = (symbol.overflowBox[1] - symbol.viewBox[1]) * scaleY
          viewBox[0] = Math.min viewBox[0], x + dx
          viewBox[1] = Math.min viewBox[1], y + dy
          viewBox[2] = Math.max viewBox[2], x + dx + symbol.overflowBox[2] * scaleX
          viewBox[3] = Math.max viewBox[3], y + dy + symbol.overflowBox[3] * scaleY
        x += symbol.width * scaleX
        viewBox[2] = Math.max viewBox[2], x
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
    doc
  renderSVG: (mappings) ->
    out = new XMLSerializer().serializeToString @renderSVGDOM mappings
    ## Parsing xlink:href in user's SVG fragments, and then serializing,
    ## can lead to these null namespace definitions.  Remove.
    out = out.replace /\sxmlns:xlink=""/g, ''
    out = prettyXML out,
      newline: '\n'  ## force consistent line endings, not require('os').EOL
    '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">

''' + out

class ASCIIDrawing extends Drawing
  @title: "ASCII drawing (one character per symbol)"
  parse: (data) ->
    @load(
      for line in splitIntoLines data
        graphemeSplitter.splitGraphemes line
    )

class DSVDrawing extends Drawing
  parse: (data) ->
    ## Remove trailing newline / final blank line.
    if data[-2..] == '\r\n'
      data = data[...-2]
    else if data[-1..] in ['\r', '\n']
      data = data[...-1]
    ## CSV parser.
    @load require('csv-parse/lib/sync') data,
      delimiter: @constructor.delimiter
      relax_column_count: true

class SSVDrawing extends DSVDrawing
  @title: "Space-delimiter drawing (one word per symbol)"
  @delimiter: ' '
  parse: (data) ->
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
  load: (datas) ->
    @drawings =
      for data in datas
        drawing = new Drawing
        drawing.subname = data.subname
        drawing.load data
        drawing
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
  parse: (data) ->
    xlsx = require 'xlsx'
    workbook = xlsx.read data, type: 'binary'
    ## https://www.npmjs.com/package/xlsx#common-spreadsheet-format
    @load (
      for sheetInfo in workbook.Workbook.Sheets
        subname = sheetInfo.name
        sheet = workbook.Sheets[subname]
        ## 0 = Visible, 1 = Hidden, 2 = Very Hidden
        ## https://sheetjs.gitbooks.io/docs/#sheet-visibility
        if sheetInfo.Hidden and not Drawings.keepHidden
          continue
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
  '.jsx': JSMapping
  '.coffee': CoffeeMapping
  '.cjsx': CoffeeMapping
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

sanitize = true
bufferSize = 16*1024

postprocess = (format, filename) ->
  return unless sanitize
  try
    switch format
      when 'pdf'
        ## Blank out /CreationDate in PDF for easier version control.
        ## Replace these commands with spaces to avoid in-file pointer errors.
        buffer = Buffer.alloc bufferSize
        fileSize = fs.statSync(filename).size
        position = Math.max 0, fileSize - bufferSize
        file = fs.openSync filename, 'r+'
        readSize = fs.readSync file, buffer, 0, bufferSize, position
        string = buffer.toString 'binary'  ## must use single-byte encoding!
        match = /\/CreationDate\s*\((?:[^()\\]|\\[^])*\)/.exec string
        if match?
          fs.writeSync file, ' '.repeat(match[0].length), position + match.index
        fs.closeSync file
  catch e
    console.log "Failed to postprocess '#{filename}': #{e}"

convertSVG = (format, svg, sync) ->
  child_process = require 'child_process'
  filename = path.parse svg
  if filename.ext == ".#{format}"
    filename.base += ".#{format}"
  else
    filename.base = "#{filename.base[...-filename.ext.length]}.#{format}"
  output = path.format filename
  args = [
    '-z'
    "--file=#{svg}"
    "--export-#{format}=#{output}"
  ]
  if sync
    ## In sychronous mode, we let inkscape directly output its error messages,
    ## and add warnings about any failures that occur.
    console.log '=>', output
    result = child_process.spawnSync 'inkscape', args, stdio: 'inherit'
    if result.error
      console.log result.error.message
    else if result.status or result.signal
      console.log ":-( #{output} FAILED"
    else
      postprocess format, output
  else
    ## In asychronous mode, we capture inkscape's outputs, and print them only
    ## when the process has finished, along with which file failed, to avoid
    ## mixing up messages from parallel executions.
    (resolve) ->
      console.log '=>', output
      inkscape = require('child_process').spawn 'inkscape', args
      out = ''
      inkscape.stdout.on 'data', (buf) -> out += buf
      inkscape.stderr.on 'data', (buf) -> out += buf
      inkscape.on 'error', (error) ->
        console.log error.message
      inkscape.on 'exit', (status, signal) ->
        if status or signal
          console.log ":-( #{output} FAILED:"
          console.log out
        else
          postprocess format, output
        resolve()

help = ->
  console.log """
Usage: #{process.argv[1]} (...options and filenames...)
Documentation: https://github.com/edemaine/svgtiler#svg-tiler

Optional arguments:
  --help                Show this help message and exit.
  -m / --margin         Don't delete blank extreme rows/columns
  --hidden              Process hidden sheets within spreadsheet files
  --tw TILE_WIDTH / --tile-width TILE_WIDTH
                        Force all symbol tiles to have specified width
  --th TILE_HEIGHT / --tile-height TILE_HEIGHT
                        Force all symbol tiles to have specified height
  -p / --pdf            Convert output SVG files to PDF via Inkscape
  -P / --png            Convert output SVG files to PNG via Inkscape
  --no-sanitize         Don't sanitize PDF output by blanking out /CreationDate
  -j N / --jobs N       Run up to N Inkscape jobs in parallel

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
  jobs = []
  sync = true
  for arg, i in args
    if skip
      skip--
      continue
    switch arg
      when '-h', '--help'
        help()
      when '-m', '--margin'
        Drawing.keepMargins = true
      when '--hidden'
        Drawings.keepHidden = true
      when '--tw', '--tile-width'
        skip = 1
        arg = parseFloat args[i+1]
        if arg
          Symbol.forceWidth = arg
        else
          console.warn "Invalid argument to --tile-width: #{args[i+1]}"
      when '--th', '--tile-height'
        skip = 1
        arg = parseFloat args[i+1]
        if arg
          Symbol.forceHeight = arg
        else
          console.warn "Invalid argument to --tile-height: #{args[i+1]}"
      when '-p', '--pdf'
        formats.push 'pdf'
      when '-P', '--png'
        formats.push 'png'
      when '--no-sanitize'
        sanitize = false
      when '-j', '--jobs'
        skip = 1
        arg = parseInt args[i+1]
        if arg
          jobs = new require('async-limiter') concurrency: arg
          sync = false
        else
          console.warn "Invalid argument to --jobs: #{args[i+1]}"
      else
        files++
        console.log '*', arg
        input = Input.recognize arg
        if input instanceof Mapping
          mappings.push input
        else if input instanceof Drawing or input instanceof Drawings
          filenames = input.writeSVG mappings
          for format in formats
            if typeof filenames == 'string'
              jobs.push convertSVG format, filenames, sync
            else
              for filename in filenames
                jobs.push convertSVG format, filename, sync
  unless files
    console.log 'Not enough filename arguments'
    help()

exports = {Symbol, StaticSymbol, DynamicSymbol, unrecognizedSymbol,
  Mapping, ASCIIMapping, JSMapping, CoffeeMapping,
  Drawing, ASCIIDrawing, DSVDrawing, SSVDrawing, CSVDrawing, TSVDrawing,
  Drawings, XLSXDrawings,
  Input, Mappings, Context, SVGTilerException, SVGNS, XLINKNS, main}
module?.exports ?= exports
window?.svgtiler ?= exports

unless window?
  main()

`}).call(this)`
