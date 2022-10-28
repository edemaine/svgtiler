size = 10
edgeColor = 'purple'
edgeStroke = 4
vertexStroke = 2
arrowStroke = 2.5
arrowSize = 2.5

viewBox = "#{-size/2} #{-size/2} #{size} #{size}"

parity = null
export init = ->
  parity = (share.flipParity ? 0) * 2

blank = <symbol viewBox={viewBox} boundingBox="0 0 0 0"/>

vertex = ->
  <symbol viewBox={viewBox} z-index="1"
   boundingBox="#{-(size+vertexStroke)/2} #{-(size+vertexStroke)/2} #{size+vertexStroke} #{size+vertexStroke}">
    <circle r="5" stroke="black" stroke-width={vertexStroke}
     fill={if (@i + @j) % 4 == parity then 'white' else 'black'}/>
  </symbol>

## Arrowhead based on https://developer.mozilla.org/en-US/docs/Web/SVG/Element/marker#example
arrow = svgtiler.def(
  <marker overflow="visible" orient="auto-start-reverse"
    viewBox="0 0 10 10" refX="10" refY="5"
    markerWidth={arrowSize} markerHeight={arrowSize}>
    <path d="M 4 0 L 10 5 L 4 10"
      fill="none" stroke={edgeColor} stroke-width={arrowStroke}/>
  </marker>
).url()

horizontal = (start, end) ->
  <symbol viewBox={viewBox}
   boundingBox="#{-(size+edgeStroke)/2} #{-edgeStroke/2} #{size+edgeStroke} #{edgeStroke}">
    <line x1={-size/2} x2={size/2} stroke={edgeColor} stroke-width={edgeStroke}
     marker-start={start} marker-end={end}/>
  </symbol>
vertical = (start, end) ->
  <symbol viewBox={viewBox}
   boundingBox="#{-edgeStroke/2} #{-(size+edgeStroke)/2} #{edgeStroke} #{size+edgeStroke}">
    <line y1={-size/2} y2={size/2} stroke={edgeColor} stroke-width={edgeStroke}
     marker-start={start} marker-end={end}/>
  </symbol>

'': blank
' ': blank
O: vertex
o: vertex
'-': horizontal()
'|': vertical()
'<': horizontal arrow, null
'>': horizontal null, arrow
'^': vertical arrow, null
'v': vertical null, arrow
'.': ->  # connecting turn between -s and |s
  <symbol viewBox={viewBox} boundingBox="#{-edgeStroke/2} #{-edgeStroke/2} #{edgeStroke} #{edgeStroke}">
    <circle r={edgeStroke/2} fill={edgeColor}/>
    {if @neighbor(-1, 0).includes '-'
      <line x1={-size/2} stroke={edgeColor} stroke-width={edgeStroke}/>
    }
    {if @neighbor(+1, 0).includes '-'
      <line x2={+size/2} stroke={edgeColor} stroke-width={edgeStroke}/>
    }
    {if @neighbor(0, -1).includes '|'
      <line y1={-size/2} stroke={edgeColor} stroke-width={edgeStroke}/>
    }
    {if @neighbor(0, +1).includes '|'
      <line y2={+size/2} stroke={edgeColor} stroke-width={edgeStroke}/>
    }
  </symbol>
