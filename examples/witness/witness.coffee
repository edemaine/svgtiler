'-': '''
  <symbol viewBox="10 -10 80 20">
    <line x1="10" x2="90" y1="0" y2="0" stroke-width="20" stroke="black"/>
  </symbol>'''
'|': '''
  <symbol viewBox="-10 10 20 80">
    <line y1="10" y2="90" x1="0" x2="0" stroke-width="20" stroke="black"/>
  </symbol>'''
'.': ->
  s = '<symbol viewBox="-10 -10 20 20">'
  if (@neighbor(-1,0).includes('-') and @neighbor(+1,0).includes('-')) or
     (@neighbor(0,-1).includes('|') and @neighbor(0,+1).includes('|'))
    s += '<rect x="-10" y="-10" width="20" height="20" fill="black"/>'
  else
    s += '<circle x="0" y="0" r="10" fill="black"/>'
    if @neighbor(-1,0).includes '-'
      s += '<rect x="-10" y="-10" width="10" height="20" fill="black"/>'
    if @neighbor(+1,0).includes '-'
      s += '<rect x="0" y="-10" width="10" height="20" fill="black"/>'
    if @neighbor(0,-1).includes '|'
      s += '<rect x="-10" y="-10" width="20" height="10" fill="black"/>'
    if @neighbor(0,+1).includes '|'
      s += '<rect x="-10" y="0" width="20" height="10" fill="black"/>'
  s + '</symbol>'
' ': '''
  <symbol viewBox="0 0 80 80"/>'''
