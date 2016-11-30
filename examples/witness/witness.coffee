gridColor = 'black'
pathColor = '#d3ac0d'

## Design and coordinates based on thefifthmatt's Windmill SVG design.  See
## https://github.com/thefifthmatt/windmill-client/blob/master/src/windmill.soy

## GRID + SOLUTION PATH
'-': """
  <symbol viewBox="10 -10 80 20">
    <line x1="10" x2="90" y1="0" y2="0" stroke-width="20" stroke="#{gridColor}"/>
  </symbol>
"""
'-s': """
  <symbol viewBox="10 -10 80 20">
    <line x1="10" x2="90" y1="0" y2="0" stroke-width="20" stroke="#{pathColor}"/>
  </symbol>
"""
'|': """
  <symbol viewBox="-10 10 20 80">
    <line y1="10" y2="90" x1="0" x2="0" stroke-width="20" stroke="#{gridColor}"/>
  </symbol>
"""
'|s': """
  <symbol viewBox="-10 10 20 80">
    <line y1="10" y2="90" x1="0" x2="0" stroke-width="20" stroke="#{pathColor}"/>
  </symbol>
"""
'.': ->
  s = '<symbol viewBox="-10 -10 20 20">'
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
  s + '</symbol>'
'.s': ->
  s = '<symbol viewBox="-10 -10 20 20">'
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
## BLANK
'': """
  <symbol viewBox="0 0 80 80"/>
"""
' ': """
  <symbol viewBox="0 0 80 80"/>
"""
## SQUARES
'rq': """
  <symbol viewBox="0 0 80 80">
    <rect x="20" y="20" width="40" height="40" rx="15" ry="15" fill="red"/>
  </symbol>
"""
'bq': """
  <symbol viewBox="0 0 80 80">
    <rect x="20" y="20" width="40" height="40" rx="15" ry="15" fill="blue"/>
  </symbol>
"""
'rs': """
  <symbol viewBox="-25 -25 80 80">
    <rect width="30px" height="30px" fill="red" />
    <rect width="30px" height="30px" transform="rotate(45 15 15)" fill="red" />
  </symbol>
"""
'bs': """
  <symbol viewBox="-25 -25 80 80">
    <rect width="30px" height="30px" fill="blue" />
    <rect width="30px" height="30px" transform="rotate(45 15 15)" fill="blue" />
  </symbol>
"""
