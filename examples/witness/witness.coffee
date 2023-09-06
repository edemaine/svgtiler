###
Originally created for the paper "Who witnesses The Witness?  Finding
witnesses in The Witness is hard and sometimes impossible" by Zachary Abel,
Jeffrey Bosboom, Michael Coulombe, Erik D. Demaine, Linus Hamilton,
Adam Hesterberg, Justin Kopinsky, Jayson Lynch, Mikhail Rudoy, and
Clemens Thielen [https://erikdemaine.org/papers/Witness_TCS/].

Design and coordinates based on thefifthmatt's Windmill SVG design.  See
https://github.com/thefifthmatt/windmill-client/blob/master/src/windmill.soy
###

gridColor = 'black'
#pathColor = '#d3ac0d'
#pathColor = 'mediumpurple'
pathColor = 'violet'

lineColor = (solution) ->
  if solution
    pathColor
  else
    gridColor
zIndex = (solution) ->
  if solution
    4
  else
    1

width = (self, shrinkExtremes) ->
  if self.column().some((cell) -> cell.includes '.') and self.column().some((cell) -> cell.includes '-')
    console.log self.i, self.j, self.key, 'is ambiguous (. and -):', self.column().map((cell) -> cell.key).join ', '
  if self.column().some((cell) -> cell.includes('.') or cell.includes('start'))
    20
  else if shrinkExtremes and not self.row()[self.j+1..].some((cell) -> cell.key?)
    ## Don't use full width if there's nothing to our right
    20
  else if shrinkExtremes and [0..self.j].every((dj) ->
            self.column(dj).every (cell) -> cell.key in ['', 'finish'])
    ## Shrink columns that just have finish in them and nothing left of them.
    20
  else
    80
  ## Use full width if there's anything to our right
  #if self.j % 2 == 1 and (self.neighbor(1,0).key? or self.neighbor(2,0).key?)
  #  80
  #else
  #  20
height = (self, shrinkExtremes) ->
  if self.row().some((cell) -> cell.includes '.')
    20
  else if shrinkExtremes and not self.column()[self.i+1..].some((cell) -> cell.key?)
    ## Don't use full height if there's nothing below
    20
  else if shrinkExtremes and [0..self.i].every((di) ->
            self.row(di).every (cell) -> cell.key in ['', 'finish'])
    ## Shrink rows that just have finish in them and nothing above them.
    20
  else
    80
  #if self.i % 2 == 1
  #  80
  #else
  #  20

horizontal = (solution) -> ->
  """
    <symbol viewBox="10 -10 80 20" z-index="#{zIndex solution}">
      <line x1="9.5" x2="90.5" y1="0" y2="0" stroke-width="20" stroke="#{lineColor solution}"/>
    </symbol>
  """

vertical = (solution) -> ->
  """
    <symbol viewBox="-10 10 20 80" z-index="#{zIndex solution}">
      <line y1="9.5" y2="90.5" x1="0" x2="0" stroke-width="20" stroke="#{lineColor solution}"/>
    </symbol>
  """

broken = (edgeGen) -> ->
  DISJOINT_LENGTH = 30
  GRID_UNIT = 80  # this is 100 in windmill.soy, but we're skipping vertex here
  edgeGen(false).call @
  .replace 'stroke', """stroke-dasharray="#{DISJOINT_LENGTH},#{GRID_UNIT-DISJOINT_LENGTH*2},#{DISJOINT_LENGTH}" $&"""

parseViewBox = (symbol) ->
  match = /viewBox="(\S+) (\S+) (\S+) (\S+)"/.exec symbol
  x0 = parseFloat match[1]
  y0 = parseFloat match[2]
  w = parseFloat match[3]
  h = parseFloat match[4]
  [x0, y0, w, h]

expandViewBox = (symbol, minX, minY, maxX, maxY) ->
  symbol.replace /viewBox="(\S+) (\S+) (\S+) (\S+)"/,
    (match, x0, y0, w, h) ->
      x0 = parseFloat x0
      y0 = parseFloat y0
      w = parseFloat w
      h = parseFloat h
      if minX? and minX < x0
        w += x0 - minX
        x0 = minX
      if minY? and minY < y0
        h += y0 - minY
        y0 = minY
      if maxX? and maxX > x0 + w
        w = maxX - x0
      if maxY? and maxY > y0 + h
        h = maxY - y0
      "#{match} overflowBox=\"#{x0} #{y0} #{w} #{h}\""

x_in_middle = (symbolFun) -> ->
  symbol = symbolFun.call @
  [x0, y0, w, h] = parseViewBox symbol
  cx = x0 + w/2
  cy = y0 + h/2
  symbol = symbol.replace /<\/symbol>/, """
      <line x1="#{cx-20}" y1="#{cy-20}" x2="#{cx+20}" y2="#{cy+20}" stroke-width="20" stroke="red"/>
      <line x1="#{cx+20}" y1="#{cy-20}" x2="#{cx-20}" y2="#{cy+20}" stroke-width="20" stroke="red"/>
    </symbol>
  """
  expandViewBox symbol, cx - 20 * (1 + Math.sqrt(2)/4),
                        cy - 20 * (1 + Math.sqrt(2)/4),
                        cx + 20 * (1 + Math.sqrt(2)/4),
                        cy + 20 * (1 + Math.sqrt(2)/4)

dot = (solution) -> -> ## dynamic symbol
  s = '<symbol viewBox="-10 -10 20 20" z-index="ZZZ">'
  #console.log @neighbor(-1,0).includes('-'), @neighbor(+1,0).includes('-'),
  #            @neighbor(0,-1).includes('|'), @neighbor(0,+1).includes('|')
  if (@neighbor(-1,0).includes('-') and @neighbor(+1,0).includes('-')) or
     (@neighbor(0,-1).includes('|') and @neighbor(0,+1).includes('|'))
    s += """<rect x="-10" y="-10" width="20" height="20" fill="#{gridColor}"/>"""
  else
    s += """<circle cx="0" cy="0" r="10" fill="#{gridColor}"/>"""
    if @neighbor(-1,0).includes '-'
      s += """<rect x="-10" y="-10" width="10" height="20" fill="#{gridColor}"/>"""
    if @neighbor(+1,0).includes '-'
      s += """<rect x="0" y="-10" width="10" height="20" fill="#{gridColor}"/>"""
    if @neighbor(0,-1).includes '|'
      s += """<rect x="-10" y="-10" width="20" height="10" fill="#{gridColor}"/>"""
    if @neighbor(0,+1).includes '|'
      s += """<rect x="-10" y="0" width="20" height="10" fill="#{gridColor}"/>"""
  if (@neighbor(-1,0).includes('-') and @neighbor(-1,0).includes('s')) or
     (@neighbor(+1,0).includes('-') and @neighbor(+1,0).includes('s')) or
     (@neighbor(0,-1).includes('|') and @neighbor(0,-1).includes('s')) or
     (@neighbor(0,+1).includes('|') and @neighbor(0,+1).includes('s')) or
     solution
    s = s.replace /ZZZ/, 3
    if (@neighbor(-1,0).includes('-') and @neighbor(-1,0).includes('s') and
        @neighbor(+1,0).includes('-') and @neighbor(+1,0).includes('s')) or
       (@neighbor(0,-1).includes('|') and @neighbor(0,-1).includes('s') and
        @neighbor(0,+1).includes('|') and @neighbor(0,+1).includes('s'))
      s += """<rect x="-10" y="-10" width="20" height="20" fill="#{pathColor}"/>"""
    else
      s += """<circle cx="0" cy="0" r="10" fill="#{pathColor}"/>"""
      if (@neighbor(-1,0).includes('-') and @neighbor(-1,0).includes('s')) or \
          @neighbor(-1,0).includes('finish')
        s += """<rect x="-10" y="-10" width="10" height="20" fill="#{pathColor}"/>"""
      if (@neighbor(+1,0).includes('-') and @neighbor(+1,0).includes('s')) or \
          @neighbor(+1,0).includes('finish')
        s += """<rect x="0" y="-10" width="10" height="20" fill="#{pathColor}"/>"""
      if (@neighbor(0,-1).includes('|') and @neighbor(0,-1).includes('s')) or \
          @neighbor(0,-1).includes('finish')
        s += """<rect x="-10" y="-10" width="20" height="10" fill="#{pathColor}"/>"""
      if (@neighbor(0,+1).includes('|') and @neighbor(0,+1).includes('s')) or \
          @neighbor(0,+1).includes('finish')
        s += """<rect x="-10" y="0" width="20" height="10" fill="#{pathColor}"/>"""
  else
    s = s.replace /ZZZ/, 0
  s + '</symbol>'

blank = ->
  """
    <symbol viewBox="0 0 #{width @, true} #{height @, true}">
    </symbol>
  """

start = (solution) -> ->
  s = """
    <symbol viewBox="-10 -10 20 20" overflowBox="-25 -25 50 50" z-index="2">
      <circle cx="0" cy="0" r="25" fill="COLOR" />
  """
  if (@neighbor(-1,0).includes('-') and @neighbor(-1,0).includes('s')) +
     (@neighbor(+1,0).includes('-') and @neighbor(+1,0).includes('s')) +
     (@neighbor(0,-1).includes('|') and @neighbor(0,-1).includes('s')) +
     (@neighbor(0,+1).includes('|') and @neighbor(0,+1).includes('s')) == 1 or
     solution
    s = s.replace /COLOR/g, pathColor
  else
    s = s.replace /COLOR/g, gridColor
    if (@neighbor(-1,0).includes('-') and @neighbor(-1,0).includes('s')) or
       (@neighbor(+1,0).includes('-') and @neighbor(+1,0).includes('s')) or
       (@neighbor(0,-1).includes('|') and @neighbor(0,-1).includes('s')) or
       (@neighbor(0,+1).includes('|') and @neighbor(0,+1).includes('s'))
      ## copied from dot (solved) above...
      if (@neighbor(-1,0).includes('-') and @neighbor(-1,0).includes('s') and
          @neighbor(+1,0).includes('-') and @neighbor(+1,0).includes('s')) or
         (@neighbor(0,-1).includes('|') and @neighbor(0,-1).includes('s') and
          @neighbor(0,+1).includes('|') and @neighbor(0,+1).includes('s'))
        s += """<rect x="-10" y="-10" width="20" height="20" fill="#{pathColor}"/>"""
      else
        s += """<circle cx="0" cy="0" r="10" fill="#{pathColor}"/>"""
        if @neighbor(-1,0).includes('-') and @neighbor(-1,0).includes('s')
          s += """<rect x="-10" y="-10" width="10" height="20" fill="#{pathColor}"/>"""
        if @neighbor(+1,0).includes('-') and @neighbor(+1,0).includes('s')
          s += """<rect x="0" y="-10" width="10" height="20" fill="#{pathColor}"/>"""
        if @neighbor(0,-1).includes('|') and @neighbor(0,-1).includes('s')
          s += """<rect x="-10" y="-10" width="20" height="10" fill="#{pathColor}"/>"""
        if @neighbor(0,+1).includes('|') and @neighbor(0,+1).includes('s')
          s += """<rect x="-10" y="0" width="20" height="10" fill="#{pathColor}"/>"""
  s + '</symbol>'

finish = (solution) -> ->
  # z-index is one below the z-index of dot()
  z = if solution then 2 else -1
  color = lineColor solution or
            @neighbor(-1,0).includes('s') or @neighbor(1,0).includes('s') or
            @neighbor(0,-1).includes('s') or @neighbor(0,1).includes('s')
  if @neighbor(-1,0).includes('-') or @neighbor(1,0).includes('-') or
     @neighbor(-1,0).includes('.') or @neighbor(1,0).includes('.')
    w = width @, true
    if @neighbor(-1,0).includes('-') or @neighbor(-1,0).includes('.')
      x1 = -20
    else
      x1 = w-20
    """
      <symbol viewBox="-10 -10 #{w} 20" z-index="#{z}">
        <line x1="#{x1}" x2="#{x1+20}" stroke-width="20" stroke="#{color}" stroke-linecap="round"/>
      </symbol>
    """
  else
    h = height @, true
    if @neighbor(0,-1).includes('-') or @neighbor(0,-1).includes('.')
      y1 = -20
    else
      y1 = h-20
    """
      <symbol viewBox="-10 -10 20 #{h}" z-index="#{z}">
        <line y1="#{y1}" y2="#{y1+20}" stroke-width="20" stroke="#{color}" stroke-linecap="round"/>
      </symbol>
    """

square = """
  <symbol viewBox="0 0 80 80">
    <rect x="20" y="20" width="40" height="40" rx="15" ry="15" fill="COLOR" stroke="COLOR"/>
  </symbol>
"""

star = """
  <symbol viewBox="0 0 80 80">
    <rect x="25" y="25" width="30px" height="30px" fill="COLOR" stroke="COLOR" />
    <rect x="25" y="25" width="30px" height="30px" transform="rotate(45 40 40)" fill="COLOR" stroke="COLOR" />
  </symbol>
"""

triangle = (k) ->
  r = 8
  addl = r*2 + 4
  h = r*1.73205/2
  xTransform = (k-1)*addl
  svg = """<symbol viewBox="-40 -40 80 80">"""
  for i in [0...k]
    # fill="orange" in Windmill, but really yellow in game
    svg += """
      <polygon fill="darkorange" stroke="none"
               points="0,#{-h} #{r},#{h} #{-r},#{h}"
               transform="translate(#{i*addl-xTransform/2},0)" />
    """
  svg + "</symbol>"

hexagon = (dx = 0, dy = 0) ->
  r = 8
  s = r/2
  h = r*Math.sqrt(3)/2
  # windmill uses:
  # <polygon fill="gray" stroke="gray"
  """
    <polygon fill="#00ff00" stroke="#00ff00"
             points="#{-r},0 #{-s},#{-h} #{s},#{-h} #{r},0 #{s},#{h} #{-s},#{h}"
             transform="translate(#{dx},#{dy})" />
  """

dot_hexagon = (solution) -> ->
  svg = dot(solution).call @
  svg.replace '</symbol>', "#{hexagon(0,0)}\n$&"

horizontal_hexagon = (solution) -> ->
  svg = horizontal(solution).call @
  svg.replace '</symbol>', "#{hexagon(50,0)}\n$&"

vertical_hexagon = (solution) -> ->
  svg = vertical(solution).call @
  svg.replace '</symbol>', "#{hexagon(0,50)}\n$&"

start_hexagon = (solution) -> ->
  svg = start(solution).call @
  svg.replace '</symbol>', "#{hexagon(0,0)}\n$&"

tetris = (pixels, negative = false, free = false) ->
  TETRIS = 18
  TETRIS_SPACE = 3
  xmin = Math.min (pixel[0] for pixel in pixels)...
  xmax = Math.max (pixel[0] for pixel in pixels)...
  w = TETRIS*(xmax-xmin+1) + TETRIS_SPACE*(xmax-xmin)
  ymin = Math.min (pixel[1] for pixel in pixels)...
  ymax = Math.max (pixel[1] for pixel in pixels)...
  h = TETRIS*(ymax-ymin+1) + TETRIS_SPACE*(ymax-ymin)
  maximumSize = Math.max xmax-xmin+1, ymax-ymin+1
  maxDimension = TETRIS*maximumSize + TETRIS_SPACE*(maximumSize-1)
  #allowedSpace = TETRIS*3.5 * (if free then 0.7071 else 1)
  allowedSpace = TETRIS*3.5 * (if free then 0.9 else 1)
  scaleFactor = if maxDimension <= allowedSpace then 1 else allowedSpace/maxDimension
  #scaleFactor = allowedSpace/maxDimension
  neg = if negative then 2 else 0
  pos = if negative then 0 else 2
  lines = ['<symbol viewBox="0 0 80 80">']
  if free
    #lines.push """<g transform="translate(40,40) rotate(-15, #{w*scaleFactor/2}, #{h*scaleFactor/2}) scale(#{scaleFactor})">"""
    lines.push """<g transform="translate(40,40) rotate(-15) scale(#{scaleFactor})">"""
  else
    lines.push """<g transform="translate(40,40) scale(#{scaleFactor})">"""
  if negative
    style = 'fill="none" stroke="blue" stroke-width="4"'
  else
    style = 'fill="green" stroke="none"'  ## fill="yellow" in The Windmill
  for pixel in pixels
    lines.push """
      <rect width="#{TETRIS-2*neg}" height="#{TETRIS-2*neg}"
            rx="#{pos}" ry="#{pos}"
            x="#{(TETRIS+TETRIS_SPACE)*(pixel[0]-xmin) - w/2 + neg}"
            y="#{(TETRIS+TETRIS_SPACE)*(pixel[1]-ymin) - h/2 + neg}"
            #{style} />
    """
  lines.push '</g>'
  lines.push '</symbol>'
  lines.join '\n'

monomino = (negative = false) ->
  tetris [[0,0]], negative, false

domino = (negative = false, free = false) ->
  tetris [[0,0], [0,1]], negative, free

tetris_S = (negative = false, free = false) ->
  tetris [[0,0], [1,0], [1,-1], [2,-1]], negative, free

tetris_Z = (negative = false, free = false) ->
  tetris [[0,0], [1,0], [1,1], [2,1]], negative, free

antibody = """
  <symbol viewBox="-40 -40 80 80">
    <rect width="15px" height="8px" transform="rotate(-90 0 4)" fill="COLOR" />
    <rect width="15px" height="8px" transform="rotate(30 0 4)" fill="COLOR" />
    <rect width="15px" height="8px" transform="rotate(150 0 4)" fill="COLOR" />
  </symbol>
"""

depth = (k, max = 5) ->
  hexColor = (Math.floor ((max - k) * 255 / max)).toString 16
  hexColor = "0#{hexColor}" while hexColor.length < 2
  hexColor = "##{hexColor}#{hexColor}#{hexColor}"
  if k < max/2
    textColor = 'black'
  else
    textColor = 'white'
  """
    <symbol viewBox="-40 -40 80 80">
      <rect x="-40" y="-40" width="80" height="80" fill="#{hexColor}"/>
      <text y="21" fill="#{textColor}" style="font-family: sans-serif; font-size: 60; text-anchor: middle">#{k}</text>
    </symbol>
  """

number = (k) ->
  """
    <symbol viewBox="-40 -40 80 80">
      <rect x="-40" y="-40" width="80" height="80" fill="white"/>
      <text y="21" fill="black" style="font-family: sans-serif; font-size: 60; text-anchor: middle">#{k}</text>
    </symbol>
  """

vdots = ->
  w = width @
  """
    <symbol viewBox="-#{w/2} -40 #{w} 80">
      <circle cx="0" cy="0" r="7" fill="#{gridColor}"/>
      <circle cx="0" cy="-20" r="7" fill="#{gridColor}"/>
      <circle cx="0" cy="20" r="7" fill="#{gridColor}"/>
    </symbol>
  """

cdots = ->
  h = height @
  """
    <symbol viewBox="-40 -#{h/2} 80 #{h}">
      <circle cx="0" cy="0" r="7" fill="#{gridColor}"/>
      <circle cx="-20" cy="0" r="7" fill="#{gridColor}"/>
      <circle cx="20" cy="0" r="7" fill="#{gridColor}"/>
    </symbol>
  """

replaceColor = (oldColor, newColor, symbolFun) -> ->
  symbol = symbolFun.call @
  if typeof oldColor == 'string'
    oldColor = ///#{oldColor}///g
  symbol = symbol.replace oldColor, newColor

colorMap =
  r: 'red'
  g: 'green'
  b: 'blue'
  c: 'cyan'
  o: 'orange'
  w: '#dddddd' ## avoiding 'white' given currently white background
  k: 'black'
  y: 'gold' #'yellow'
  m: 'magenta'
  ## remaining colors are unofficial
  p: 'purple'
  i: 'pink'
  R: 'darkred'
  G: 'lightgreen'
  B: 'darkblue'
  C: 'darkturquoise'
  O: 'darkorange'
  W: 'darkgrey'
  K: 'gray'
  Y: 'darkkhaki'
  #M: 'darkviolet'

bgMap =
  error: 'red'
  chamber: '#00c6c6' # dark cyan
  hallway: '#c600c6' # dark magenta
  #D: '#7f5200' # dark orange
  D: 'lightgreen'
  empty: '#a0a0a0'
bgMapRe = ///#{(key for key of bgMap).join '|'}///

map =
  '-': horizontal false
  '-s': horizontal true
  '-b': broken horizontal
  '|': vertical false
  '|s': vertical true
  '|b': broken vertical
  '-x': x_in_middle horizontal false
  '|x': x_in_middle vertical false
  '-h': horizontal_hexagon false
  '-hs': horizontal_hexagon true
  '|h': vertical_hexagon false
  '|hs': vertical_hexagon true
  '|chamber': replaceColor gridColor, bgMap.chamber, vertical false
  '-chamber': replaceColor gridColor, bgMap.chamber, horizontal false
  '.chamber': replaceColor gridColor, bgMap.chamber, dot false
  '|hallway': replaceColor gridColor, bgMap.hallway, vertical false
  '-hallway': replaceColor gridColor, bgMap.hallway, horizontal false
  '.hallway': replaceColor gridColor, bgMap.hallway, dot false
  '': blank
  ' ': blank
  '.': dot false
  '.s': dot true
  '.h': dot_hexagon false
  '.sh': dot_hexagon true
  '.hs': dot_hexagon true
  start: start false
  starts: start true
  starth: start_hexagon false
  startsh: start_hexagon true
  finish: finish false
  finishs: finish true
  '1': triangle 1
  '2': triangle 2
  '3': triangle 3
  'm': monomino()
  '!m': monomino true
  'd': domino()
  'df': domino false, true
  '!d': domino true
  '!df': domino true, true
  'a': antibody
  'tetriss': tetris_S()
  'tetrissf': tetris_S false, true
  'tetrisz': tetris_Z()
  'tetriszf': tetris_Z false, true
  '-tetriss': tetris_S true
  '-tetrissf': tetris_S true, true
  '-tetrisz': tetris_Z true
  '-tetriszf': tetris_Z true, true
  '\\vdots': vdots
  '\\cdots': cdots
  'd0': depth 0
  'd1': depth 1
  'd2': depth 2
  'd3': depth 3
  'd4': depth 4
  'n0': number 0
  'n1': number 1
  'n2': number 2
  'n3': number 3
  'n4': number 4
  'n5': number 5
  'n6': number 6
  'n7': number 7
  'n8': number 8
  'n9': number 9

(key) ->
  return map[key] if key of map
  bg = null
  key = key.replace bgMapRe, (match) ->
    bg = bgMap[match]
    ''  ## remove background indicator from key
  svg = switch key[key.length-1]
    when 'a'
      antibody.replace /COLOR/g, colorMap[key[0]]
    when 'q'
      square.replace /COLOR/g, colorMap[key[0]]
    when '*'
      star.replace /COLOR/g, colorMap[key[0]]
    else
      map[key]
  if bg? and key[0] not in ['.', '-', '|']
    bgRect = """\n<rect width="#{w}" height="#{h}" fill="#{bg}"/>\n"""
    if typeof svg == 'string'
      [x0, y0, w, h] = parseViewBox svg
      svg = svg.replace /<symbol[^<>]*>/, """$&
          <rect width="#{w}" height="#{h}" fill="#{bg}"/>
        """
    else
      oldSvg = svg
      svg = ->
        text = oldSvg.call(@)
        [x0, y0, w, h] = parseViewBox text
        text.replace /<symbol[^<>]*>/, """$&
          <rect width="#{w}" height="#{h}" fill="#{bg}"/>
        """
  svg
