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
  svgtiler = require '../package.json'
  require 'coffeescript/register'
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

parseBox = (box) ->
  return null unless box
  box = box.split /\s*[\s,]\s*/
  .map parseNum
  return null if null in box
  box

extractOverflowBox = (xml) ->
  ## Parse and return root overflowBox attribute.
  ## Also remove it if present, so output is valid SVG.
  box = xml.documentElement.getAttribute 'overflowBox'
  xml.documentElement.removeAttribute 'overflowBox'
  parseBox box

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
    parseBox xml.documentElement.getAttribute 'viewBox'
  else
    recurse = (node) ->
      if node.nodeType != node.ELEMENT_NODE or
         node.nodeName in ['defs', 'use']
        return null
      # Ignore <symbol>s except the root <symbol> that we're bounding
      if node.nodeName == 'symbol' and node != xml.documentElement
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
    if not viewBox? or Infinity in viewBox or -Infinity in viewBox
      null
    else
      viewBox

isAuto = (xml, prop) ->
  xml.documentElement.hasAttribute(prop) and
  /^\s*auto\s*$/i.test xml.documentElement.getAttribute prop

attributeOrStyle = (node, attr, styleKey = attr) ->
  if value = node.getAttribute attr
    value.trim()
  else
    style = node.getAttribute 'style'
    if style
      match = ///(?:^|;)\s*#{styleKey}\s*:\s*([^;\s][^;]*)///i.exec style
      match?[1]

getHref = (node) ->
  for key in ['xlink:href', 'href']
    if href = node.getAttribute key
      return
        key: key
        href: href
  key: null
  href: null

extractZIndex = (node) ->
  ## Check whether DOM node has a specified z-index, defaulting to zero.
  ## Also remove z-index attribute, so output is valid SVG.
  ## Note that z-index must be an integer.
  ## 1. https://www.w3.org/Graphics/SVG/WG/wiki/Proposals/z-index suggests
  ## a z-index="..." attribute.  Check for this first.
  ## 2. Look for style="z-index:..." as in HTML.
  z = parseInt attributeOrStyle node, 'z-index'
  node.removeAttribute 'z-index'
  if isNaN z
    0
  else
    z

domRecurse = (node, callback) ->
  ###
  Recurse through DOM starting at `node`, calling `callback(node, parent)`
  on every recursive node except `node` itself.
  `callback()` should return a true value if you want to recurse into
  the specified node's children (typically, when there isn't a match).
  ###
  return unless node.hasChildNodes()
  child = node.lastChild
  while child?
    nextChild = child.previousSibling
    if callback child, node
      domRecurse child, callback
    child = nextChild
  null

contentType =
  '.png': 'image/png'
  '.jpg': 'image/jpeg'
  '.jpeg': 'image/jpeg'
  '.gif': 'image/gif'
  '.svg': 'image/svg+xml'

class Symbol
  @svgEncoding: 'utf8'
  @forceWidth: null   ## default: no size forcing
  @forceHeight: null  ## default: no size forcing
  @texText: false
  # Set default overflow behavior to visible unless --no-overflow specified;
  # use overflow:hidden to restore normal SVG behavior of keeping each tile
  # within its bounding box.
  @overflowDefault: 'visible'

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
                dirname: dirname
                svg: """
                  <image xlink:href="#{encodeURI data}"/>
                """
              when '.svg'
                dirname: path.dirname filename
                filename: filename
                svg: fs.readFileSync filename,
                       encoding: @svgEncoding
              else
                throw new SVGTilerException "Unrecognized extension in filename '#{data}' for symbol '#{key}'"
          else
            dirname: dirname
            svg: data
        else
          data
  includes: (substring) ->
    @key.indexOf(substring) >= 0
    ## ECMA6: @key.includes substring

escapeId = (key) ->
  ###
  According to XML spec [https://www.w3.org/TR/xml/#id],
  id/href follows the XML name spec: [https://www.w3.org/TR/xml/#NT-Name]
    NameStartChar ::= ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6] | [#xF8-#x2FF] | [#x370-#x37D] | [#x37F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
    NameChar      ::= NameStartChar | "-" | "." | [0-9] | #xB7 | [#x0300-#x036F] | [#x203F-#x2040]
    Name          ::= NameStartChar (NameChar)*
  In addition, colons in IDs fail when embedding an SVG via <img>.
  We use encodeURIComponent which escapes everything except
    A-Z a-z 0-9 - _ . ! ~ * ' ( )
  [https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent]
  into %-encoded symbols, plus we encode _ . ! ~ * ' ( ) and - 0-9 (start only).
  But % (and %-encoded) symbols are not supported, so we replace '%' with '_',
  an allowed character that we escape.
  In the special case of a blank key, we use the special _blank which cannot
  be generated by the escaping process.
  ###
  (encodeURIComponent key
   .replace /[_\.!~*'()]|^[\-0-9]/g,
     (c) -> "%#{c.charCodeAt(0).toString(16).toUpperCase()}"
   .replace /%/g, '_'
  ) or '_blank'

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
        console.error "SVG parse #{level} in symbol '#{@key}': #{msg}"
    .parseFromString @svg, 'image/svg+xml'
    # Remove from the symbol any top-level xmlns=SVGNS possibly added above:
    # we will have such a tag in the top-level <svg>.
    @xml.documentElement.removeAttribute 'xmlns'

    ## Wrap XML in <symbol> if not already.
    symbol = @xml.createElementNS SVGNS, 'symbol'
    symbol.setAttribute 'id', @id = escapeId @key
    # Avoid a layer of indirection for <symbol>/<svg> at top level
    if @xml.documentElement.nodeName in ['symbol', 'svg'] and
       not @xml.documentElement.nextSibling?
      for attribute in @xml.documentElement.attributes
        unless attribute.name in ['version', 'id'] or attribute.name[...5] == 'xmlns'
          symbol.setAttribute attribute.name, attribute.value
      doc = @xml.documentElement
      @xml.removeChild @xml.documentElement
    else
      doc = @xml
    for child in (node for node in doc.childNodes)
      symbol.appendChild child
    @xml.appendChild symbol

    ## <image> processing
    domRecurse @xml.documentElement, (node) =>
      if node.nodeName == 'image'
        ###
        Fix image-rendering: if unspecified, or if specified as "optimizeSpeed"
        or "pixelated", attempt to render pixels as pixels, as needed for
        old-school graphics.  SVG 1.1 and Inkscape define
        image-rendering="optimizeSpeed" for this.  Chrome doesn't support this,
        but supports a CSS3 (or SVG) specification of
        "image-rendering:pixelated".  Combining these seems to work everywhere.
        ###
        rendering = attributeOrStyle node, 'image-rendering'
        if not rendering? or rendering in ['optimizeSpeed', 'pixelated']
          node.setAttribute 'image-rendering', 'optimizeSpeed'
          style = node.getAttribute('style') ? ''
          style = style.replace /(^|;)\s*image-rendering\s*:\s*\w+\s*($|;)/,
            (m, before, after) -> before or after or ''
          style += ';' if style
          node.setAttribute 'style', style + 'image-rendering:pixelated'
        ## Read file for width/height detection and/or inlining
        {href, key} = getHref node
        filename = href
        filename = path.join @dirname, filename if @dirname? and filename
        if filename? and not /^data:|file:|[a-z]+:\/\//.test filename # skip URLs
          filedata = null
          try
            filedata = fs.readFileSync filename unless window?
          catch e
            console.warn "Failed to read image '#{filename}': #{e}"
          ## Fill in width and height
          size = null
          unless window?
            try
              size = require('image-size') filedata ? filename
            catch e
              console.warn "Failed to detect size of image '#{filename}': #{e}"
          if size?
            ## If one of width and height is set, scale to match.
            if not isNaN width = parseFloat node.getAttribute 'width'
              node.setAttribute 'height', size.height * (width / size.width)
            else if not isNaN height = parseFloat node.getAttribute 'height'
              node.setAttribute 'width', size.width * (height / size.height)
            else
              ## If neither width nor height are set, set both.
              node.setAttribute 'width', size.width
              node.setAttribute 'height', size.height
          ## Inline
          if filedata? and Drawing.inlineImages
            type = contentType[extensionOf filename]
            if type?
              node.setAttribute "data-filename", filename
              if size?
                node.setAttribute "data-width", size.width
                node.setAttribute "data-height", size.height
              node.setAttribute key,
                "data:#{type};base64,#{filedata.toString 'base64'}"
        false
      else
        true

    ## Set viewBox attribute if absent.
    @viewBox = svgBBox @xml
    if @viewBox? and not @xml.documentElement.hasAttribute 'viewBox'
      @xml.documentElement.setAttribute 'viewBox', @viewBox.join ' '

    # Overflow behavior
    overflow = attributeOrStyle @xml.documentElement, 'overflow'
    if @constructor.overflowDefault? and not overflow?
      @xml.documentElement.setAttribute 'overflow',
        overflow = @constructor.overflowDefault
    @overflowVisible = (overflow? and /^\s*(visible|scroll)\b/.test overflow)
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
    @overflowBox = extractOverflowBox @xml
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
    @zIndex = extractZIndex @xml.documentElement
    ## Optionally extract <text> nodes for LaTeX output
    if Symbol.texText
      @text = []
      domRecurse @xml.documentElement, (node, parent) =>
        if node.nodeName == 'text'
          @text.push node
          parent.removeChild node
          false # don't recurse into <text>'s children
        else
          true
  setId: (id) ->
    @id = id # for <use>
    @xml.documentElement.setAttribute 'id', id
  use: -> @  ## do nothing for static symbol
  usesContext: false

class DynamicSymbol extends Symbol
  @all: []
  constructor: (@key, @func, @dirname) ->
    super()
    @versions = {}
    @nversions = 0
    @constructor.all.push @
  @resetAll: ->
    ## Resets all DynamicSymbol's versions to 0.
    ## Use before starting a new SVG document.
    for symbol in @all
      symbol.versions = {}
      symbol.nversions = 0
  use: (context) ->
    result = @func.call context
    unless result?
      throw new Error "Function for symbol #{@key} returned #{result}"
    ## We use JSON serialization to detect duplicate symbols.  This enables
    ## return values like {filename: ...} and JSX virtual dom elements,
    ## in addition to raw SVG strings.
    string = JSON.stringify result
    unless string of @versions
      version = @nversions++
      @versions[string] =
        Symbol.parse "#{@key}_v#{version}", result, @dirname
      @versions[string].setId "#{escapeId @key}_v#{version}"
    @versions[string]
  usesContext: true

## Symbol to fall back to when encountering an unrecognized symbol.
## Path from https://commons.wikimedia.org/wiki/File:Replacement_character.svg
## by Amit6, released into the public domain.
unrecognizedSymbol = new StaticSymbol '_unrecognized', svg: '''
  <symbol viewBox="0 0 200 200" preserveAspectRatio="none" width="auto" height="auto">
    <rect width="200" height="200" fill="yellow"/>
    <path stroke="none" fill="red" d="M 200,100 100,200 0,100 100,0 200,100 z M 135.64709,74.70585 q 0,-13.52935 -10.00006,-22.52943 -9.99999,-8.99999 -24.35289,-8.99999 -17.29415,0 -30.117661,5.29409 L 69.05879,69.52938 q 9.764731,-6.23528 21.52944,-6.23528 8.82356,0 14.58824,4.82351 5.76469,4.82351 5.76469,12.70589 0,8.5883 -9.94117,21.70588 -9.94117,13.11766 -9.94117,26.76473 l 17.88236,0 q 0,-6.3529 6.9412,-14.9412 11.76471,-14.58816 12.82351,-16.35289 6.9412,-11.05887 6.9412,-23.29417 z m -22.00003,92.11771 0,-24.70585 -27.29412,0 0,24.70585 27.29412,0 z"/>
  </symbol>
'''
unrecognizedSymbol.setId '_unrecognized' # cannot be output of escapeId()

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

class Style extends Input
  load: (@css) ->

class CSSStyle extends Style
  @title: "CSS style file"
  parse: (filedata) ->
    @load filedata

class Styles
  constructor: (@styles = []) ->
  push: (map) ->
    @styles.push map

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
    dirname = path.dirname @filename if @filename?
    key = key.toString()  ## Sometimes get a number, e.g., from XLSX
    if key of @map
      @map[key]
    else if @function?
      ## Cache return value of function so that only one Symbol generated
      ## for each key.  It still may be a DynamicSymbol, which will allow
      ## it to make multiple versions, but keep track of which are the same.
      value = @function key
      if value?
        @map[key] = Symbol.parse key, value, dirname
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
  @title: "JavaScript mapping file (including JSX notation)"
  @help: "Object mapping symbol names to SYMBOL e.g. {dot: 'dot.svg'}"
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
    ## Mimick NodeJS module's __filename and __dirname variables.
    ## Redirect require() to use paths relative to the mapping file.
    ## xxx should probably actually create a NodeJS module when possible
    __filename = path.resolve @filename
    code =
      "var __filename = #{JSON.stringify __filename},
           __dirname = #{JSON.stringify path.dirname __filename},
           __require = require;
       require = (module) => __require(module.startsWith('.') ? __require('path').resolve(__dirname, module) : module);
       #{code}\n//@ sourceURL=#{@filename}"
    @load eval code

class CoffeeMapping extends JSMapping
  @title: "CoffeeScript mapping file (including JSX notation)"
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
  @inlineImages: not window?
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
  writeSVG: (mappings, styles, filename) ->
    ## Default filename is the input filename with extension replaced by .svg
    unless filename?
      filename = path.parse @filename
      if filename.ext == '.svg'
        filename.base += '.svg'
      else
        filename.base = filename.base[...-filename.ext.length] + '.svg'
      filename = path.format filename
    console.log '->', filename
    fs.writeFileSync filename, @renderSVG mappings, styles
    filename
  renderSVGDOM: (mappings, styles) ->
    ###
    Main rendering engine, returning an xmldom object for the whole document.
    Also saves the table of symbols in `@symbols`, the corresponding
    coordinates in `@coords`, and overall `@weight` and `@height`,
    for use by `renderTeX`.
    ###
    DynamicSymbol.resetAll()
    doc = domImplementation.createDocument SVGNS, 'svg'
    svg = doc.documentElement
    svg.setAttribute 'xmlns:xlink', XLINKNS
    svg.setAttribute 'version', '1.1'
    #svg.appendChild defs = doc.createElementNS SVGNS, 'defs'
    ## <style> tags for CSS
    for style in styles.styles
      svg.appendChild styleTag = doc.createElementNS SVGNS, 'style'
      styleTag.textContent = style.css
    ## Look up all symbols in the drawing.
    missing = {}
    @symbols =
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
    @symbols =
      for row, i in @symbols
        for symbol, j in row
          if symbol.usesContext
            symbol = symbol.use new Context @, i, j
          else
            symbol = symbol.use()
          unless symbol.key of symbolsByKey
            symbolsByKey[symbol.key] = symbol
          else if symbolsByKey[symbol.key] is not symbol
            console.warn "Multiple symbols with key #{symbol.key}"
          symbol
    ## Include all used symbols in SVG
    for key, symbol of symbolsByKey
      continue unless symbol?
      svg.appendChild symbol.xml.documentElement.cloneNode true
    ## Factor out duplicate inline <image>s into separate <symbol>s.
    inlineImages = {}
    inlineImageVersions = {}
    domRecurse svg, (node, parent) ->
      return true unless node.nodeName == 'image'
      {href} = getHref node
      return true unless href?.startsWith 'data:'
      # data-filename gets set to the original filename when inlining,
      # which we use for key labels so isn't needed as an exposed attribute.
      # Ditto for width and height of image.
      filename = node.getAttribute('data-filename') ? ''
      node.removeAttribute 'data-filename'
      width = node.getAttribute 'data-width'
      node.removeAttribute 'data-width'
      height = node.getAttribute 'data-height'
      node.removeAttribute 'data-height'
      # Transfer x/y/width/height to <use> element, for more re-usability.
      parent.replaceChild (use = doc.createElementNS SVGNS, 'use'), node
      for attr in ['x', 'y', 'width', 'height']
        use.setAttribute attr, node.getAttribute attr if node.hasAttribute attr
        node.removeAttribute attr
      # Memoize versions
      attributes =
        for attr in node.attributes
          "#{attr.name}=#{attr.value}"
      attributes.sort()
      attributes = attributes.join ' '
      if attributes not of inlineImages
        inlineImageVersions[filename] ?= 0
        version = inlineImageVersions[filename]++
        inlineImages[attributes] = "_image_#{escapeId filename}_v#{version}"
        svg.appendChild symbol = doc.createElementNS SVGNS, 'symbol'
        symbol.setAttribute 'id', inlineImages[attributes]
        # If we don't have width/height set from data-width/height fields,
        # we take the first used width/height as the master height.
        node.setAttribute 'width', width or use.getAttribute 'width'
        node.setAttribute 'height', height or use.getAttribute 'height'
        symbol.setAttribute 'viewBox', "0 0 #{width} #{height}"
        symbol.appendChild node
      use.setAttribute 'xlink:href', '#' + inlineImages[attributes]
      false
    ## Lay out the symbols in the drawing via SVG <use>.
    viewBox = [0, 0, 0, 0]  ## initially x-min, y-min, x-max, y-max
    levels = {}
    y = 0
    colWidths = {}
    @coords = []
    for row, i in @symbols
      @coords.push coordsRow = []
      rowHeight = 0
      for symbol in row when not symbol.autoHeight
        if symbol.height > rowHeight
          rowHeight = symbol.height
      x = 0
      for symbol, j in row
        coordsRow.push {x, y}
        continue unless symbol?
        levels[symbol.zIndex] ?= []
        levels[symbol.zIndex].push use = doc.createElementNS SVGNS, 'use'
        use.setAttribute 'xlink:href', '#' + symbol.id
        use.setAttributeNS SVGNS, 'x', x
        use.setAttributeNS SVGNS, 'y', y
        scaleX = scaleY = 1
        if symbol.autoWidth
          colWidths[j] ?= Math.max 0, ...(
            for row2 in @symbols when row2[j]? and not row2[j].autoWidth
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
    svg.setAttributeNS SVGNS, 'width', @width = viewBox[2]
    svg.setAttributeNS SVGNS, 'height', @height = viewBox[3]
    svg.setAttributeNS SVGNS, 'preserveAspectRatio', 'xMinYMin meet'
    doc
  renderSVG: (mappings, styles) ->
    out = new XMLSerializer().serializeToString @renderSVGDOM mappings, styles
    ## Parsing xlink:href in user's SVG fragments, and then serializing,
    ## can lead to these null namespace definitions.  Remove.
    out = out.replace /\sxmlns:xlink=""/g, ''
    out = prettyXML out,
      newline: '\n'  ## force consistent line endings, not require('os').EOL
    '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">

''' + out
  renderTeX: (filename) ->
    ## Must be called *after* `renderSVG` (or `renderSVGDOM`)
    filename = path.parse filename
    basename = filename.base[...-filename.ext.length]
    ## LaTeX based loosely on Inkscape's PDF/EPS/PS + LaTeX output extension.
    ## See http://tug.ctan.org/tex-archive/info/svg-inkscape/
    lines = ["""
      %% Creator: svgtiler #{svgtiler.version}, https://github.com/edemaine/svgtiler
      %% This LaTeX file includes and overlays text on top of companion file
      %% #{basename}.pdf/.png
      %%
      %% Instead of \\includegraphics, include this figure via
      %%   \\input{#{filename.base}}
      %% You can scale the image by first defining \\svg{width,height,scale}:
      %%   \\def\\svgwidth{\\linewidth} % full width
      %% or
      %%   \\def\\svgheight{5in}
      %% or
      %%   \\def\\svgscale{0.5} % 50%
      %% (If multiple are specified, the first in the list above takes priority.)
      %%
      %% If this file resides in another directory from the root .tex file,
      %% you need to help it find its auxiliary .pdf/.png file via one of the
      %% following options (any one will do):
      %%   1. \\usepackage{currfile} so that this file can find its own directory.
      %%   2. \\usepackage{import} and \\import{path/to/file/}{#{filename.base}}
      %%      instead of \\import{#{filename.base}}
      %%   3. \\graphicspath{{path/to/file/}} % note extra braces and trailing slash
      %%
      \\begingroup
        \\providecommand\\color[2][]{%
          \\errmessage{You should load package 'color.sty' to render color in svgtiler text.}%
          \\renewcommand\\color[2][]{}%
        }%
        \\ifx\\currfiledir\\undefined
          \\def\\currfiledir{}%
        \\fi
        \\ifx\\svgwidth\\undefined
          \\ifx\\svgheight\\undefined
            \\unitlength=0.75bp\\relax % 1px (SVG unit) = 0.75bp (SVG pts)
            \\ifx\\svgscale\\undefined\\else
              \\ifx\\real\\undefined % in case calc.sty not loaded
                \\unitlength=\\svgscale \\unitlength
              \\else
                \\setlength{\\unitlength}{\\unitlength * \\real{\\svgscale}}%
              \\fi
            \\fi
          \\else
            \\unitlength=\\svgheight
            \\unitlength=#{1/@height}\\unitlength % divide by image height
          \\fi
        \\else
          \\unitlength=\\svgwidth
          \\unitlength=#{1/@width}\\unitlength % divide by image width
        \\fi
        \\def\\clap#1{\\hbox to 0pt{\\hss#1\\hss}}%
        \\begin{picture}(#{@width},#{@height})%
          \\put(0,0){\\includegraphics[width=#{@width}\\unitlength]{\\currfiledir #{basename}}}%
    """]
    for row, i in @symbols
      for symbol, j in row
        {x, y} = @coords[i][j]
        for text in symbol.text
          tx = parseNum(text.getAttribute('x')) ? 0
          ty = parseNum(text.getAttribute('y')) ? 0
          content = (
            for child in text.childNodes when child.nodeType == 3 # TEXT_NODE
              child.data
          ).join ''
          anchor = attributeOrStyle text, 'text-anchor'
          if /^middle\b/.test anchor
            wrap = '\\clap{'
          else if /^end\b/.test anchor
            wrap = '\\rlap{'
          else #if /^start\b/.test anchor  # default
            wrap = '\\llap{'
          # "@height -" is to flip between y down (SVG) and y up (picture)
          lines.push "    \\put(#{x+tx},#{@height - (y+ty)}){\\color{#{attributeOrStyle(text, 'fill') or 'black'}}#{wrap}#{content}#{wrap and '}'}}%"
    lines.push """
        \\end{picture}%
      \\endgroup
    """, '' # trailing newline
    lines.join '\n'
  writeTeX: (filename) ->
    ###
    Must be called *after* `writeSVG`.
    Default filename is the input filename with extension replaced by .svg_tex
    (analogous to .pdf_tex from Inkscape's --export-latex feature, but noting
    that the text is extracted from the SVG not the PDF, and that this file
    works with both .pdf and .png auxiliary files).
    ###
    unless filename?
      filename = path.parse @filename
      if filename.ext == '.svg_tex'
        filename.base += '.svg_tex'
      else
        filename.base = filename.base[...-filename.ext.length] + '.svg_tex'
      filename = path.format filename
    console.log ' &', filename
    fs.writeFileSync filename, @renderTeX filename
    filename

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
  @filenameSeparator: '_'
  load: (datas) ->
    @drawings =
      for data in datas
        drawing = new Drawing
        drawing.filename = @filename
        drawing.subname = data.subname
        drawing.load data
        drawing
  subfilename: (extension, drawing) ->
    filename2 = path.parse @filename
    filename2.base = filename2.base[...-filename2.ext.length]
    if @drawings.length > 1
      filename2.base += @constructor.filenameSeparator + drawing.subname
    filename2.base += extension
    path.format filename2
  writeSVG: (mappings, styles, filename) ->
    for drawing in @drawings
      drawing.writeSVG mappings, styles, @subfilename '.svg', drawing
  writeTeX: (filename) ->
    for drawing in @drawings
      drawing.writeTeX @subfilename '.svg_tex', drawing

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
  constructor: (@drawing, @i, @j) ->
    @symbols = @drawing.symbols
    @filename = @drawing.filename
    @subname = @drawing.subname
    @symbol = @symbols[@i]?[@j]
    @key = @symbol?.key
  neighbor: (dj, di) ->
    new Context @drawing, @i + di, @j + dj
  includes: (args...) ->
    @symbol? and @symbol.includes args...
  row: (di = 0) ->
    i = @i + di
    for symbol, j in @symbols[i] ? []
      new Context @drawing, i, j
  column: (dj = 0) ->
    j = @j + dj
    for row, i in @symbols
      new Context @drawing, i, j

extensionMap =
  # Mappings
  '.txt': ASCIIMapping
  '.js': JSMapping
  '.jsx': JSMapping
  '.coffee': CoffeeMapping
  '.cjsx': CoffeeMapping
  # Drawings
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
  # Styles
  '.css': CSSStyle

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

inkscapeVersion = null

convertSVG = (format, svg, sync) ->
  child_process = require 'child_process'
  unless inkscapeVersion?
    result = child_process.spawnSync 'inkscape', ['--version']
    if result.error
      console.log "inkscape --version failed: #{result.error.message}"
    else if result.status or result.signal
      console.log "inkscape --version failed: #{result.stderr.toString()}"
    else
      inkscapeVersion = result.stdout.toString().replace /^Inkscape\s*/, ''

  filename = path.parse svg
  if filename.ext == ".#{format}"
    filename.base += ".#{format}"
  else
    filename.base = "#{filename.base[...-filename.ext.length]}.#{format}"
  output = path.format filename
  ## Workaround relative paths not working in MacOS distribution of Inkscape
  ## [https://bugs.launchpad.net/inkscape/+bug/181639]
  if process.platform == 'darwin'
    preprocess = path.resolve
  else
    preprocess = (x) -> x
  if inkscapeVersion.startsWith '0'
    args = [
      "-z"
      "--file=#{preprocess svg}"
      "--export-#{format}=#{preprocess output}"
    ]
  else ## Inkscape 1+
    args = [
      "--export-overwrite"
      #"--export-type=#{format}"
      "--export-filename=#{preprocess output}"
      preprocess svg
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
      inkscape = child_process.spawn 'inkscape', args
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
svgtiler #{svgtiler.version ? "(web)"}
Usage: #{process.argv[1]} (...options and filenames...)
Documentation: https://github.com/edemaine/svgtiler

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
  -t / --tex            Move <text> from SVG to accompanying LaTeX file.tex
  --no-inline           Don't inline <image>s into output SVG
  --no-overflow         Don't default <symbol> overflow to "visible"
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
                    `key` (symbol name), `i` and `j` (y and x coordinates),
                    `filename` (drawing filename), `subname` (subsheet name),
                    and supporting `neighbor`/`includes`/`row`/`column` methods
"""
  #object with one or more attributes
  process.exit()

main = ->
  mappings = new Mappings
  styles = new Styles
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
      when '-t', '--tex'
        Symbol.texText = true
      when '--no-sanitize'
        sanitize = false
      when '--no-overflow'
        Symbol.overflowDefault = null # no default
      when '--no-inline'
        Drawing.inlineImages = false
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
        else if input instanceof Style
          styles.push input
        else if input instanceof Drawing or input instanceof Drawings
          filenames = input.writeSVG mappings, styles
          input.writeTeX() if Symbol.texText
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
