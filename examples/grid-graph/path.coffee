parity = (share.flipParity ? 0) * 2
size = 10
edgeColor = 'purple'
edgeStroke = 4
vertexStroke = 2
arrowStroke = 2.5
arrowSize = 2.5

viewBox = "#{-size/2} #{-size/2} #{size} #{size}"

blank = <symbol viewBox={viewBox} overflowBox="-5.5 -5.5 11 11"/>

vertex = ->
  <symbol viewBox={viewBox} z-index="1"
   overflowBox="#{-(size+vertexStroke)/2} #{-(size+vertexStroke)/2} #{size+vertexStroke} #{size+vertexStroke}">
    <circle r="5" stroke="black" stroke-width={vertexStroke}
     fill={if (@i + @j) % 4 == parity then 'white' else 'black'}/>
  </symbol>

## Arrowhead based on https://developer.mozilla.org/en-US/docs/Web/SVG/Element/marker#example
arrow = ->
  id = svgtiler.def \
    <marker overflow="visible" orient="auto-start-reverse"
     viewBox="0 0 10 10" refX="10" refY="5"
     markerWidth={arrowSize} markerHeight={arrowSize}>
      <path d="M 4 0 L 10 5 L 4 10"
       fill="none" stroke={edgeColor} stroke-width={arrowStroke}/>
    </marker>
  "url(##{id})"

horizontal = (start, end) -> svgtiler.static \
  <symbol viewBox={viewBox}
   overflowBox="#{-(size+edgeStroke)/2} #{-edgeStroke/2} #{size+edgeStroke} #{edgeStroke}">
    <line x1={-size/2} x2={size/2} stroke={edgeColor} stroke-width={edgeStroke}
     marker-start={start?()} marker-end={end?()}/>
  </symbol>
vertical = (start, end) -> svgtiler.static \
  <symbol viewBox={viewBox}
   overflowBox="#{-edgeStroke/2} #{-(size+edgeStroke)/2} #{edgeStroke} #{size+edgeStroke}">
    <line y1={-size/2} y2={size/2} stroke={edgeColor} stroke-width={edgeStroke}
     marker-start={start?()} marker-end={end?()}/>
  </symbol>

' ': blank
O: vertex
o: vertex
'-': horizontal()
'|': vertical()
'<': -> horizontal arrow
'>': -> horizontal undefined, arrow
'^': -> vertical arrow
'v': -> vertical undefined, arrow
