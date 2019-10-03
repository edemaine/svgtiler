borderStyle = 'stroke="black" stroke-width="5" stroke-linecap="round"'

(key) -> ->
  s = '''
    <symbol viewBox="-10 -10 20 20" overflowBox="-12.5 -12.5 25 25" style="overflow: visible">
  '''
  if this.neighbor(-1,0).key != key
    s += """<line x1="-10" y1="-10" x2="-10" y2="10" #{borderStyle}/>"""
  if this.neighbor(+1,0).key != key
    s += """<line x1="10" y1="-10" x2="10" y2="10" #{borderStyle}/>"""
  if this.neighbor(0,-1).key != key
    s += """<line x1="-10" y1="-10" x2="10" y2="-10" #{borderStyle}/>"""
  if this.neighbor(0,+1).key != key
    s += """<line x1="-10" y1="10" x2="10" y2="10" #{borderStyle}/>"""
  s += '</symbol>'
