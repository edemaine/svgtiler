unless window?
  path = require 'path'
  fs = require 'fs'
  xmldom = require '@xmldom/xmldom'
  DOMParser = xmldom.DOMParser
  domImplementation = new xmldom.DOMImplementation()
  XMLSerializer = xmldom.XMLSerializer
  prettyXML = require 'prettify-xml'
  graphemeSplitter = new require('grapheme-splitter')()
  metadata = require '../package.json'
  try
    metadata.modified = (fs.statSync __filename).mtimeMs
else
  DOMParser = window.DOMParser # escape CoffeeScript scope
  domImplementation = document.implementation
  XMLSerializer = window.XMLSerializer # escape CoffeeScript scope
  path =
    basename: (x) -> /[^/]*$/.exec(x)[0]
    extname: (x) -> /\.[^/]+$/.exec(x)[0]
    dirname: (x) -> /[^]*\/|/.exec(x)[0]
  graphemeSplitter = splitGraphemes: (x) -> x.split ''
  metadata = version: '(web)'

## Register `require` hooks of Babel and CoffeeScript,
## so that imported/required modules are similarly processed.
unless window?
  ## Babel plugin to add implicit `export default` to last line of program,
  ## to simulate the effect of `eval` but in a module context.
  implicitFinalExportDefault = ({types}) ->
    visitor:
      Program: (path) ->
        body = path.get 'body'
        return unless body.length  # empty program
        for part in body
          if types.isExportDefaultDeclaration part
            return  # already an export default, so don't add one
        last = body[body.length-1]
        if last.node.type == 'ExpressionStatement'
          exportLast = types.exportDefaultDeclaration last.node.expression
          exportLast.leadingComments = last.node.leadingComments
          exportLast.innerComments = last.node.innerComments
          exportLast.trailingComments = last.node.trailingComments
          last.replaceWith exportLast
        undefined

  babelConfig =
    plugins: [
      implicitFinalExportDefault
      [require.resolve('babel-plugin-auto-import'),
        declarations: [
          default: 'preact'
          path: 'preact'
        ,
          default: 'svgtiler'
          members: ['share']
          path: 'svgtiler'
        ]
      ]
      require.resolve '@babel/plugin-transform-modules-commonjs'
      [require.resolve('@babel/plugin-transform-react-jsx'),
        useBuiltIns: true
        runtime: 'automatic'
        importSource: 'preact'
        #pragma: 'preact.h'
        #pragmaFrag: 'preact.Fragment'
        throwIfNamespace: false
      ]
      require.resolve 'babel-plugin-module-deps'
    ]
    #inputSourceMap: true  # CoffeeScript sets this to its own source map
    sourceMaps: 'inline'
    retainLines: true

  ## Tell CoffeeScript's register to transpile with our Babel config.
  module.options =
    bare: true  # needed for implicitFinalExportDefault
    #inlineMap: true  # rely on Babel's source map
    transpile: babelConfig

  require('@babel/register') babelConfig
  CoffeeScript = require 'coffeescript'
  CoffeeScript.FILE_EXTENSIONS = ['.coffee', '.cjsx']
  CoffeeScript.register()

defaultSettings =
  ## Force all tiles to have specified width or height.
  forceWidth: null   ## default: no size forcing
  forceHeight: null  ## default: no size forcing
  ## Inline <image>s into output SVG (replacing URLs to other files).
  inlineImages: not window?
  ## Process hidden sheets within spreadsheet files.
  keepHidden: false
  ## Don't delete blank extreme rows/columns.
  keepMargins: false
  ## Directories to output all or some files.
  outputDir: null  ## default: same directory as input
  outputDirExt:  ## by extension; default is to use outputDir
    '.svg': null
    '.pdf': null
    '.png': null
    '.svg_tex': null
  ## Path to inkscape.  Default searches PATH.
  inkscape: 'inkscape'
  ## Default overflow behavior is 'visible' unless --no-overflow specified;
  ## use `overflow:hidden` to restore normal SVG behavior of keeping each tile
  ## within its bounding box.
  overflowDefault: 'visible'
  ## When a mapping refers to an SVG filename, assume this encoding.
  svgEncoding: 'utf8'
  ## Move <text> from SVG to accompanying LaTeX file.tex.
  texText: false
  ## Use `href` instead of `xlink:href` attribute in <use> and <image>.
  ## `href` behaves better in web browsers, but `xlink:href` is more
  ## compatible with older SVG drawing programs.
  useHref: window?
  ## renderDOM-specific
  filename: 'drawing.asc'  # default filename when not otherwise specified
  keepParent: false
  keepClass: false
  ## Major state
  mappings: null  # should be Mappings instance
  styles: null  # should be Styles instance

getSetting = (settings, key) ->
  settings?[key] ? defaultSettings[key]
getOutputDir = (settings, extension) ->
  dir = getSetting(settings, 'outputDirExt')?[extension] ?
        getSetting settings, 'outputDir'
  if dir
    try
      fs.mkdirSync dir, recursive: true
    catch err
      console.warn "Failed to make directory '#{dir}': #{err}"
  dir
class HasSettings
  getSetting: (key) -> getSetting @settings, key
  getOutputDir: (extension) -> getOutputDir @settings, extension

SVGNS = 'http://www.w3.org/2000/svg'
XLINKNS = 'http://www.w3.org/1999/xlink'

splitIntoLines = (data) ->
  data
  .replace /\r\n/g, '\n'
  .replace /\r/g, '\n'
  .split '\n'
whitespace = /[\s\uFEFF\xA0]+/  ## based on https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/Trim

extensionOf = (filename) -> path.extname(filename).toLowerCase()

class SVGTilerError extends Error
  constructor: (message) ->
    super message
    @name = 'SVGTilerError'

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

svgBBox = (dom, auto = true) ->
  ## xxx Many unsupported features!
  ##   - transformations
  ##   - used symbols/defs
  ##   - paths
  ##   - text
  ##   - line widths which extend bounding box
  if dom.documentElement.hasAttribute 'viewBox'
    parseBox dom.documentElement.getAttribute 'viewBox'
  else if auto
    recurse = (node) ->
      if node.nodeType != node.ELEMENT_NODE or
         node.nodeName in ['defs', 'use']
        return null
      # Ignore <symbol>s except the root <symbol> that we're bounding
      if node.nodeName == 'symbol' and node != dom.documentElement
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
          xmin = Math.min ...xs
          ymin = Math.min ...ys
          if isNaN(xmin) or isNaN(ymin) # invalid points attribute; don't render
            null
          else
            [xmin, ymin, Math.max(...xs) - xmin, Math.max(...ys) - ymin]
        else
          viewBoxes = (recurse(child) for child in node.childNodes)
          viewBoxes = (viewBox for viewBox in viewBoxes when viewBox?)
          xmin = Math.min ...(viewBox[0] for viewBox in viewBoxes)
          ymin = Math.min ...(viewBox[1] for viewBox in viewBoxes)
          xmax = Math.max ...(viewBox[0]+viewBox[2] for viewBox in viewBoxes)
          ymax = Math.max ...(viewBox[1]+viewBox[3] for viewBox in viewBoxes)
          [xmin, ymin, xmax - xmin, ymax - ymin]
    viewBox = recurse dom.documentElement
    if not viewBox? or Infinity in viewBox or -Infinity in viewBox
      null
    else
      viewBox

isAuto = (dom, prop) ->
  dom.documentElement.hasAttribute(prop) and
  /^\s*auto\s*$/i.test dom.documentElement.getAttribute prop

attributeOrStyle = (node, attr, styleKey = attr) ->
  if value = node.getAttribute attr
    value.trim()
  else
    style = node.getAttribute 'style'
    if style
      match = ///(?:^|;)\s*#{styleKey}\s*:\s*([^;\s][^;]*)///i.exec style
      match?[1]
removeAttributeOrStyle = (node, attr, styleKey = attr) ->
  node.removeAttribute attr
  style = node.getAttribute 'style'
  return unless style?
  newStyle = style.replace ///(?:^|;)\s*#{styleKey}\s*:\s*([^;\s][^;]*)///i, ''
  if style != newStyle
    if newStyle.trim()
      node.setAttribute 'style', newStyle
    else
      node.removeAttribute 'style'

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
  z = parseFloat attributeOrStyle node, 'z-index'
  removeAttributeOrStyle node, 'z-index'
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

## Support for `require`/`import`ing images.
## SVG files get parsed into Preact Virtual DOM so you can manipulate them,
## while raster images get converted into <image> Preact Virtual DOM elements.
## In either case, DOM gets `svg` attribute with raw SVG string.
unless window?
  pirates = require 'pirates'
  pirates.settings = defaultSettings
  pirates.addHook (code, filename) ->
    if '.svg' == extensionOf filename
      code = removeSVGComments code
      domCode = require('@babel/core').transform "module.exports = #{code}",
        {...babelConfig, filename}
      """
      #{domCode.code}
      module.exports.svg = #{JSON.stringify code};
      """
    else
      href = hrefAttr pirates.settings
      """
      module.exports = require('preact').h('image', #{JSON.stringify "#{href}": filename});
      module.exports.svg = '<image #{href}="'+#{JSON.stringify filename.replace /"/g, '&quot;'}+'"/>';
      """
  , exts: Object.keys contentType

isPreact = (data) ->
  typeof data == 'object' and data?.type? and data.props?
renderPreact = (data) ->
  (window?.preactRenderToString?.default ? require('preact-render-to-string')) \
    data

$static = Symbol 'svgtiler.static'
wrapStatic = (x) -> [$static]: x  # exported as `static` but that's reserved

#fileCache = new Map
loadSVG = (filename, settings) ->
  #if (found = fileCache.get filename)?
  #  return found
  #data =
  fs.readFileSync filename,
    encoding: getSetting settings, 'svgEncoding'
    ## TODO: Handle <?xml encoding="..."?> or BOM to override svgEncoding.
  #fileCache.set filename, data
  #data

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

removeSVGComments = (svg) ->
  ## Remove SVG/XML comments such as <?xml...?> and <!DOCTYPE>
  ## (spec: https://www.w3.org/TR/2008/REC-xml-20081126/#NT-prolog)
  svg.replace /<\?[^]*?\?>|<![^-][^]*?>|<!--[^]*?-->/g, ''

class Tile extends HasSettings
  constructor: (@key, @value, @settings) ->
    ## `@value` can be a string or Preact VDOM.
    super()
    unless @value?
      throw new SVGTilerError "Attempt to create tile '#{@key}' without content"

  makeSVG: ->
    return @svg if @svg?
    ## Set `@svg` to SVG string for duplication detection.
    if isPreact @value
      ## Render Preact virtual dom nodes (e.g. from JSX notation) into strings.
      ## Serialization + parsing shouldn't be necessary, but this lets us
      ## deal with one parsed format (xmldom).
      @svg = renderPreact @value
    else if typeof @value == 'string'
      if @value.trim() == ''  ## Blank SVG treated as 0x0 symbol
        @svg = '<symbol viewBox="0 0 0 0"/>'
      else unless @value.includes '<'  ## No <'s -> interpret as filename
        filename = @value
        filename = path.join @settings.dirname, filename if @settings?.dirname?
        extension = extensionOf filename
        ## <image> tag documentation: "Conforming SVG viewers need to
        ## support at least PNG, JPEG and SVG format files."
        ## [https://svgwg.org/svg2-draft/embedded.html#ImageElement]
        switch extension
          when '.png', '.jpg', '.jpeg', '.gif'
            @svg = """
              <image #{hrefAttr @settings}="#{encodeURI @value}"/>
            """
          when '.svg'
            @filename = filename
            @settings = {...@settings, dirname: path.dirname filename}
            @svg = loadSVG @filename, @settings
          else
            throw new SVGTilerError "Unrecognized extension in filename '#{@value}' for tile '#{@key}'"
      else
        @svg = @value
    else
      throw new SVGTilerError "Invalid value for tile '#{@key}': #{typeof @value}"
    ## Remove initial SVG/XML comments (for broader duplication detection,
    ## and the next replace rule).
    @svg = removeSVGComments @svg

  setId: (@id) ->
    @dom.documentElement.setAttribute 'id', @id if @dom?
  makeDOM: (wrapper = 'symbol') ->
    return @dom if @dom?
    @makeSVG()
    ## Force SVG namespace when parsing, so nodes have correct namespaceURI.
    ## (This is especially important on the browser, so the results can be
    ## reparented into an HTML Document.)
    svg = @svg.replace /^\s*<(?:[^<>'"\/]|'[^']*'|"[^"]*")*\s*(\/?\s*>)/,
      (match, end) ->
        unless match.includes 'xmlns'
          match = match[...match.length-end.length] +
            " xmlns='#{SVGNS}'" + match[match.length-end.length..]
        match
    @dom = new DOMParser
      locator:  ## needed when specifying errorHandler
        line: 1
        col: 1
      errorHandler: (level, msg, indent = '  ') =>
        msg = msg.replace /^\[xmldom [^\[\]]*\]\t/, ''
        msg = msg.replace /@#\[line:(\d+),col:(\d+)\]$/, (match, line, col) =>
          lines = svg.split '\n'
          (if line > 1 then indent + lines[line-2] + '\n' else '') +
          indent + lines[line-1] + '\n' +
          indent + ' '.repeat(col-1) + '^^^' +
          (if line < lines.length then '\n' + indent + lines[line] else '')
        console.error "SVG parse #{level} in tile '#{@key}': #{msg}"
    .parseFromString svg, 'image/svg+xml'
    ## Remove from the symbol any top-level xmlns=SVGNS or xmlns:xlink,
    ## in the original parsed content or possibly added above,
    ## to avoid conflict with these attributes in the top-level <svg>.
    @dom.documentElement.removeAttribute 'xmlns'
    unless @getSetting 'useHref'
      @dom.documentElement.removeAttribute 'xmlns:xlink'

    ## Wrap XML in <symbol> if not already.
    symbol = @dom.createElementNS SVGNS, wrapper
    ## Force `id` to be first attribute.
    symbol.setAttribute 'id', @id if @id?
    # Avoid a layer of indirection for <symbol>/<svg> at top level
    if @dom.documentElement.nodeName in ['symbol', 'svg'] and
       not @dom.documentElement.nextSibling?
      for attribute in @dom.documentElement.attributes
        unless attribute.name in ['version', 'id'] or attribute.name.startsWith 'xmlns'
          symbol.setAttribute attribute.name, attribute.value
      @dom.removeChild doc = @dom.documentElement
    else
      doc = @dom
      ## Allow top-level object to specify <symbol> data.
      for attribute in ['z-index', 'viewBox', 'overflowBox']
        if doc.documentElement.hasAttribute attribute
          symbol.setAttribute attribute,
            doc.documentElement.getAttribute attribute
          doc.documentElement.removeAttribute attribute
    for child in (node for node in doc.childNodes)
      symbol.appendChild child
    @dom.appendChild symbol

    ## <image> processing
    domRecurse @dom.documentElement, (node) =>
      if node.nodeName == 'image'
        ###
        Fix image-rendering: if unspecified, or if specified as "optimizeSpeed"
        or "pixelated", attempt to render pixels as pixels, as needed for
        old-school graphics.  SVG 1.1 and Inkscape define
        image-rendering="optimizeSpeed" for this.  Chrome doesn't support this,
        but supports a CSS3 (or SVG) specification of
        "image-rendering:pixelated".  Combining these seems to work everywhere.
        ###
        imageRendering = attributeOrStyle node, 'image-rendering'
        if not imageRendering? or
           imageRendering in ['optimizeSpeed', 'pixelated']
          node.setAttribute 'image-rendering', 'optimizeSpeed'
          style = node.getAttribute('style') ? ''
          style = style.replace /(^|;)\s*image-rendering\s*:\s*\w+\s*($|;)/,
            (m, before, after) -> before or after or ''
          style += ';' if style
          node.setAttribute 'style', style + 'image-rendering:pixelated'
        ## Read file for width/height detection and/or inlining
        {href, key} = getHref node
        filename = href
        if @settings?.dirname? and filename
          filename = path.join @settings.dirname, filename
        if filename? and not /^data:|file:|[a-z]+:\/\//.test filename # skip URLs
          filedata = null
          try
            filedata = fs.readFileSync filename unless window?
          catch e
            console.warn "Failed to read image '#{filename}': #{e}"
          ## Fill in width and/or height if missing
          width = parseFloat node.getAttribute 'width'
          height = parseFloat node.getAttribute 'height'
          if (isNaN width) or (isNaN height)
            size = null
            if filedata? and not window?
              try
                size = require('image-size') filedata ? filename
              catch e
                console.warn "Failed to detect size of image '#{filename}': #{e}"
            if size?
              ## If one of width and height is set, scale to match.
              if not isNaN width
                node.setAttribute 'height', size.height * (width / size.width)
              else if not isNaN height
                node.setAttribute 'width', size.width * (height / size.height)
              else
                ## If neither width nor height are set, set both.
                node.setAttribute 'width', size.width
                node.setAttribute 'height', size.height
          ## Inline
          if filedata? and @getSetting 'inlineImages'
            type = contentType[extensionOf filename]
            if type?
              node.setAttribute "data-filename", path.basename filename
              if size?
                node.setAttribute "data-width", size.width
                node.setAttribute "data-height", size.height
              node.setAttribute key,
                "data:#{type};base64,#{filedata.toString 'base64'}"
        false
      else
        true

    ## Compute viewBox attribute if absent and wrapping in <symbol>.
    @viewBox = svgBBox @dom, wrapper == 'symbol'

    ## Overflow behavior
    overflow = attributeOrStyle @dom.documentElement, 'overflow'
    if not overflow? and (overflowDefault = @getSetting 'overflowDefault')?
      @dom.documentElement.setAttribute 'overflow',
        overflow = overflowDefault
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
      ## Reset viewBox attribute in case either absent (and computed via
      ## svgBBox) or changed to avoid zeroes.
      @dom.documentElement.setAttribute 'viewBox', @viewBox.join ' '
    @overflowBox = extractOverflowBox @dom
    @width = forceWidth if (forceWidth = @getSetting 'forceWidth')?
    @height = forceHeight if (forceHeight = @getSetting 'forceHeight')?
    warnings = []
    unless @width?
      warnings.push 'width'
      @width = 0
    unless @height?
      warnings.push 'height'
      @height = 0
    if warnings.length > 0
      console.warn "Failed to detect #{warnings.join ' and '} of SVG for tile '#{@key}'"
    ## Detect special `width="auto"` and/or `height="auto"` fields for future
    ## processing, and remove them to ensure valid SVG.
    @autoWidth = isAuto @dom, 'width'
    @autoHeight = isAuto @dom, 'height'
    @dom.documentElement.removeAttribute 'width' if @autoWidth
    @dom.documentElement.removeAttribute 'height' if @autoHeight
    @zIndex = extractZIndex @dom.documentElement
    ## Optionally extract <text> nodes for LaTeX output
    if @getSetting 'texText'
      @text = []
      domRecurse @dom.documentElement, (node, parent) =>
        if node.nodeName == 'text'
          @text.push node
          parent.removeChild node
          false # don't recurse into <text>'s children
        else
          true
    @dom

## Tile to fall back to when encountering an unrecognized key.
## Path from https://commons.wikimedia.org/wiki/File:Replacement_character.svg
## by Amit6, released into the public domain.
unrecognizedTile = new Tile '_unrecognized', '''
  <symbol viewBox="0 0 200 200" preserveAspectRatio="none" width="auto" height="auto">
    <rect width="200" height="200" fill="yellow"/>
    <path stroke="none" fill="red" d="M 200,100 100,200 0,100 100,0 200,100 z M 135.64709,74.70585 q 0,-13.52935 -10.00006,-22.52943 -9.99999,-8.99999 -24.35289,-8.99999 -17.29415,0 -30.117661,5.29409 L 69.05879,69.52938 q 9.764731,-6.23528 21.52944,-6.23528 8.82356,0 14.58824,4.82351 5.76469,4.82351 5.76469,12.70589 0,8.5883 -9.94117,21.70588 -9.94117,13.11766 -9.94117,26.76473 l 17.88236,0 q 0,-6.3529 6.9412,-14.9412 11.76471,-14.58816 12.82351,-16.35289 6.9412,-11.05887 6.9412,-23.29417 z m -22.00003,92.11771 0,-24.70585 -27.29412,0 0,24.70585 27.29412,0 z"/>
  </symbol>
'''
unrecognizedTile.id = '_unrecognized' # cannot be output of escapeId()

class Input extends HasSettings
  ###
  Abstract base class for all inputs to SVG Tiler, in particular
  `Mapping`, `Style`, and `Drawing` and their format-specific subclasses.

  Each subclass should define:
  * `parse(data)` method that parses the input contents in the format
    defined by the subclass (specified manually by the user, or
    automatically read from the input file).
  * `skipRead: true` attribute if you don't want `@parseFile` class method
    to read the file data and pass it into `parse`, in case you want to read
    from `@filename` directly yourself in a specific way.
  ###
  constructor: (data, opts) ->
    ###
    `data` is input-specific data for direct creation (e.g. without a file),
    which is processed via a `parse` method (which subclass must define).
    `opts` is an object with options attached directly to the Input
    (*before* `parse` gets called), including `filename` and `settings`.
    ###
    super()
    @[key] = value for key, value of opts if opts?
    @parse data
  @encoding: 'utf8'
  @parseFile: (filename, filedata, settings) ->
    ###
    Generic method to parse file once we're already in the correct subclass.
    Automatically reads the file contents from `filename` unless
    * `@skipRead` is true, or
    * file contents are specified via `settings.filedata`.
      Use this to avoid attempting to use the file system on the browser.
    ###
    modified = -Infinity
    try
      modified = (fs.statSync filename).mtimeMs
    unless filedata? or @skipRead
      filedata = fs.readFileSync filename, encoding: @encoding
    new @ filedata, {filename, modified, settings}
  @recognize: (filename, filedata, settings) ->
    ###
    Recognize type of file and call corresponding class's `parseFile`.
    Meant to be used as `Input.recognize(...)` via top-level Input class,
    without specific subclass.
    ###
    extension = extensionOf filename
    if extensionMap.hasOwnProperty extension
      extensionMap[extension].parseFile filename, filedata, settings
    else
      throw new SVGTilerError "Unrecognized extension in filename #{filename}"
  dependsOn: (@deps) ->
    for dep in @deps
      try
        modified = (fs.statSync dep).mtimeMs
      continue unless modified?
      @modified = Math.max @modified, modified
  filenameSeparator: '_'
  generateFilename: (ext, filename = @filename, subname = @subname) ->
    filename = path.parse filename
    delete filename.base
    if subname
      filename.name += (@filenameSeparator ? '') + subname
    if filename.ext == ext
      filename.ext += ext
    else
      filename.ext = ext
    if (outputDir = @getOutputDir ext)?
      filename.dir = outputDir
    path.format filename

class Style extends Input
  ###
  Base Style class assumes any passed data is in CSS format,
  stored in `@css` attribute.
  ###
  parse: (@css) ->

class CSSStyle extends Style
  ## Style in CSS format.  Equivalent to Style base class.
  @title: "CSS style file"

class StylusStyle extends Style
  ## Style in Stylus format.
  @title: "Stylus style file (https://stylus-lang.com/)"
  parse: (stylus) ->
    styl = require('stylus') stylus,
      filename: @filename
    super styl.render()

class ArrayWrapper extends Array
  ###
  Array-like object (indeed, Array subclass) where each item in the array
  is supposed to be of a fixed class, given by the `@itemClass` class attribute.
  For example, `Styles` is like an array of `Style`s; and
  `Mappings` is like an array of `Mapping`s.
  ###
  @from: (data) ->
    ###
    Enforce `data` to be `ArrayWrapper` (sub)class.
    Supported formats:
      * `ArrayWrapper` (do nothing)
      * `@itemClass` (wrap in singleton)
      * raw data to pass to `new @itemClass`
      * `Array` of `@itemClass`
      * `Array` of raw data to pass to `new @itemClass`
      * `Array` of a mixture
      * `undefined`/`null` (empty)
    ###
    if data instanceof @
      data
    else if data?
      data = [data] unless Array.isArray data
      new @ ...(
        for item in data when item?
          if item instanceof @itemClass
            item
          else
            new @itemClass item
      )
    else
      new @

class Styles extends ArrayWrapper
  @itemClass: Style

currentMapping = null
getMapping = ->
  ## Returns current `Mapping` object,
  ## when used at top level of a JS/CS mapping file.
  currentMapping
runWithMapping = (mapping, fn) ->
  ## Runs the specified function `fn` as if it were called
  ## at the top level of the specified mapping.
  oldMapping = currentMapping
  currentMapping = mapping
  try
    fn()
  finally
    currentMapping = oldMapping

beforeRender = (fn) ->
  unless currentMapping?
    throw new SVGTilerError "svgtiler.beforeRender called outside mapping file"
  currentMapping.beforeRender fn
afterRender = (fn) ->
  unless currentMapping?
    throw new SVGTilerError "svgtiler.afterRender called outside mapping file"
  currentMapping.afterRender fn

class Mapping extends Input
  ###
  Base Mapping class.
  The passed-in data can be any supported output from a JavaScript mapping
  file: an object, a Map, or a function resolving to one of the above
  or a String (containing SVG or a filename), Preact VDOM, or null/undefined.
  In this class and subclasses, `@map` stores this data.
  ###
  constructor: (data, opts) ->
    super data, {
      cache: new Map  # for static tiles
      beforeRenderQueue: []
      afterRenderQueue: []
      ...opts
    }
    @settings = {...@settings, dirname: path.dirname @filename} if @filename?
  parse: (@map) ->
    unless typeof @map in ['function', 'object']
      console.warn "Mapping file #{@filename} returned invalid mapping data of type (#{typeof @map}): should be function or object"
      @map = null
    if isPreact @map
      console.warn "Mapping file #{@filename} returned invalid mapping data (Preact DOM): should be function or object"
      @map = null
  lookup: (key, context) ->
    ## `key` normally should be a String (via `AutoDrawing::parse` coercion).
    ## Check cache (used for static tiles).
    if (found = @cache.get key)?
      return found

    ## Repeatedly expand `@map` until we get string, Preact VDOM, or
    ## null/undefined.
    value = @map
    isStatic = undefined
    while value? and typeof value != 'string' and not isPreact value
      if value instanceof Map or value instanceof WeakMap
        value = value.get key
      else if typeof value == 'function'
        value = value.call context, key, context
        ## Use of a function implies dynamic, unless there's a static wrapper.
        isStatic ?= false
      else if $static of value  # static wrapper from wrapStatic
        value = value[$static]
        ## Static wrapper forces static, even if there are functions.
        isStatic = true
      else  # typeof value == 'object'
        if value.hasOwnProperty key  # avoid inherited property e.g. toString
          value = value[key]
        else
          value = undefined
    isStatic ?= true  # static unless we saw a function and no static wrapper

    ## Build tile if non-null, and save in cache if it's static.
    if value?
      tile = new Tile key, value, @settings
      tile.isStatic = isStatic
      @cache.set key, tile if isStatic
      tile
    else
      @cache.set key, value if isStatic
      value
  beforeRender: (fn) ->
    @beforeRenderQueue.push fn
  afterRender: (fn) ->
    @afterRenderQueue.push fn
  doBeforeRender: (render, onResult) ->
    for callback in @beforeRenderQueue
      result = callback.call render, render
      onResult? result
  doAfterRender: (render, onResult) ->
    for callback in @afterRenderQueue
      result = callback.call render, render
      onResult? result

class ASCIIMapping extends Mapping
  @title: "ASCII mapping file"
  @help: "Each line is <tile-name><space><raw SVG or filename.svg>"
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
    super map

class JSMapping extends Mapping
  @title: "JavaScript mapping file (including JSX notation)"
  @help: "Object mapping tile names to TILE e.g. {dot: 'dot.svg'}"
  @skipRead: true  # `require` loads file contents for us
  parse: (data) ->
    unless data?
      ## Normally use `require` to load code as a real NodeJS module
      filename = path.resolve @filename
      ## Debug Babel output
      #{code} = require('@babel/core').transform fs.readFileSync(filename), {
      #  ...babelConfig
      #  filename: @filename
      #}
      #console.log code
      pirates?.settings = @settings
      @module = runWithMapping @, -> require filename
      super @module.default ? {}
      @walkDeps filename
    else
      ## But if file has been explicitly loaded (e.g. in browser),
      ## compile manually and simulate module.
      {code} = require('@babel/core').transform data, {
        ...babelConfig
        filename: @filename
      }
      #console.log code
      @module = {}
      ## Mimick NodeJS module's __filename and __dirname variables
      ## [https://nodejs.org/api/modules.html#modules_the_module_scope]
      _filename = path.resolve @filename
      _dirname = path.dirname _filename
      ## Use `new Function` instead of `eval` for improved performance and to
      ## restrict to passed arguments + global scope.
      #super eval code
      func = new Function \
        'exports', '__filename', '__dirname', 'svgtiler', 'preact', code
      runWithMapping @, ->
        func @module, _filename, _dirname, svgtiler,
          (if code.includes 'preact' then require 'preact')
      super @module.default
  walkDeps: (filename) ->
    deps = new Set
    recurse = (modname) =>
      deps.add modname
      for dep in require.cache[modname]?.deps ? []
        unless deps.has dep
          recurse dep
    recurse filename
    @dependsOn (dep for dep from deps)

class CoffeeMapping extends JSMapping
  @title: "CoffeeScript mapping file (including JSX notation)"
  @help: "Object mapping tile names to TILE e.g. dot: 'dot.svg'"
  parse: (data) ->
    unless data?
      ## Debug CoffeeScript output
      #{code} = require('@babel/core').transform(
      #  require('coffeescript').compile(
      #    fs.readFileSync(@filename, encoding: 'utf8'),
      #    bare: true
      #    inlineMap: true
      #    filename: @filename
      #    sourceFiles: [@filename])
      #  {...babelConfig, filename: @filename})
      #console.log code
      ## Normally rely on `require` and `CoffeeScript.register` to load code.
      super data
    else
      ## But if file has been explicitly loaded (e.g. in browser),
      ## compile manually.
      super require('coffeescript').compile data,
        bare: true
        inlineMap: true
        filename: @filename
        sourceFiles: [@filename]

class Mappings extends ArrayWrapper
  @itemClass: Mapping
  lookup: (key, context) ->
    return unless @length
    for i in [@length-1..0]
      value = @[i].lookup key, context
      return value if value?
    undefined
  doBeforeRender: (render, callback) ->
    for mapping in @
      mapping.doBeforeRender render, callback
  doAfterRender: (render, callback) ->
    for mapping in @
      mapping.doAfterRender render, callback

blankCells = new Set [
  ''
  ' '  ## for ASCII art in particular
]

allBlank = (list) ->
  for x in list
    if x? and not blankCells.has x
      return false
  true

hrefAttr = (settings) ->
  if getSetting settings, 'useHref'
    'href'
  else
    'xlink:href'

maybeWrite = (filename, data) ->
  ## Writes data to filename, unless the file is already identical to data.
  ## Returns whether the write actually happened.
  try
    if data == fs.readFileSync filename, encoding: 'utf8'
      return false
  fs.writeFileSync filename, data
  true

###
This was a possible replacement for calls to maybeWrite, to prevent future
calls from running the useless job again, but it doesn't interact well with
PDF/PNG conversion: svgink will think it needs to convert.

writeOrTouch = (filename, data) ->
  ## Writes data to filename, unless the file is already identical to data,
  ## in which case it touches the file (so that we don't keep regenerating it).
  ## Returns whether the write actually happened.
  wrote = maybeWrite filename, data
  unless wrote
    now = new Date
    fs.utimesSync filename, now, now
  wrote
###

class Drawing extends Input
  ###
  Base Drawing class uses a data format of an Array of Array of keys,
  where `data[i][j]` represents the key in row `i` and column `j`,
  without any preprocessing.  This is meant for direct API use,
  whereas AutoDrawing provides preprocessing for data from mapping files.
  In this class and subclasses, `@keys` stores the Array of Array of keys.
  ###
  parse: (@keys) ->
  renderDOM: (settings = @settings) ->
    new Render @, settings
    .makeDOM()
  render: (settings = @settings) ->
    ## Writes SVG and optionally TeX file.
    ## Returns output SVG filename.
    r = new Render @, settings
    filename = r.writeSVG()
    r.writeTeX() if getSetting settings, 'texText'
    filename
  get: (j, i) ->
    @keys[i]?[j]
  at: (j, i) ->
    if i < 0
      i += @keys.length
    if j < 0
      j += @keys[i]?.length ? 0
    @keys[i]?[j]

class AutoDrawing extends Drawing
  ###
  Extended Drawing base class that preprocesses the drawing as follows:
  * Casts all keys to strings, in particular to handle Number data.
  * Optionally removes margins according to `keepMargins` setting.
  ###
  parse: (data) ->
    ## Turn strings into arrays, and turn numbers (e.g. from XLSX) into strings.
    unless @skipStringCast
      data =
        for row in data
          for cell in row
            String cell
    unless @getSetting 'keepMargins'
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
        j = Math.max ...(row.length for row in data)
        while j >= 0 and allBlank (row[j] for row in data)
          for row in data
            if j < row.length
              row.pop()
          j--
    super data

class ASCIIDrawing extends AutoDrawing
  @title: "ASCII drawing (one character per tile)"
  parse: (data) ->
    super(
      for line in splitIntoLines data
        graphemeSplitter.splitGraphemes line
    )

class DSVDrawing extends AutoDrawing
  ###
  Abstract base class for all Delimiter-Separator Value (DSV) drawings.
  Each subclass must define `@delimiter` class property.
  ###
  parse: (data) ->
    ## Remove trailing newline / final blank line.
    if data[-2..] == '\r\n'
      data = data[...-2]
    else if data[-1..] in ['\r', '\n']
      data = data[...-1]
    ## CSV parser.
    super require('csv-parse/sync').parse data,
      delimiter: @constructor.delimiter
      relax_column_count: true

class SSVDrawing extends DSVDrawing
  @title: "Space-delimiter drawing (one word per tile)"
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
  parse: (datas) ->
    @drawings =
      for data in datas
        new Drawing parse,
          settings: @settings
          filename: @filename
          subname: data.subname
  render: (settings = @settings) ->
    ## Writes SVG and optionally TeX files.
    ## Returns array of output SVG filenames.
    for drawing in @drawings
      drawing.render settings

class XLSXDrawings extends Drawings
  @encoding: 'binary'
  @title: "Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)"
  parse: (data) ->
    xlsx = require 'xlsx'
    workbook = xlsx.read data, type: 'binary'
    ## https://www.npmjs.com/package/xlsx#common-spreadsheet-format
    super(
      for sheetInfo in workbook.Workbook.Sheets
        subname = sheetInfo.name
        sheet = workbook.Sheets[subname]
        ## 0 = Visible, 1 = Hidden, 2 = Very Hidden
        ## https://sheetjs.gitbooks.io/docs/#sheet-visibility
        if sheetInfo.Hidden and not @getSetting 'keepHidden'
          continue
        if subname.length == 31
          console.warn "Warning: Sheet '#{subname}' has length exactly 31, which may be caused by Google Sheets export truncation"
        rows = xlsx.utils.sheet_to_json sheet,
          header: 1
          defval: ''
        rows.subname = subname
        rows
    )

class DummyInput extends Input
  parse: ->

class SVGFile extends DummyInput
  @title: "SVG file (convert to PDF/PNG without any tiling)"
  @skipRead: true  # svgink/Inkscape will do actual file reading

class Render extends HasSettings
  constructor: (@drawing, @settings) ->
    super()
    @settings ?= @drawing.settings
    @idVersions = new Map
    @mappings = Mappings.from @getSetting 'mappings'
    @styles = Styles.from @getSetting 'styles'
  hrefAttr: -> hrefAttr @settings
  id: (key) ->
    ## Generate unique ID starting with an escaped version of `key`.
    ## If necessary, appends _v0, _v1, _v2, etc. to make unique.
    escaped = escapeId key
    version = @idVersions.get(key) ? 0
    @idVersions.set key, version + 1
    if version
      "#{escaped}_v#{version}"
    else
      escaped
  makeDOM: ->
    ###
    Main rendering engine, returning an xmldom object for the whole document.
    Also saves the table of tiles in `@tiles`, the corresponding
    coordinates in `@coords`, and overall `@width` and `@height`,
    for use by `makeTeX`.
    ###
    @dom = domImplementation.createDocument SVGNS, 'svg'
    svg = @dom.documentElement
    svg.setAttribute 'xmlns:xlink', XLINKNS unless @getSetting 'useHref'
    svg.setAttribute 'version', '1.1'
    #svg.appendChild defs = @dom.createElementNS SVGNS, 'defs'
    ## <style> tags for CSS
    for style in @styles
      svg.appendChild styleTag = @dom.createElementNS SVGNS, 'style'
      styleTag.textContent = style.css
    ## Render all tiles in the drawing.
    @mappings.doBeforeRender @
    missing = new Set
    cache = new Map
    symbolIds = new Set
    context = new Context @
    @tiles =
      for row, i in @drawing.keys
        for key, j in row
          context.move j, i
          tile = @mappings.lookup key, context
          unless tile?
            missing.add key
            tile = unrecognizedTile
          ## Check cache by tile value if it's a string (e.g. filename,
          ## to avoid loading file again), and by computed SVG string
          ## (in case multiple paths lead to the same SVG content).
          if typeof tile.value == 'string' and
              (found = cache.get tile.value)?
            tile = found
          else
            tile.makeSVG()
            unless tile.value == tile.svg
              if (found = cache.get tile.svg)?
                tile = found
              else
                cache.set tile.svg, tile
            cache.set tile.value, tile
          ## Include new <symbol> in SVG
          unless found?
            tile.setId @id key unless tile.id?  # unrecognizedTile has id
            dom = tile.makeDOM().documentElement
            ## Clone if tile is static, to enable later re-use
            dom = dom.cloneNode true if tile.isStatic
            svg.appendChild dom
            if symbolIds.has tile.id
              console.warn "Multiple symbols with id '#{tile.id}': This shouldn't happen, and SVG likely won't load correctly."
            else
              symbolIds.add tile.id
          tile
    missing = ("'#{key}'" for key from missing)
    if missing.length
      console.warn "Failed to recognize tiles:", missing.join ', '
    ## Factor out duplicate inline <image>s into separate <symbol>s.
    inlineImages = new Map
    inlineImageVersions = new Map
    domRecurse svg, (node, parent) =>
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
      parent.replaceChild (use = @dom.createElementNS SVGNS, 'use'), node
      for attr in ['x', 'y', 'width', 'height']
        use.setAttribute attr, node.getAttribute attr if node.hasAttribute attr
        node.removeAttribute attr
      # Memoize versions
      attributes =
        for attr in node.attributes
          "#{attr.name}=#{attr.value}"
      attributes.sort()
      attributes = attributes.join ' '
      unless (id = inlineImages.get attributes)?
        version = inlineImageVersions.get(filename) ? 0
        inlineImageVersions.set filename, version + 1
        id = "_image_#{escapeId filename}_v#{version}"
        inlineImages.set attributes, id
        svg.appendChild symbol = @dom.createElementNS SVGNS, 'symbol'
        symbol.setAttribute 'id', id
        # If we don't have width/height set from data-width/height fields,
        # we take the first used width/height as the defining height.
        node.setAttribute 'width', width or use.getAttribute 'width'
        node.setAttribute 'height', height or use.getAttribute 'height'
        symbol.setAttribute 'viewBox', "0 0 #{width} #{height}"
        symbol.appendChild node
      use.setAttribute @hrefAttr(), '#' + id
      false
    ## Lay out the symbols in the drawing via SVG <use>.
    @xMin = @yMin = @xMax = @yMax = 0
    @layers = {}
    y = 0
    colWidths = {}
    @coords = []
    for row, i in @tiles
      @coords.push coordsRow = []
      rowHeight = 0
      for tile in row when not tile.autoHeight
        if tile.height > rowHeight
          rowHeight = tile.height
      x = 0
      for tile, j in row
        coordsRow.push {x, y}
        continue unless tile?
        @layers[tile.zIndex] ?= []
        @layers[tile.zIndex].push use = @dom.createElementNS SVGNS, 'use'
        use.setAttribute @hrefAttr(), '#' + tile.id
        use.setAttribute 'x', x
        use.setAttribute 'y', y
        scaleX = scaleY = 1
        if tile.autoWidth
          colWidths[j] ?= Math.max 0, ...(
            for row2 in @tiles when row2[j]? and not row2[j].autoWidth
              row2[j].width
          )
          scaleX = colWidths[j] / tile.width unless tile.width == 0
          scaleY = scaleX unless tile.autoHeight
        if tile.autoHeight
          scaleY = rowHeight / tile.height unless tile.height == 0
          scaleX = scaleY unless tile.autoWidth
        ## Scaling of tile is relative to viewBox, so use that to define
        ## width and height attributes:
        use.setAttribute 'width',
          (tile.viewBox?[2] ? tile.width) * scaleX
        use.setAttribute 'height',
          (tile.viewBox?[3] ? tile.height) * scaleY
        if tile.overflowBox?
          dx = (tile.overflowBox[0] - tile.viewBox[0]) * scaleX
          dy = (tile.overflowBox[1] - tile.viewBox[1]) * scaleY
          @xMin = Math.min @xMin, x + dx
          @yMin = Math.min @yMin, y + dy
          @xMax = Math.max @xMax, x + dx + tile.overflowBox[2] * scaleX
          @yMax = Math.max @yMax, y + dy + tile.overflowBox[3] * scaleY
        x += tile.width * scaleX
        @xMax = Math.max @xMax, x
      y += rowHeight
      @yMax = Math.max @yMax, y
    ## afterRender callbacks: render as <symbol> and then strip off that wrapper
    do updateSize = =>
      @width = @xMax - @xMin
      @height = @yMax - @yMin
    @mappings.doAfterRender @, (out) =>
      return unless out
      tile = new Tile '_afterRender', out
      ## Wrap in <svg> instead of <symbol>, with default viewBox of drawing.
      dom = tile.makeDOM 'svg'
      @layers[tile.zIndex] ?= []
      box = tile.overflowBox ? tile.viewBox
      if box?
        @xMin = Math.min @xMin, box[0]
        @yMin = Math.min @yMin, box[1]
        @xMax = Math.max @xMax, box[0] + box[2]
        @yMax = Math.max @yMax, box[1] + box[3]
      updateSize()
      @layers[tile.zIndex].push dom.documentElement
    ## Sort by layer
    layerOrder = (layer for layer of @layers).sort (x, y) -> x-y
    for layer in layerOrder
      for node in @layers[layer]
        svg.appendChild node
    svg.setAttribute 'viewBox', "#{@xMin} #{@yMin} #{@width} #{@height}"
    svg.setAttribute 'width', @width
    svg.setAttribute 'height', @height
    #svg.setAttribute 'preserveAspectRatio', 'xMinYMin meet'
    @dom
  makeSVG: ->
    out = new XMLSerializer().serializeToString @makeDOM()
    ## Parsing xlink:href in user's SVG fragments, and then serializing,
    ## can lead to these null namespace definitions.  Remove.
    out = out.replace /\sxmlns:xlink=""/g, ''
    if prettyXML?
      out = prettyXML out,
        newline: '\n'  ## force consistent line endings, not require('os').EOL
    '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">

''' + out
  makeTeX: (filename, relativeDir) ->
    @makeDOM() unless @tiles?
    filename = path.parse filename
    basename = filename.base[...-filename.ext.length]
    if relativeDir
      relativeDir += '/'
      ## TeX uses forward slashes for path separators
      if require('process').platform == 'win32'
        relativeDir = relativeDir.replace /\\/g, '/'
    ## LaTeX based loosely on Inkscape's PDF/EPS/PS + LaTeX output extension.
    ## See http://tug.ctan.org/tex-archive/info/svg-inkscape/
    lines = ["""
      %% Creator: svgtiler, https://github.com/edemaine/svgtiler
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
          \\put(0,0){\\includegraphics[width=#{@width}\\unitlength]{\\currfiledir #{relativeDir ? ''}#{basename}}}%
    """]
    for row, i in @tiles
      for tile, j in row
        {x, y} = @coords[i][j]
        for text in tile.text
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
  writeSVG: (filename) ->
    ## Generates SVG and writes to filename.
    ## Default filename is the input filename with extension replaced by .svg.
    ## Returns generated .svg filename (even if it didn't changed).
    filename ?= @drawing.generateFilename '.svg'
    unless @shouldGenerate filename, @mappings, @styles
      console.log '->', filename, '(SKIPPED)'
    else if maybeWrite filename, @makeSVG()
      console.log '->', filename
    else
      console.log '->', filename, '(UNCHANGED)'
    filename
  writeTeX: (filename, relativeDir) ->
    ###
    Default filename is the input filename with extension replaced by .svg_tex
    (analogous to .pdf_tex from Inkscape's --export-latex feature, but noting
    that the text is extracted from the SVG not the PDF, and that this file
    works with both .pdf and .png auxiliary files).
    ###
    filename ?= @drawing.generateFilename '.svg_tex'
    relativeDir ?= path.relative path.parse(filename).dir,
      @getOutputDir('.pdf') ? @getOutputDir('.png') ?
      @getOutputDir('.svg')
    unless @shouldGenerate filename, @mappings
      console.log '->', filename, '(SKIPPED)'
    else if maybeWrite filename, @makeTeX filename, relativeDir
      console.log ' &', filename
    else
      console.log ' &', filename, '(UNCHANGED)'
    filename
  shouldGenerate: (filename, ...depGroups) ->
    return true if @getSetting 'force'
    try
      modified = (fs.statSync filename).mtimeMs
    ## If file doesn't exist or can't be stat, need to generate it.
    return true unless modified?
    ## If SVG Tiler is newer than file, need to generate it.
    return true if metadata.modified? and metadata.modified > modified
    ## If drawing is newer than file, need to generate it.
    return true if @drawing.modified? and @drawing.modified > modified
    ## If dependency is newer than file, need to generate it.
    for depGroup in depGroups
      ## `depGroup` may be a `Mappings` or `Styles` object
      ## (which both implement array interface).
      for dep in depGroup
        return true if dep.modified? and dep.modified > modified
    false

class Context
  constructor: (@render, i, j) ->
    @drawing = @render.drawing
    ## Use @drawing to access these old properties:
    #@keys = @drawing.keys
    #@filename = @drawing.filename
    #@subname = @drawing.subname
    @move j, i if i? and j?
  move: (@j, @i) ->
    ## Change location in-place
    @key = @drawing.keys[@i]?[@j]
  at: (j, i) ->
    if i < 0
      i += @drawing.keys.length
    if j < 0
      j += @drawing.keys[i]?.length ? 0
    new Context @render, i, j
  neighbor: (dj, di) ->
    new Context @render, @i + di, @j + dj
  includes: (...args) ->
    @key? and @key.includes ...args
  match: (...args) ->
    @key? and @key.match ...args
  row: (di = 0) ->
    i = @i + di
    for tile, j in @drawing.keys[i] ? []
      new Context @render, i, j
  column: (dj = 0) ->
    j = @j + dj
    for row, i in @drawing.keys
      new Context @render, i, j
Object.defineProperties Context.prototype,
  filename: get: -> @drawing.filename
  subname: get: -> @drawing.subname

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
  '.styl': StylusStyle
  # Other
  '.svg': SVGFile

renderDOM = (elts, settings) ->
  if typeof elts == 'string'
    elts = document.querySelectorAll elts
  else if elts instanceof HTMLElement
    elts = [elts]

  for elt from elts
    ## Default to href attribute which works better in DOM.
    eltSettings = {...defaultSettings, useHref: true, ...settings}
    ## Override settings via data-* attributes.
    for key, value of elt.dataset
      continue unless eltSettings.hasOwnProperty key
      if typeof eltSettings[key] == 'boolean'
        switch value = setting key
          #when 'true', 'on', 'yes'
          #  eltSettings[key] = true
          when 'false', 'off', 'no'#, ''
            eltSettings[key] = false
          else
            eltSettings[key] = Boolean value
      else
        eltSettings[key] = value

    try
      elt.style.whiteSpace = 'pre'
      filename = eltSettings.filename
      drawing = Input.recognize filename, elt.innerText, eltSettings
      if drawing instanceof Drawing
        dom = drawing.renderDOM().documentElement
        if eltSettings.keepParent
          elt.innerHTML = ''
          elt.appendChild dom
        else
          elt.replaceWith dom
          if eltSettings.keepClass
            dom.setAttribute 'class', elt.className
      else
        console.warn "Parsed element with filename '#{filename}' into #{drawing.constructor.name} instead of Drawing:", elt
        dom = null
      input: elt
      output: dom
      drawing: drawing
      filename: filename
    catch err
      console.error 'svgtiler.renderDOM failed to render element:', elt
      console.error err

help = ->
  console.log """
svgtiler #{metadata.version}
Usage: #{process.argv[1]} (...options and filenames...)
Documentation: https://github.com/edemaine/svgtiler

Optional arguments:
  -h / --help           Show this help message and exit.
  -p / --pdf            Convert output SVG files to PDF via Inkscape
  -P / --png            Convert output SVG files to PNG via Inkscape
  -t / --tex            Move <text> from SVG to accompanying LaTeX file.svg_tex
  -f / --force          Force SVG/TeX/PDF/PNG creation even if deps older
  -o DIR / --output DIR Write all output files to directory DIR
  --os DIR / --output-svg DIR   Write all .svg files to directory DIR
  --op DIR / --output-pdf DIR   Write all .pdf files to directory DIR
  --oP DIR / --output-png DIR   Write all .png files to directory DIR
  --ot DIR / --output-tex DIR   Write all .svg_tex files to directory DIR
  -i PATH / --inkscape PATH     Specify PATH to Inkscape binary
  -j N / --jobs N       Run up to N Inkscape jobs in parallel
  -m / --margin         Don't delete blank extreme rows/columns
  --hidden              Process hidden sheets within spreadsheet files
  --tw TILE_WIDTH / --tile-width TILE_WIDTH
                        Force all tiles to have specified width
  --th TILE_HEIGHT / --tile-height TILE_HEIGHT
                        Force all tiles to have specified height
  --no-inline           Don't inline <image>s into output SVG
  --no-overflow         Don't default <symbol> overflow to "visible"
  --no-sanitize         Don't sanitize PDF output by blanking out /CreationDate

Filename arguments:  (mappings and styles before relevant drawings!)

"""
  for extension, klass of extensionMap
    if extension.length < 10
      extension += ' '.repeat 10 - extension.length
    console.log "  *#{extension}  #{klass.title}"
    console.log "               #{klass.help}" if klass.help?
  console.log """

TILE specifiers:  (omit the quotes in anything except .js and .coffee files)

  'filename.svg':   load SVG from specified file
  'filename.png':   include PNG image from specified file
  'filename.jpg':   include JPEG image from specified file
  '<svg>...</svg>' or '<symbol>...</symbol>': raw SVG string
  <svg>...</svg> or <symbol>...</symbol>: SVG in JSX notation
  -> ...@key...:    function computing SVG, with `this` bound to Context with
                    `key` (tile name), `i` and `j` (y and x coordinates),
                    `filename` (drawing filename), `subname` (subsheet name),
                    and supporting `neighbor`/`includes`/`row`/`column` methods
"""
  #object with one or more attributes
  process.exit()

processor = null
convert = (filenames, formats, settings) ->
  return unless formats.length
  unless processor?
    svgink = require 'svgink'
    settings = {...svgink.defaultSettings, ...settings}
    processor = new svgink.SVGProcessor settings
    .on 'converted', (data) =>
      console.log "   #{data.input} -> #{data.output}" +
                  (if data.skip then ' (SKIPPED)' else '')
      console.log data.stdout if data.stdout
      console.log data.stderr if data.stderr
    .on 'error', (error) =>
      if error.input?
        console.log "!! #{error.input} -> #{error.output} FAILED"
      else
        console.log "!! svgink conversion error"
      console.log error
  if Array.isArray filenames
    for filename in filenames
      processor.convertTo filename, formats
  else
    processor.convertTo filenames, formats

main = (args = process.argv[2..]) ->
  files = skip = 0
  formats = []
  settings = {
    ...defaultSettings
    mappings: new Mappings
    styles: new Styles
  }
  for arg, i in args
    if skip
      skip--
      continue
    switch arg
      when '-h', '--help'
        help()
      when '-f', '--force'
        settings.force = true
      when '-m', '--margin'
        settings.keepMargins = true
      when '--hidden'
        settings.keepHidden = true
      when '--tw', '--tile-width'
        skip = 1
        arg = parseFloat args[i+1]
        if arg
          settings.forceWidth = arg
        else
          console.warn "Invalid argument to --tile-width: #{args[i+1]}"
      when '--th', '--tile-height'
        skip = 1
        arg = parseFloat args[i+1]
        if arg
          settings.forceHeight = arg
        else
          console.warn "Invalid argument to --tile-height: #{args[i+1]}"
      when '-o', '--output'
        skip = 1
        settings.outputDir = args[i+1]
      when '--os', '--output-svg'
        skip = 1
        settings.outputDirExt['.svg'] = args[i+1]
      when '--op', '--output-pdf'
        skip = 1
        settings.outputDirExt['.pdf'] = args[i+1]
      when '--oP', '--output-png'
        skip = 1
        settings.outputDirExt['.png'] = args[i+1]
      when '--ot', '--output-tex'
        skip = 1
        settings.outputDirExt['.svg_tex'] = args[i+1]
      when '-i', '--inkscape'
        skip = 1
        settings.inkscape = args[i+1]
      when '-p', '--pdf'
        formats.push 'pdf'
      when '-P', '--png'
        formats.push 'png'
      when '-t', '--tex'
        settings.texText = true
      when '--no-sanitize'
        settings.sanitize = false
      when '--no-overflow'
        settings.overflowDefault = null  # no default
      when '--no-inline'
        settings.inlineImages = false
      when '-j', '--jobs'
        skip = 1
        arg = parseInt args[i+1], 10
        if arg
          settings.jobs = arg
        else
          console.warn "Invalid argument to --jobs: #{args[i+1]}"
      else
        files++
        console.log '*', arg
        input = Input.recognize arg, undefined, settings
        if input instanceof Mapping
          settings.mappings.push input
        else if input instanceof Style
          settings.styles.push input
        else if input instanceof Drawing or input instanceof Drawings
          filenames = input.render settings
          ## Convert to any additional formats.  Even if SVG files didn't
          ## change, we may not have done these conversions before or in the
          ## last run of SVG Tiler, so let svgink compare mod times and decide.
          convert filenames, formats, settings
        else if input instanceof SVGFile
          convert input.filename, formats, settings
  unless files
    console.log 'Not enough filename arguments'
    help()

svgtiler = {
  Tile, unrecognizedTile,
  Mapping, ASCIIMapping, JSMapping, CoffeeMapping,
  getMapping, runWithMapping,
  Drawing, AutoDrawing, ASCIIDrawing,
  DSVDrawing, SSVDrawing, CSVDrawing, TSVDrawing,
  Drawings, XLSXDrawings,
  Style, CSSStyle, StylusStyle,
  SVGFile,
  extensionMap, Input, DummyInput, ArrayWrapper, Mappings,
  Render, Context,
  beforeRender, afterRender,
  SVGTilerError, SVGNS, XLINKNS, escapeId,
  main, renderDOM, defaultSettings, convert,
  static: wrapStatic,
  share: {}  # for shared data between mapping modules
  version: metadata.version
}
module?.exports = svgtiler
window?.svgtiler = svgtiler

if module? and require?.main == module and not window?
  paths = [
    ## Enable require('svgtiler') (as autoimported by `svgtiler` access)
    ## to load this module (needed if the module is installed globally).
    path.join __dirname, '..', '..'
    ## Enable require('preact') (as autoimported by `preact` access)
    ## to load SVG Tiler's copy of preact.
    path.join __dirname, '..', 'node_modules'
  ]
  paths.push process.env.NODE_PATH if process.env.NODE_PATH
  process.env.NODE_PATH = paths.join (
    if require('process').platform == 'win32'
      ';'
    else
      ':'
  )
  require('module').Module._initPaths()

  main()
