parity = (share.flipParity ? 0) * 2
size = 10
edgeStroke = 4
vertexStroke = 2

viewBox = "#{-size/2} #{-size/2} #{size} #{size}"

blank = <symbol viewBox={viewBox} overflowBox="-5.5 -5.5 11 11"/>

vertex = ->
  <symbol viewBox={viewBox} z-index="1"
   overflowBox="#{-(size+vertexStroke)/2} #{-(size+vertexStroke)/2} #{size+vertexStroke} #{size+vertexStroke}">
    <circle r="5" stroke="black" stroke-width={vertexStroke}
     fill={if (@i + @j) % 4 == parity then 'white' else 'black'}/>
  </symbol>

horizontal =
  <symbol viewBox={viewBox}
   overflowBox="#{-(size+edgeStroke)/2} #{-edgeStroke/2} #{size+edgeStroke} #{edgeStroke}">
    <line x1={-size/2} x2={size/2} stroke="purple" stroke-width={edgeStroke}/>
  </symbol>
vertical =
  <symbol viewBox={viewBox}
   overflowBox="#{-edgeStroke/2} #{-(size+edgeStroke)/2} #{edgeStroke} #{size+edgeStroke}">
    <line y1={-size/2} y2={size/2} stroke="purple" stroke-width={edgeStroke}/>
  </symbol>

' ': blank
O: vertex
o: vertex
'-': horizontal
'|': vertical
