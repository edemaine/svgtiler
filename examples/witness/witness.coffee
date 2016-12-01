gridColor = 'black'
pathColor = '#d3ac0d'

## Design and coordinates based on thefifthmatt's Windmill SVG design.  See
## https://github.com/thefifthmatt/windmill-client/blob/master/src/windmill.soy

## GRID + SOLUTION PATH
horizontal = """
  <symbol viewBox="10 -10 80 20">
    <line x1="10" x2="90" y1="0" y2="0" stroke-width="20" stroke="COLOR"/>
  </symbol>
"""
vertical = """
  <symbol viewBox="-10 10 20 80">
    <line y1="10" y2="90" x1="0" x2="0" stroke-width="20" stroke="COLOR"/>
  </symbol>
"""
dot = (solution) -> -> ## dynamic symbol
  s = '<symbol viewBox="-10 -10 20 20">'
  #console.log @neighbor(-1,0).includes('-'), @neighbor(+1,0).includes('-'),
  #            @neighbor(0,-1).includes('|'), @neighbor(0,+1).includes('|')
  if (@neighbor(-1,0).includes('-') and @neighbor(+1,0).includes('-')) or
     (@neighbor(0,-1).includes('|') and @neighbor(0,+1).includes('|'))
    s += """<rect x="-10" y="-10" width="20" height="20" fill="#{gridColor}"/>"""
  else
    s += """<circle x="0" y="0" r="10" fill="#{gridColor}"/>"""
    if @neighbor(-1,0).includes '-'
      s += """<rect x="-10" y="-10" width="10" height="20" fill="#{gridColor}"/>"""
    if @neighbor(+1,0).includes '-'
      s += """<rect x="0" y="-10" width="10" height="20" fill="#{gridColor}"/>"""
    if @neighbor(0,-1).includes '|'
      s += """<rect x="-10" y="-10" width="20" height="10" fill="#{gridColor}"/>"""
    if @neighbor(0,+1).includes '|'
      s += """<rect x="-10" y="0" width="20" height="10" fill="#{gridColor}"/>"""
  if solution
    if (@neighbor(-1,0).includes('-s') and @neighbor(+1,0).includes('-s')) or
       (@neighbor(0,-1).includes('|s') and @neighbor(0,+1).includes('|s'))
      s += """<rect x="-10" y="-10" width="20" height="20" fill="#{pathColor}"/>"""
    else
      s += """<circle x="0" y="0" r="10" fill="#{pathColor}"/>"""
      if @neighbor(-1,0).includes '-s'
        s += """<rect x="-10" y="-10" width="10" height="20" fill="#{pathColor}"/>"""
      if @neighbor(+1,0).includes '-s'
        s += """<rect x="0" y="-10" width="10" height="20" fill="#{pathColor}"/>"""
      if @neighbor(0,-1).includes '|s'
        s += """<rect x="-10" y="-10" width="20" height="10" fill="#{pathColor}"/>"""
      if @neighbor(0,+1).includes '|s'
        s += """<rect x="-10" y="0" width="20" height="10" fill="#{pathColor}"/>"""
  s + '</symbol>'
blank = """
  <symbol viewBox="0 0 80 80"/>
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
    svg += """
      <polygon fill="orange" stroke="none"
               points="0,#{-h} #{r},#{h} #{-r},#{h}"
               transform="translate(#{i*addl-xTransform/2},0)" />
    """
  svg + "</symbol>"

map =
  '-': horizontal.replace /COLOR/g, gridColor
  '-s': horizontal.replace /COLOR/g, pathColor
  '|': vertical.replace /COLOR/g, gridColor
  '|s': vertical.replace /COLOR/g, pathColor
  '': blank
  ' ': blank
  '.': dot false
  '.s': dot true
  '1': triangle 1
  '2': triangle 2
  '3': triangle 3

colorMap =
  r: 'red'
  g: 'green'
  b: 'blue'
  c: 'cyan'
  o: 'orange'
  w: '#dddddd' ## avoiding 'white' given currently white background
  k: 'black'
  y: 'yellow'
  m: 'magenta'

(key) ->
  return map[key] if key of map
  switch key[key.length-1]
    when 'q'
      square.replace /COLOR/g, colorMap[key[0]]
    when '*'
      star.replace /COLOR/g, colorMap[key[0]]
    else
      null
