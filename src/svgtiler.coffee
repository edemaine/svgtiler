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
  ###
  Babel plugin to add implicit `export default` to last line of program,
  to simulate the effect of `eval` but in a module context.
  Only added if there isn't already an `export default` or `exports.default`
  in the code, and when the last line is an object, array, or function
  expression (with the idea that it wouldn't do much by itself).
  ###
  implicitFinalExportDefault = ({types}) ->
    visitor:
      Program: (path) ->
        body = path.get 'body'
        return unless body.length  # empty program
        ## Check for existing `export default` or `exports.default` or
        ## `exports['default']`, in which case definitely don't add one.
        exportedDefault = false
        path.traverse(
          ExportDefaultDeclaration: (path) ->
            exportedDefault = true
            return
          MemberExpression: (path) ->
            {node} = path
            check = (key, value) ->
              types.isIdentifier(node.object) and
              node.object.name == key and (
                (types.isIdentifier(node.property) and
                 node.property.name == value) or
                (types.isStringLiteral(node.property) and
                 node.property.value == value)
              )
            exportedDefault or= check('exports', 'default') or
                                check('module', 'exports')
            return
        )
        return if exportedDefault
        last = body[body.length-1]
        lastNode = last.node
        if types.isExpressionStatement(last) and (
          types.isObjectExpression(lastNode.expression) or
          types.isFunctionExpression(lastNode.expression) or
          types.isArrowFunctionExpression(lastNode.expression) or
          types.isArrayExpression(lastNode.expression)
          # not AssignmentExpression or CallExpression
        )
          exportLast = types.exportDefaultDeclaration lastNode.expression
          exportLast.leadingComments = lastNode.leadingComments
          exportLast.innerComments = lastNode.innerComments
          exportLast.trailingComments = lastNode.trailingComments
          last.replaceWith exportLast
        return

  ## Modify `svgtiler.require` calls to add __dirname as third argument,
  ## so that files can be located relative to the module's directory.
  svgtilerRequire = ({types}) ->
    visitor:
      CallExpression: (path) ->
        {node} = path
        {callee} = node
        return unless types.isMemberExpression callee
        return unless types.isIdentifier(callee.object) and
                      callee.object.name == 'svgtiler'
        return unless types.isIdentifier(callee.property) and
                      callee.property.name == 'require'
        while node.arguments.length < 2
          node.arguments.push types.identifier 'undefined'
        if node.arguments.length == 2
          node.arguments.push types.identifier '__dirname'
        return

  babelConfig =
    plugins: [
      implicitFinalExportDefault
      svgtilerRequire
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

  ## Prevent Babel from caching its results, for changes to our plugins.
  require('@babel/register') {...babelConfig, cache: false}

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
  ## Don't make all rows have the same number of columns by padding with
  ## empty strings.
  keepUneven: false
  ## Override for output file's stem (basename without extension).
  ## Can use `*` to refer to input file's stem, to add prefix or suffix.
  outputStem: null
  ## Directories to output all or some files.
  ## Can also include stem overrides like "prefix_*_suffix".
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
  ## Background rectangle fill color.
  background: null
  ## Glob pattern for Maketiles.
  maketile: '[mM]aketile.{args,coffee,js}'
  ## renderDOM-specific
  filename: 'drawing.asc'  # default filename when not otherwise specified
  keepParent: false
  keepClass: false
  ## Major state
  mappings: null  # should be valid argument to new Mappings
  styles: null    # should be valid argument to new Styles

cloneSettings = (settings, addArrays) ->
  settings = {...settings}
  if settings.mappings?
    settings.mappings = new Mappings settings.mappings
  else if addArrays
    settings.mappings = new Mappings
  if settings.styles?
    settings.styles = new Styles settings.styles
  else if addArrays
    settings.styles = new Styles
  settings
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

globalShare = {}  # for shared data between mapping modules

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

parseNum = (x) ->
  parsed = parseFloat x
  if isNaN parsed
    null
  else
    parsed

## Allow Infinity, \infty, Inf with optional sign prefix
infinityRegExp = /^\s*([+-]?)\\?infi?n?i?t?y?\s*$/i
parseNumOrInfinity = (x) ->
  if (match = infinityRegExp.exec x)?
    if match[1] == '-'
      -Infinity
    else
      Infinity
  else
    parseNum x

## Conversion from arbitrary unit to px (SVG units),
## from https://www.w3.org/TR/css-values-3/#absolute-lengths
units =
  cm: 96 / 2.54
  mm: 96 / 25.4
  Q: 96 / 25.4 / 4
  in: 96
  pc: 96 / 6
  pt: 96 / 72
  px: 1
  undefined: 1

parseDim = (x) ->
  match = /^\s*([0-9.]+)\s*([a-zA-Z]\w+)?\s*$/.exec x
  return null unless match?
  if units.hasOwnProperty match[2]
    parseNum(match[1]) * units[match[2]]
  else
    console.warn "Unrecognized unit #{match[2]}"
    parseNum match[1]

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

svgBBox = (dom) ->
  ## xxx Many unsupported features!
  ##   - transformations
  ##   - used symbols/defs
  ##   - paths
  ##   - text
  ##   - line widths which extend bounding box
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
        xMin = Math.min x1, x2
        yMin = Math.min y1, y2
        [xMin, yMin, Math.max(x1, x2) - xMin, Math.max(y1, y2) - yMin]
      when 'polyline', 'polygon'
        points = for point in node.getAttribute('points').trim().split /\s+/
                    for coord in point.split /,/
                      parseFloat coord
        xs = (point[0] for point in points)
        ys = (point[1] for point in points)
        xMin = Math.min ...xs
        yMin = Math.min ...ys
        if isNaN(xMin) or isNaN(yMin) # invalid points attribute; don't render
          null
        else
          [xMin, yMin, Math.max(...xs) - xMin, Math.max(...ys) - yMin]
      else
        viewBoxes = (recurse(child) for child in node.childNodes)
        viewBoxes = (viewBox for viewBox in viewBoxes when viewBox?)
        xMin = Math.min ...(viewBox[0] for viewBox in viewBoxes)
        yMin = Math.min ...(viewBox[1] for viewBox in viewBoxes)
        xMax = Math.max ...(viewBox[0]+viewBox[2] for viewBox in viewBoxes)
        yMax = Math.max ...(viewBox[1]+viewBox[3] for viewBox in viewBoxes)
        [xMin, yMin, xMax - xMin, yMax - yMin]
  viewBox = recurse dom.documentElement
  if not viewBox? or Infinity in viewBox or -Infinity in viewBox
    null
  else
    viewBox

isAuto = (value) ->
  typeof value == 'string' and /^\s*auto\s*$/i.test value

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
  ## Special values of Infinity or -Infinity are allowed.
  ## Also remove z-index attribute, so output is valid SVG.
  ## Note that z-index must be an integer.
  ## 1. https://www.w3.org/Graphics/SVG/WG/wiki/Proposals/z-index suggests
  ## a z-index="..." attribute.  Check for this first.
  ## 2. Look for style="z-index:..." as in HTML.
  z = parseNumOrInfinity attributeOrStyle node, 'z-index'
  removeAttributeOrStyle node, 'z-index'
  z ? 0

domRecurse = (node, callback) ->
  ###
  Recurse through DOM starting at `node`, calling `callback(node)`
  on every recursive node, including `node` itself.
  `callback()` should return a true value if you want to recurse into
  the specified node's children (typically, when there isn't a match).
  Robust against node being replaced.
  ###
  return unless callback node
  return unless node.hasChildNodes()
  child = node.lastChild
  while child?
    nextChild = child.previousSibling
    domRecurse child, callback
    child = nextChild
  return

refRegExp = ///
  # url() without quotes
  \b url \s* \( \s* \# ([^()]*) \)
  # url() with quotes, or src() which requires quotes
| \b (?: url | src) \s* \( \s* (['"]) \s* \# ([^'"]*) \2 \s* \)
///g
findRefs = (root) =>
  ## Returns an array of id-based references to other elements in the SVG.
  refs = []
  domRecurse root, (node) =>
    return unless node.attributes?
    for attr in node.attributes
      if attr.name in ['href', 'xlink:href'] and
              (value = attr.value.trim()).startsWith '#'
        refs.push {id: value[1..].trim(), node, attr: attr.name}
      else
        while (match = refRegExp.exec attr.value)?
          refs.push {id: (match[1] or match[3]).trim(), node, attr: attr.name}
    true
  refs

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

currentMapping = null
currentRender = null
currentContext = null

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

getRender = ->
  ## Returns current `Mapping` object,
  ## when used at top level of a JS/CS mapping file.
  currentRender
runWithRender = (render, fn) ->
  ## Runs the specified function `fn` as if it were called
  ## from the specified `render`.
  oldRender = currentRender
  currentRender = render
  try
    fn()
  finally
    currentRender = oldRender

getContext = ->
  ## Returns current `Context` object, when used within a mapping function.
  currentContext
runWithContext = (context, fn) ->
  ## Runs the specified function `fn` as if it were called
  ## within the specified `context`.
  oldContext = currentContext
  currentContext = context
  try
    fn()
  finally
    currentContext = oldContext

getContextString = ->
  ## Returns string describing the current context
  if currentContext?
    "tile '#{currentContext.tile}' in row #{currentContext.i+1}, column #{currentContext.j+1} of drawing '#{currentContext.drawing.filename}'"
  else if currentMapping?
    "mapping '#{currentMapping.filename}'"
  else if currentRender?
    "render of '#{currentRender.drawing.filename}'"
  else
    'unknown context'

getSettings = ->
  ###
  Returns currently active `Settings` object, if any, from the current Render
  process (which includes the case of an active Context) or the current Mapping.
  Returns `null` if neither is currently active.
  ###
  #if currentContext?
  #  currentContext.render.settings
  if currentRender?
    currentRender.settings
  else if currentMapping?
    currentMapping.settings
  else
    null

## SVG container element tags from
## https://developer.mozilla.org/en-US/docs/Web/SVG/Element#container_elements
## that are useless when empty and have no `id` attribute.
emptyContainers = new Set [
  'defs'
  'g'
  'svg'
  'switch'
  'symbol'
]

class SVGContent extends HasSettings
  ###
  Base helper for parsing SVG as specified in SVG Tiler:
  SVG strings, Preact VDOM, or filenames, with special handling of image files.
  Automatically determines `width`, `height`, `viewBox`, `overflowBox`,
  and `zIndex` properties if specified in the SVG content,
  and sets `isEmpty` to indicate whether the SVG is a useless empty tag.
  In many cases (symbols and defs), acquires an `id` property via `setId`,
  which can be formatted via `url()` and `hash()`.
  In some cases, acquires `isStatic` Boolean property to indicate
  re-usable content, or `isForced` Boolean property to indicate
  a def that should be included by force (even if unused).
  ###
  constructor: (@name, @value, @settings) ->
    ## `@value` can be a string (SVG or filename) or Preact VDOM.
    super()
  url: ->
    "url(##{@id})"
  hash: ->
    "##{@id}"
  force: (value = true) ->
    @isForced = value
    @  # allow chaining

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
            throw new SVGTilerError "Unrecognized extension in filename '#{@value}' for #{@name}"
      else
        @svg = @value
    else
      throw new SVGTilerError "Invalid value for #{@name}: #{typeof @value}"
    ## Remove initial SVG/XML comments (for broader duplication detection,
    ## and the next replace rule).
    @svg = removeSVGComments @svg

  setId: (@id) ->
    ## Can be called before or after makeDOM, updating DOM in latter case.
    @dom.documentElement.setAttribute 'id', @id if @dom?
  defaultId: (base = 'id') ->
    ###
    Generate a "default" id (typically for use in def) using these rules:
    1. If the root element has an `id` attribute, use that (manual spec).
    2. Use the root element's tag name, if any
    3. Fallback to use first argument `base`, which defaults to `"id"`.
    The returned id is not yet escaped; you should pass it to `escapeId`.
    ###
    doc = @makeDOM().documentElement
    doc.getAttribute('id') or doc.tagName or base
  makeDOM: ->
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
        console.error "SVG parse #{level} in #{@name}: #{msg}"
    .parseFromString svg, 'image/svg+xml'
    ## Remove from the symbol any top-level xmlns=SVGNS or xmlns:xlink,
    ## in the original parsed content or possibly added above,
    ## to avoid conflict with these attributes in the top-level <svg>.
    @dom.documentElement.removeAttribute 'xmlns'
    unless @getSetting 'useHref'
      @dom.documentElement.removeAttribute 'xmlns:xlink'

    ## Wrap in <symbol> if appropriate,
    ## before we add width/height/etc. attributes.
    @wrap?()

    ## <image> processing (must come before width/height processing).
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

    ## Determine `viewBox`, `width`, and `height` attributes.
    @viewBox = parseBox @dom.documentElement.getAttribute 'viewBox'
    @width = parseDim @origWidth = @dom.documentElement.getAttribute 'width'
    @height = parseDim @origHeight = @dom.documentElement.getAttribute 'height'
    ## Check for default width/height specified by caller.
    if not @width? and @defaultWidth?
      @dom.documentElement.setAttribute 'width', @width = @defaultWidth
    if not @height? and @defaultHeight?
      @dom.documentElement.setAttribute 'height', @height = @defaultHeight
    ## Absent viewBox becomes 0 0 <width> <height> if latter are present
    ## (but only internal to SVG Tiler, DOM remains unchanged).
    if @width? and @height? and not @viewBox?
      @viewBox = [0, 0, @width, @height]
    ## Absent viewBox set to automatic bounding box if requested
    ## (e.g. in `SVGSymbol`).
    if not @viewBox? and @autoViewBox
      if (@viewBox = svgBBox @dom)?
        @dom.documentElement.setAttribute 'viewBox', @viewBox.join ' '
    ## Absent width/height inherited from viewBox if latter is present,
    ## in `SVGSymbol` which sets `@autoWidthHeight`.
    ## Including the width/height in the <symbol> lets us skip it in <use>.
    if @viewBox? and @autoWidthHeight
      unless @width?
        @dom.documentElement.setAttribute 'width', @width = @viewBox[2]
      unless @height?
        @dom.documentElement.setAttribute 'height', @height = @viewBox[3]

    ## Overflow behavior
    overflow = attributeOrStyle @dom.documentElement, 'overflow'
    if not overflow? and @defaultOverflow?
      @dom.documentElement.setAttribute 'overflow', overflow = @defaultOverflow
    @overflowVisible = (overflow? and /^\s*(visible|scroll)\b/.test overflow)

    ###
    SVG's `viewBox`, `width`, and `height` attributes have a special rule that
    "A value of zero disables rendering of the element."
    [https://www.w3.org/TR/SVG11/coords.html#ViewBoxAttribute]
    [https://www.w3.org/TR/SVG11/struct.html#SVGElementWidthAttribute]
    Avoid this if overflow is visible.
    ###
    if @overflowVisible
      if @width == 0
        @dom.documentElement.setAttribute 'width', zeroSizeReplacement
      if @height == 0
        @dom.documentElement.setAttribute 'height', zeroSizeReplacement
      if @viewBox? and (@viewBox[2] == 0 or @viewBox[3] == 0)
        @viewBox[2] = zeroSizeReplacement if @viewBox[2] == 0
        @viewBox[3] = zeroSizeReplacement if @viewBox[3] == 0
        @dom.documentElement.setAttribute 'viewBox', @viewBox.join ' '

    ## Special SVG Tiler attributes that get extracted from DOM
    @overflowBox = extractOverflowBox @dom
    @zIndex = extractZIndex @dom.documentElement
    #@isEmpty = @dom.documentElement.childNodes.length == 0 and
    #  (@emptyWithId or not @dom.documentElement.hasAttribute 'id') and
    #  emptyContainers.has @dom.documentElement.tagName
    recursiveEmpty = (node, allowId) ->
      return false unless emptyContainers.has node.tagName
      return false unless allowId or not node.hasAttribute 'id'
      for child in node.childNodes
        return false unless recursiveEmpty child
      true
    @isEmpty = recursiveEmpty @dom.documentElement, @emptyWithId
    @dom
  useDOM: ->
    @makeDOM()
    ## Clone if content is static, to enable later re-use
    if @isStatic
      @dom.documentElement.cloneNode true
    else
      @dom.documentElement

class SVGWrapped extends SVGContent
  ###
  Abstract base class for `SVGSymbol` and `SVGSVG` which automatically wrap
  content in a containing element (`<symbol>` or `<svg>` respectively).
  Subclass should define `wrapper` of 'symbol' or 'svg'.
  Parser will enforce that the content is wrapped in this element.
  ###
  wrap: ->
    ## Wrap XML in <wrapper>.
    symbol = @dom.createElementNS SVGNS, @wrapper
    ## Force `id` to be first attribute (if it's already set).
    symbol.setAttribute 'id', @id if @id?
    ## Avoid a layer of indirection for <symbol>/<svg> at top level
    if @dom.documentElement.nodeName in ['symbol', 'svg'] and
       not @dom.documentElement.nextSibling?
      for attribute in @dom.documentElement.attributes
        unless attribute.name in ['version', 'id'] or attribute.name.startsWith 'xmlns'
          symbol.setAttribute attribute.name, attribute.value
      @dom.removeChild doc = @dom.documentElement
    else
      doc = @dom
      ## Allow top-level object to specify <symbol> data.
      ## `z-index` and `overflowBox` should already be extracted.
      ## `width` and `height` have another meaning in e.g. <rect>s,
      ## so just transfer for tags where they are meaningless.
      for attribute in ['viewBox', 'width', 'height', 'overflow']
        continue if attribute in ['width', 'height'] and
                    doc.documentElement.tagName not in ['g']
        if doc.documentElement.hasAttribute attribute
          symbol.setAttribute attribute,
            doc.documentElement.getAttribute attribute
          doc.documentElement.removeAttribute attribute
    for child in (node for node in doc.childNodes)
      symbol.appendChild child
    @dom.appendChild symbol
    @dom

#class SVGSVG extends SVGWrapped
#  ###
#  SVG content wrapped in `<svg>`.
#  ###
#  wrapper: 'svg'

class SVGSymbol extends SVGWrapped
  ###
  SVG content wrapped in `<symbol>`, with special width/height handling
  and text extraction, used for tiles.
  Note though that one `SVGSymbol` may be re-used in many different `Tile`s.
  ###
  wrapper: 'symbol'
  autoViewBox: true
  autoWidthHeight: true
  emptyWithId: true  # consider empty even if <symbol> has id attribute
  makeDOM: ->
    return @dom if @dom?

    ## Special defaults for loading symbols in `SVGContent`'s `makeDOM`.
    @defaultWidth = @getSetting 'forceWidth'
    @defaultHeight = @getSetting 'forceHeight'
    @defaultOverflow = @getSetting 'overflowDefault'

    ## `SVGTop` sets `@width` and `@height` according to
    ## `width`/`height`/`viewBox` attributes or our defaults.
    super()

    ## Detect special `width="auto"` and/or `height="auto"` fields for future
    ## processing, and remove them to ensure valid SVG.
    @autoWidth = isAuto @origWidth
    @autoHeight = isAuto @origHeight

    ## Remove `width="auto"` and `height="auto"` attributes
    ## (or whatever `SVGTop` set them to).
    @dom.documentElement.removeAttribute 'width' if @autoWidth
    @dom.documentElement.removeAttribute 'height' if @autoHeight

    ## Warning for missing width/height.
    warnings = []
    unless @width?
      warnings.push 'width'
      @width = 0
    unless @height?
      warnings.push 'height'
      @height = 0
    if warnings.length > 0
      console.warn "Failed to detect #{warnings.join ' and '} of SVG for #{@name}"

    ## Optionally extract <text> nodes for LaTeX output
    if @getSetting 'texText'
      @text = []
      domRecurse @dom.documentElement, (node, parent) =>
        if node.nodeName == 'text'
          @text.push node
          node.parentNode.removeChild node
          false # don't recurse into <text>'s children
        else
          true
    @dom

## Tile to fall back to when encountering an unrecognized key.
## Path from https://commons.wikimedia.org/wiki/File:Replacement_character.svg
## by Amit6, released into the public domain.
unrecognizedSymbol = new SVGSymbol 'unrecognized tile', '''
  <symbol viewBox="0 0 200 200" preserveAspectRatio="none" width="auto" height="auto">
    <rect width="200" height="200" fill="yellow"/>
    <path stroke="none" fill="red" d="M 200,100 100,200 0,100 100,0 200,100 z M 135.64709,74.70585 q 0,-13.52935 -10.00006,-22.52943 -9.99999,-8.99999 -24.35289,-8.99999 -17.29415,0 -30.117661,5.29409 L 69.05879,69.52938 q 9.764731,-6.23528 21.52944,-6.23528 8.82356,0 14.58824,4.82351 5.76469,4.82351 5.76469,12.70589 0,8.5883 -9.94117,21.70588 -9.94117,13.11766 -9.94117,26.76473 l 17.88236,0 q 0,-6.3529 6.9412,-14.9412 11.76471,-14.58816 12.82351,-16.35289 6.9412,-11.05887 6.9412,-23.29417 z m -22.00003,92.11771 0,-24.70585 -27.29412,0 0,24.70585 27.29412,0 z"/>
  </symbol>
'''
unrecognizedSymbol.id = '_unrecognized' # cannot be output of escapeId()
unrecognizedSymbol.isStatic = true      # need to clone on use

## Tile to fall back to when encountering an error during tile evaluation.
## Path from https://commons.wikimedia.org/wiki/File:Caution_icon_-_Noun_Project_9556_white.svg
## by José Hernandez, SE, released under CC-BY-SA 3.0.
## This symbol is hereby released under the same CC-BY-SA 3.0 license.
errorSymbol = new SVGSymbol 'error tile', '''
  <symbol viewBox="0 0 100 100" preserveAspectRatio="none" width="auto" height="auto">
    <rect width="100" height="100" fill="yellow"/>
    <path stroke="none" fill="red" d="M96.803,83.551L55.418,8.992C52.466,3.67,47.631,3.67,44.675,8.988L3.23,83.555   c-2.957,5.32-0.396,9.672,5.688,9.672h82.19C97.193,93.227,99.756,88.873,96.803,83.551z M55.53,82.439H44.5V71.41h11.03V82.439z    M56.064,38.449l-2.484,26.85h-7.132l-2.484-26.85v-9.894h12.101V38.449z"/>
  </symbol>
'''
errorSymbol.id = '_error'   # cannot be output of escapeId()
errorSymbol.isStatic = true # need to clone on use

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
    if extensionMap.hasOwnProperty (extension = extensionOf filename)
      extensionMap[extension].parseFile filename, filedata, settings
    #else if filenameMap.hasOwnProperty (lower = filename.toLowerCase())
    #  filenameMap[lower].parseFile filename, filedata, settings
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
    delete filename.base  # force generation from filename.name & filename.ext
    if (outputStem = @getSetting 'outputStem')?
      filename.name = outputStem.replace '*', filename.name
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
  constructor: (...items) ->
    ###
    Enforce `items` to be instances of `@itemClass`.
    Supported formats:
      * `ArrayWrapper` (just clone array)
      * `@itemClass` (wrap in singleton)
      * raw data to pass to `new @itemClass`
      * `Array` of `@itemClass`
      * `Array` of raw data to pass to `new @itemClass`
      * `Array` of a mixture
      * `undefined`/`null` (empty)
    ###
    super()
    for item in items
      if item instanceof @constructor
        @push ...item
      else if item instanceof @constructor.itemClass
        @push item
      else
        @push new @constructor.itemClass item

class Styles extends ArrayWrapper
  @itemClass: Style

parseIntoArgs = (text) ->
  ## Parse string into an array of arguments, similar to shells.
  re = ///
    " (?: [^"\\] | \\. )* "  # double-quoted string
  | ' [^']* '?               # single-quoted string: no escape processing
  | \\.                      # escaped character
  | \#.*                     # comment
  | (\s+)                    # top-level whitespace separates args
  | [^"'\\\#\s]+             # everything else
  | .                        # for failed matches like "foo
  ///g
  args = []
  arg = ''
  while (match = re.exec text)?
    chunk = match[0]
    if match[1]  # whitespace
      args.push arg if arg
      arg = ''
    else
      switch chunk[0]
        when '"'
          ## Double-quoted strings escape all glob patterns, and
          ## process argument-specific escapes processed,
          ## leaving rest (e.g. `\*`) for glob processing.
          chunk = chunk[1...-1]
          .replace /\\(["'\-#])/g, '$1'
          .replace /[\*\+\?\!\|\@\(\)\[\]\{\}]/g, '\\$&'
        when "'"
          ## Single-quoted strings escape all backslashes and glob patterns
          ## so they will be treated literally (as in bash).
          chunk = chunk[1...-1]
          .replace /[\\\*\+\?\!\|\@\(\)\[\]\{\}]/g, '\\$&'
        when '\\'
          ## Process escaping specific to argument parsing,
          ## leaving rest (e.g. `\*`) for glob processing.
          chunk = chunk[1] if chunk[1] in ['"', "'", '-', '#']
        when '#'
          continue
      arg += chunk
  args.push arg if arg
  args

class Args extends Input
  ###
  Args list stores in `@args` an array of strings such as "-p" and
  "filename.asc".  It's represented in a file as an ASCII file
  that's parsed like a shell, allowing quoted strings, backslash escapes,
  comments via `#`, and newlines treated like regular whitespace.
  ###
  @title: "Additional command-line arguments parsed like a shell"
  parse: (text) ->
    @args = parseIntoArgs text

class Mapping extends Input
  ###
  Base Mapping class.
  The passed-in data can be any supported output from a JavaScript mapping
  file: an object, a Map, or a function resolving to one of the above
  or a String (containing SVG or a filename), Preact VDOM, or null/undefined,
  with Arrays possibly mixed in; or another `Mapping`.
  In this class and subclasses, `@map` stores this data.
  ###
  constructor: (data, opts) ->
    super data, {
      cache: new Map  # for static tiles
      initQueue: []
      preprocessQueue: []
      postprocessQueue: []
      ...opts
    }
    @settings = {...@settings, dirname: path.dirname @filename} if @filename?
  parse: (@map) ->
    unless typeof @map in ['function', 'object', 'undefined']
      console.warn "Mapping file #{@filename} returned invalid mapping data of type (#{typeof @map}): should be function or object"
      @map = null
    if isPreact @map
      console.warn "Mapping file #{@filename} returned invalid mapping data (Preact DOM): should be function or object"
      @map = null
  isFunction: ->
    typeof @map == 'function'
  lookup: (key, context) ->
    ## `key` normally should be a String (via `AutoDrawing::parse` coercion).
    ## Don't do anything if this is an empty mapping.
    return unless @map?
    ## Check cache (used for static tiles).
    if (found = @cache.get key)?
      return found

    ## Repeatedly expand `@map` until we get string, Preact VDOM, or
    ## null/undefined.  Arrays get expanded recursively.
    recurse = (value, isStatic = undefined) =>
      while value?
        #console.log key, (
        #  switch
        #    when Array.isArray value then 'array'
        #    when isPreact value then 'preact'
        #    else typeof value
        #), isStatic
        if typeof value == 'string' or isPreact value
          ## Static unless we saw a function and no static wrapper.
          isStatic ?= true
          ## Symbol ends up getting `isStatic` set to global `isStatic` value,
          ## instead of this local value.  For example, not helpful to mark
          ## this symbol as static if another one in an array isn't static.
          value = new SVGSymbol "tile '#{key}'", value, @settings
          #value.isStatic = isStatic
          return {value, isStatic}
        else if value instanceof Map or value instanceof WeakMap
          value = value.get key
        else if typeof value == 'function'
          value = value.call context, key, context
          ## Use of a function implies dynamic, unless there's a static wrapper.
          isStatic ?= false
        else if $static of value  # static wrapper from wrapStatic
          value = value[$static]
          ## Static wrapper forces static, even if there are functions.
          isStatic = true
        else if value instanceof Mapping or value instanceof Mappings
          return
            value: value.lookup key, context
            isStatic: false  # no need to cache at higher level
        else if Array.isArray value  # must come after Mappings test
          ## Items in an array inherit parent staticness if any,
          ## with no influence between items.
          ## Overall array is static if every item is.
          allStatic = true
          value =
            for item in value
              result = recurse item, isStatic
              allStatic = false if result.isStatic == false
              result.value
          return {value, isStatic: allStatic}
        else if typeof value == 'object'
          if value.hasOwnProperty key  # avoid inherited property e.g. toString
            value = value[key]
          else
            value = undefined
        else
          console.warn "Unsupported data type #{typeof value} in looking up tile '#{key}'"
          value = undefined
      ## Static unless we saw a function and no static wrapper
      isStatic ?= true
      {value, isStatic}
    {value, isStatic} = recurse @map

    ## Set each symbol's `isStatic` flag to the global `isStatic` value.
    ## Enforce arrays to be flat with no nulls.
    if Array.isArray value
      value =
        for symbol in value.flat Infinity when symbol?
          symbol.isStatic = isStatic
          symbol
    else if value?
      value.isStatic = isStatic

    ## Save in cache if overall static.
    @cache.set key, value if isStatic
    value
  onInit: (fn) ->
    @initQueue.push fn
  preprocess: (fn) ->
    @preprocessQueue.push fn
  postprocess: (fn) ->
    @postprocessQueue.push fn
  doInit: ->
    runWithMapping @, =>
      for callback in @initQueue
        callback.call @, @
  doPreprocess: (render) ->
    runWithMapping @, =>
      for callback in @preprocessQueue
        callback.call render, render
  doPostprocess: (render) ->
    runWithMapping @, =>
      for callback in @postprocessQueue
        callback.call render, render

onInit = (fn) ->
  unless currentMapping?
    throw new SVGTilerError "svgtiler.onInit called outside mapping file"
  currentMapping.onInit fn
preprocess = (fn) ->
  unless currentMapping?
    throw new SVGTilerError "svgtiler.preprocess called outside mapping file"
  currentMapping.preprocess fn
postprocess = (fn) ->
  unless currentMapping?
    throw new SVGTilerError "svgtiler.postprocess called outside mapping file"
  currentMapping.postprocess fn

## A fake Mapping file that just sets a `share` key when initialized.
## (Used to implement -s/--share command-line option.)
class ShareSetter
  constructor: (key, value) ->
    @key = key
    @value = value
  doInit: ->
    globalShare[@key] = @value

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
      #if @constructor == JSMapping
      #  {code} = require('@babel/core').transform fs.readFileSync(filename), {
      #    ...babelConfig
      #    filename: @filename
      #  }
      #  console.log code
      pirates?.settings = @settings
      @module = runWithMapping @, -> require filename
      #console.log filename, @module
      super @module.default
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
  doPreprocess: (render) ->
    for mapping in @
      mapping.doPreprocess render
  doPostprocess: (render) ->
    for mapping in @
      mapping.doPostprocess render

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
    ## No special negative number handling
    @keys[i]?[j]
  set: (j, i, key) ->
    if i < 0 or j < 0
      throw new SVGTilerError "Cannot set key for negative index (#{i}, #{j})"
    while i >= @keys.length
      @keys.push []
    row = @keys[i]
    while j >= row.length
      row.push ''
    row[j] = key
  at: (j, i) ->
    ## Negative numbers wrap around
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
  * Optionally pads rows to same length according to `keepUneven` setting.
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
    unless @getSetting 'keepUneven'
      width = Math.max 0, ...(row.length for row in data)
      for row in data
        while row.length < width
          row.push ''
    super data
  set: (j, i, key) ->
    oldHeight = @keys.length
    super j, i, key
    ## If we added new rows, make them match row 0's length.
    unless oldHeight == @keys.length or @getSetting 'keepUneven'
      for row in @keys[oldHeight..]
        while row.length < @keys[0].length
          row.push ''

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
        new AutoDrawing data,
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

class Tile
  ###
  `Tile` represents a rendered tile, which consists of
  * the input `key` (usually a `String`) and coordinates (`i` and `j`);
  * an `SVGSymbol` (`symbol`); and
  * a layout (`xMin`, `yMin`, `xMax`, `yMax`, `width`, `height`).
  We also store `zIndex` and `isEmpty` (from the symbol).
  Note that typically several `Tile`s use the same `SVGSymbol`
  (assuming some re-use of tiles, e.g., repeated keys).
  ###
  constructor: (opts) ->
    @[key] = value for key, value of opts if opts?

## Do not need to wrap the following elements in <defs>.
skipDef = new Set [
  'clipPath'
  'defs'
  'desc'
  'filter'
  'linearGradient'
  'marker'
  'mask'
  'metadata'
  'pattern'
  'radialGradient'
  'script'
  'style'
  'title'
]

class Render extends HasSettings
  constructor: (@drawing, @settings) ->
    super()
    @settings ?= @drawing.settings
    @backgroundFill = @getSetting 'background'
    @idVersions = new Map
    @mappings = new Mappings @getSetting 'mappings'
    @styles = new Styles @getSetting 'styles'
    @defs = []
    ## Accumulated rendering, in case add() called before makeDOM():
    @xMin = @yMin = @xMax = @yMax = 0
    @layers = {}
  hrefAttr: -> hrefAttr @settings
  id: (key) -> #, noEscape) ->
    ## Generate unique ID starting with an escaped version of `key`.
    ## If necessary, appends _v0, _v1, _v2, etc. to make unique.
    key = escapeId key #unless noEscape
    version = @idVersions.get(key) ? 0
    @idVersions.set key, version + 1
    if version
      "#{key}_v#{version}"
    else
      key
  undoId: (key) ->
    ## Undoes the effect of `@id(key)` by decrementing the version counter.
    key = escapeId key
    @idVersions.set key, @idVersions.get(key) - 1
  cacheLookup: (def) ->
    ###
    Given `SVGContent` for a `def` (e.g. <symbol>),
    check cache by `value` if it's a string (e.g. filename,
    to avoid loading file again), and by computed SVG string
    (in case multiple paths lead to the same SVG content).
    Returns the cached `SVGContent` if found, or `undefined` if new.
    ###
    unless typeof def.value == 'string' and (found = @cache.get def.value)?
      unless def.value == def.makeSVG()
        unless (found = @cache.get def.svg)?
          @cache.set def.svg, def
      @cache.set def.value, def
    found
  def: (content) ->
    content = new SVGContent getContextString(), content,
      getSettings() ? @settings
    if (found = @cacheLookup content)?
      found
    else
      content.setId @id content.defaultId 'def'
      @defs.push content
      content
  background: (fill) ->
    ## Sets current background fill to specified value; `null` to remove.
    ## Returns current background fill.
    @backgroundFill = fill unless fill == undefined
    @backgroundFill
  add: (content, prepend) ->
    unless content instanceof SVGContent
      content = new SVGContent \
        "svgtiler.add content from #{getContextString()}", content, @settings
    dom = content.makeDOM()
    return if content.isEmpty
    if (box = content.overflowBox ? content.viewBox)?
      @xMin = Math.min @xMin, box[0]
      @yMin = Math.min @yMin, box[1]
      @xMax = Math.max @xMax, box[0] + box[2]
      @yMax = Math.max @yMax, box[1] + box[3]
      @updateSize()
    @layers[content.zIndex] ?= []
    if prepend
      @layers[content.zIndex].unshift dom.documentElement
    else
      @layers[content.zIndex].push dom.documentElement
  updateSize: ->
    @width = @xMax - @xMin
    @height = @yMax - @yMin
  makeDOM: -> runWithRender @, => runWithContext (new Context @), =>
    ###
    Main rendering engine, returning an xmldom object for the whole document.
    Also saves the table of `Tile`s (symbols with layout geometry) in `@tiles`,
    and bounding box in `@xMin`, `@xMax`, `@yMin`, `@yMax`,
    `@width`, and `@height`.
    ###
    @dom = domImplementation.createDocument SVGNS, 'svg'
    svg = @dom.documentElement
    svg.setAttribute 'xmlns:xlink', XLINKNS unless @getSetting 'useHref'
    svg.setAttribute 'version', '1.1'
    #svg.appendChild defs = @dom.createElementNS SVGNS, 'defs'

    ## Preprocess callbacks, which may change anything about the Render job
    @mappings.doPreprocess @

    ## <style> tags for CSS
    for style in @styles
      svg.appendChild styleTag = @dom.createElementNS SVGNS, 'style'
      styleTag.textContent = style.css

    ## Render all tiles in the drawing.
    missing = new Set
    errored = new Set
    @cache = new Map
    @tiles =
      for row, i in @drawing.keys
        for key, j in row
          currentContext.move j, i
          try
            symbols = @mappings.lookup key, currentContext
          catch error
            console.warn "Error while evaluating mapping for key '#{key}':"
            console.error error
            errored.add key
            symbols = errorSymbol
          unless symbols? and symbols.length != 0
            missing.add key
            symbols = unrecognizedSymbol
          symbols = [symbols] unless Array.isArray symbols
          for symbol, k in symbols
            ## Check cache for this symbol
            if (found = @cacheLookup symbol)?
              symbol = found
            else
              ## Set id before generating DOM (needed for `isEmpty`)
              ## to make `id` the first attribute.
              symbol.setId id = @id key unless symbol.id?  # unrecognizedSymbol has id
              symbol.makeDOM()
              if symbol.isEmpty
                @undoId key
                symbol.setId '_empty'
              else
                ## Include new non-empty <symbol> in SVG
                svg.appendChild symbol.useDOM()
            new Tile {i, j, k, key, symbol,
              isEmpty: symbol.isEmpty
              zIndex: symbol.zIndex
            }
    currentContext = null
    missing = ("'#{key}'" for key from missing)
    errored = ("'#{key}'" for key from errored)
    if missing.length
      console.warn "Failed to recognize tiles:", missing.join ', '
    if errored.length
      console.warn "Errors during tiles:", errored.join ', '

    ## Lay out the tiles in the drawing via SVG <use>.
    y = 0
    colWidths = {}
    for row, i in @tiles
      rowHeight = 0
      for tiles in row
        for tile in tiles
          if not tile.symbol.autoHeight and tile.symbol.height > rowHeight
            rowHeight = tile.symbol.height
      x = 0
      for tiles, j in row
        for tile, k in tiles
          {symbol} = tile
          tile.xMin = x
          tile.yMin = y
          unless symbol?
            tile.width = tile.height = 0
            tile.xMax = x
            tile.yMax = y
            continue
          scaleX = scaleY = 1
          if symbol.autoWidth and symbol.width > 0
            if k == 0
              colWidths[j] ?= Math.max 0, ...(
                for row2 in @tiles when row2[j]?[0]?.symbol? and not row2[j][0].symbol.autoWidth
                  row2[j][0].symbol.width
              )
              scaleX = colWidths[j] / symbol.width
            else
              scaleX = tiles[0].width / symbol.width
            scaleY = scaleX unless symbol.autoHeight
          if symbol.autoHeight and symbol.height > 0
            if k == 0
              scaleY = rowHeight / symbol.height
            else
              scaleX = tiles[0].height / symbol.height
            scaleX = scaleY unless symbol.autoWidth
          tile.width = symbol.width * scaleX
          tile.height = symbol.height * scaleY
          tile.xMax = x + tile.width
          tile.yMax = y + tile.height
          unless tile.isEmpty
            @layers[tile.zIndex] ?= []
            @layers[tile.zIndex].push use = @dom.createElementNS SVGNS, 'use'
            use.setAttribute @hrefAttr(), '#' + symbol.id
            use.setAttribute 'x', x
            use.setAttribute 'y', y
            ## Symbols generally set their own width and height,
            ## so only need to set these on <use> when they are 'auto'.
            ## SVG's scaling of tile is relative to viewBox (including possible
            ## `zeroSizeReplacement`), so use viewBox to define width and
            ## height attributes:
            if symbol.autoWidth
              use.setAttribute 'width',
                (symbol.viewBox?[2] ? symbol.width) * scaleX
            if symbol.autoHeight
              use.setAttribute 'height',
                (symbol.viewBox?[3] ? symbol.height) * scaleY
          if symbol.overflowBox?
            dx = (symbol.overflowBox[0] - symbol.viewBox[0]) * scaleX
            dy = (symbol.overflowBox[1] - symbol.viewBox[1]) * scaleY
            @xMin = Math.min @xMin, x + dx
            @yMin = Math.min @yMin, y + dy
            @xMax = Math.max @xMax, x + dx + symbol.overflowBox[2] * scaleX
            @yMax = Math.max @yMax, y + dy + symbol.overflowBox[3] * scaleY
        x = tiles[0].xMax
        @xMax = Math.max @xMax, x
      y += rowHeight
      @yMax = Math.max @yMax, y

    ## Postprocess callbacks, which may use (and update) @width/@height
    @updateSize()
    @mappings.doPostprocess @

    ## Background fill, now that size has settled
    if (@backgroundFill ?= @getSetting 'background')?
      @add new SVGContent("background",
        """<rect z-index="-Infinity" x="#{@xMin}" y="#{@yMin}" width="#{@width}" height="#{@height}" fill="#{@backgroundFill}"/>""",
        @settings), true  # prepend

    ## Check for global <defs> used by the symbols so far.
    usedIds = new Set
    globalIdMap = new Map
    findGlobalDefs = (root) =>
      for {id, node, attr} in findRefs root
        desireId = unglobalId id
        if id == desireId  # local id
          usedIds.add id
        else  # global id
          unless (newId = globalIdMap.get id)?  # first use
            unless (def = globalDefs.get id)?
              throw new SVGTilerError "Referenced global ID '#{id}' in node #{node} not found"
            if (found = @cacheLookup def)?
              newId = found.id
            else
              globalIdMap.set id, newId = @id desireId
              usedIds.add newId
              def.setId newId
              @defs.push def
          node.setAttribute attr, node.getAttribute(attr).replace "##{id}",
            "##{newId}"
    findGlobalDefs svg

    ## Render all <defs> so far and check for additional <defs> used by them.
    ## `for def in @defs` but allowing @defs to change in length
    ## from additional global <defs> encountered along the way.
    i = 0
    defDoms =
      while i < @defs.length
        def = @defs[i++]
        dom = def.useDOM()
        ## Look for more global <defs> used by this def.
        findGlobalDefs dom
        {def, dom}
    ## Add <defs> to DOM if they're used or forced.
    firstSymbol = svg.firstChild
    defsWrapper = null
    for {def, dom} in defDoms
      ## Omit unused <defs> unless forced.
      continue unless def.isForced or usedIds.has def.id
      ## Wrap in <defs> if needed.
      if skipDef.has dom.tagName
        svg.insertBefore dom, firstSymbol
      else
        defsWrapper ?= @dom.createElementNS SVGNS, 'defs'
        defsWrapper.appendChild dom
    svg.insertBefore defsWrapper, svg.firstChild if defsWrapper?

    ## Factor out duplicate inline <image>s into separate <symbol>s.
    inlineImages = new Map
    domRecurse svg, (node) =>
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
      node.parentNode.replaceChild (use = @dom.createElementNS SVGNS, 'use'),
        node
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
        inlineImages.set attributes, id = @id filename
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
      if process.platform == 'win32'
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
      for tiles, j in row
        for tile, k in tiles
          {xMin, yMin} = tile
          for text in tile.symbol.text
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
            lines.push "    \\put(#{xMin+tx},#{@height - (yMin+ty)}){\\color{#{attributeOrStyle(text, 'fill') or 'black'}}#{wrap}#{content}#{wrap and '}'}}%"
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
    if not relativeDir? and (outputDir =
      @getOutputDir('.pdf') ? @getOutputDir('.png') ? @getOutputDir('.svg')
    )?
      relativeDir = path.relative path.parse(filename).dir, outputDir
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

###
ids generated at the top level have the temporary form "_globalN_ID",
where "N" is a globally unique integer and "ID" is the (escaped) desired id
(to be assigned a version number later).
###
globalIdCount = 0
globalId = (baseId = 'id') ->
  if currentRender?
    currentRender.id baseId
  else
    "_global#{globalIdCount++}_#{escapeId baseId}"
unglobalId = (id) ->
  id.replace /^_global\d+_/, ''

globalDefs = new Map
globalDef = (content) ->
  if currentRender?
    currentRender.def content
  else
    content = new SVGContent getContextString(), content, getSettings()
    content.setId globalId content.defaultId 'def'
    content.isStatic = true  # global def may get re-used in multiple renders
    globalDefs.set content.id, content
    content

globalBackground = (fill) ->
  ## Sets current/default background fill to specified value; `null` to remove.
  ## Returns current background fill.
  if currentRender?
    currentRender.background fill
  else if currentMapping?
    preprocess (render) -> render.background fill
  else
    throw new SVGTilerError "svgtiler.background called outside of render of mapping context"

globalAdd = (content, ...opts) ->
  if currentRender?
    currentRender.add content, ...opts
  else
    throw new SVGTilerError "svgtiler.add called outside of render context"

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
  set: (key) ->
    ## Change key for this location
    @drawing.set @j, @i, key
  at: (j, i) ->
    ## Negative numbers wrap around
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
    for key, j in @drawing.keys[i] ? []
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
  '.args': Args
#filenameMap =
#  'maketile': Args

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
  -O STEM / --output-stem STEM  Write next output to STEM.{svg,svg_tex,pdf,png}
                                (STEM can use * to refer to input stem)
  --os DIR / --output-svg DIR   Write all .svg files to directory DIR
  --op DIR / --output-pdf DIR   Write all .pdf files to directory DIR
  --oP DIR / --output-png DIR   Write all .png files to directory DIR
  --ot DIR / --output-tex DIR   Write all .svg_tex files to directory DIR
  -i PATH / --inkscape PATH     Specify PATH to Inkscape binary
  -j N / --jobs N       Run up to N Inkscape jobs in parallel
  -s KEY=VALUE / --share KEY=VALUE  Set share.KEY to VALUE (undefined if no =)
  -m / --margin         Don't delete blank extreme rows/columns
  --uneven              Don't make all rows have same length by padding with ''
  --hidden              Process hidden sheets within spreadsheet files
  --bg BG / --background BG  Set background fill color to BG
  --tw TILE_WIDTH / --tile-width TILE_WIDTH
                        Force all tiles to have specified width
  --th TILE_HEIGHT / --tile-height TILE_HEIGHT
                        Force all tiles to have specified height
  --no-inline           Don't inline <image>s into output SVG
  --no-overflow         Don't default <symbol> overflow to "visible"
  --no-sanitize         Don't sanitize PDF output by blanking out /CreationDate
  (                     Remember settings, mappings, styles, and share values
  )                     Restore last remembered settings/mappings/styles/share

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

inputRequire = (filename, settings = getSettings() ? defaultSettings, dirname) ->
  filename = path.join dirname, filename if dirname?
  Input.recognize filename, undefined, settings

glob = (pattern, options) ->
  ## Support backslash in Windows path as long as not meaningful escape.
  ## [code from svgink]
  if process.platform == 'win32'
    pattern = pattern.replace /\\($|[^\*\+\?\!\|\@\(\)\[\]\{\}])/g, '/$1'
  require('glob').sync pattern, options

loadMaketile = (settings = getSettings() ? defaultSettings) ->
  filenames = glob settings.maketile, nodir: true
  return unless filenames.length
  inputRequire filenames.sort().pop(), settings

main = (args = process.argv[2..]) ->
  showHelp = 'No filename arguments and no Maketile to run; showing --help'
  maketile = null
  ranMaketile = false
  files = 0
  inputCache = new Map  # maps filenames to previously loaded `Input`s
  formats = []
  settings = cloneSettings defaultSettings, true
  inits = []  # array of objects to call doInit() on
  stack = []  # {settings, inits} objects for implementing parens
  # `for arg, i in args` but allowing i to advance and args to get appended to
  i = 0
  loop
    if i >= args.length and not files and not ranMaketile and
       (maketile ?= loadMaketile settings)?
      ranMaketile = true
      if maketile instanceof Args
        showHelp = "No filename arguments on command line or in '#{maketile.filename}'"
        args.push ...maketile.args
      else if maketile instanceof Mapping
        showHelp = false
        maketile.doInit()
        if maketile.isFunction()
          maketile.map()
        else
          console.log "Maketile '#{maketile.filename}' did not `export default` a function"
      else
        showHelp = false
        console.log "Unrecognized Maketile '#{maketile.filename}' of type '#{maketile?.constructor?.name}'"
    break if i >= args.length
    switch (arg = args[i])
      when '-h', '--help'
        help()
        return
      when '-f', '--force'
        settings.force = true
      when '-m', '--margin'
        settings.keepMargins = true
      when '--uneven'
        settings.keepUneven = true
      when '--hidden'
        settings.keepHidden = true
      when '--tw', '--tile-width'
        i++
        arg = parseFloat args[i]
        if arg?
          settings.forceWidth = arg
        else
          console.warn "Invalid argument to --tile-width: #{args[i]}"
      when '--th', '--tile-height'
        i++
        arg = parseFloat args[i]
        if arg?
          settings.forceHeight = arg
        else
          console.warn "Invalid argument to --tile-height: #{args[i]}"
      when '--bg', '--background'
        i++
        settings.background = args[i]
      when '-s', '--share'
        i++
        [key, ...value] = args[i].split '='
        inits.push setter =
          new ShareSetter key, value.join '='  # ignore later =s
        setter.doInit()
      when '-o', '--output'
        i++
        settings.outputDir = args[i]
      when '-O', '--output-stem'
        i++
        settings.outputStem = args[i]
      when '--os', '--output-svg'
        i++
        settings.outputDirExt['.svg'] = args[i]
      when '--op', '--output-pdf'
        i++
        settings.outputDirExt['.pdf'] = args[i]
      when '--oP', '--output-png'
        i++
        settings.outputDirExt['.png'] = args[i]
      when '--ot', '--output-tex'
        i++
        settings.outputDirExt['.svg_tex'] = args[i]
      when '-i', '--inkscape'
        i++
        settings.inkscape = args[i]
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
        i++
        arg = parseInt args[i], 10
        if arg
          settings.jobs = arg
        else
          console.warn "Invalid argument to --jobs: #{args[i]}"
      when '('
        stack.push
          settings: cloneSettings settings
          inits: [...inits]
      when ')'
        oldInits = inits
        if stack.length
          {settings, inits} = stack.pop()
        else
          console.warn "Unmatched ')'"
          settings = cloneSettings defaultSettings, true
          inits = []
        ## Check whether inits list changed.  If so,
        ## reset globalShare without changing top-level object identity,
        ## and re-initialize all still-active mappings to restore side-effects.
        unless inits.length == oldInits.length and
               inits.every (init, i) -> init == oldInits[i] 
          delete globalShare[key] for key of globalShare
          init.doInit() for init in inits
      else
        showHelp = false
        unless (exists = inputCache.has arg)
          try
            exists = fs.statSync arg
        if exists
          filenames = [arg]
        else
          filenames = glob arg
        append = i+1  # where to append Args
        for filename in filenames
          files++
          cached = inputCache.has filename
          console.log '*', filename, if cached then '(cached)' else ''
          if cached
            input = inputCache.get filename
            input.settings = settings
          else
            input = Input.recognize filename, undefined, settings
            ## Cache Mapping files, as we only capture `onInit` etc. callbacks on
            ## the first load (top-level code run only during first `require`).
            ## Don't cache drawing files, as we might have changed options like
            ## `keepMargins` and `keepUneven` which affect parsing.
            inputCache.set filename, input if input instanceof Mapping
          if input instanceof Mapping
            settings.mappings.push input
            inits.push input
            input.doInit()
          else if input instanceof Style
            settings.styles.push input
          else if input instanceof Drawing or input instanceof Drawings
            svgs = input.render settings
            ## Convert to any additional formats.  Even if SVG files didn't
            ## change, we may not have done these conversions before or in the
            ## last run of SVG Tiler, so let svgink compare mod times and decide.
            convert svgs, formats, settings
            ## Reset -O output filename stem override unless it uses `*`.
            if settings.outputStem? and not settings.outputStem.includes '*'
              settings.outputStem = null
          else if input instanceof SVGFile
            convert input.filename, formats, settings
          else if input instanceof Args
            args[append...append] = input.args
            append += input.args.length
          else
            console.log "Unrecognized file '#{filename}' of type '#{input?.constructor?.name}'"
    i++
  if showHelp
    console.log showHelp
    help()

svgtiler = {
  SVGContent, SVGWrapped, SVGSymbol, unrecognizedSymbol,
  Mapping, Mappings, ASCIIMapping, JSMapping, CoffeeMapping,
  getMapping, runWithMapping, static: wrapStatic,
  Drawing, AutoDrawing, ASCIIDrawing,
  DSVDrawing, SSVDrawing, CSVDrawing, TSVDrawing,
  Drawings, XLSXDrawings,
  Style, CSSStyle, StylusStyle, Styles,
  Args, SVGFile,
  extensionMap, Input, DummyInput, ArrayWrapper,
  Render, getRender, runWithRender, onInit, preprocess, postprocess,
  id: globalId, def: globalDef, background: globalBackground,
  add: globalAdd,
  Context, getContext, getContextString, runWithContext,
  SVGTilerError, SVGNS, XLINKNS, escapeId,
  main, renderDOM, convert, glob, require: inputRequire,
  defaultSettings, getSettings, cloneSettings, getSetting, getOutputDir,
  share: globalShare
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
    if process.platform == 'win32'
      ';'
    else
      ':'
  )
  require('module').Module._initPaths()

  main()
