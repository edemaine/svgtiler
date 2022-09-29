size = 45  # width and height of svg files

# checkerboard backgrounds
light = null
dark = <path stroke="#000" d="M 7.5,0 L 0,7.5 M 15,0 L 0,15 M 22.5,0 L 0,22.5 M 30,0 L 0,30 M 37.5,0 L 0,37.5 M 45,0 L 0,45 M 45,7.5 L 7.5,45 M 45,15 L 15,45 M 45,22.5 L 22.5,45 M 45,30 L 30,45 M 45,37.5 L 37.5,45"/>
background = ->
  <symbol width={size} height={size} z-index="-1">
    {if (@i + @j) % 2 == 0
      light
    else
      dark
    }
  </symbol>

read = (filename) ->
  dom = require filename
  ## Alternative: Strip off top level <svg>...</svg> and wrap in <symbol>
  #console.assert dom.type == 'svg'
  #<symbol width={size} height={size}">
  #  {dom.props.children}
  #</symbol>

svgtiler.beforeRender ({drawing}) ->
  svgtiler.add <title z-index="-Infinity">Chess diagram {drawing.filename}</title>

svgtiler.background 'white'
## Equivalent:
#svgtiler.afterRender (render) -> render.add \
#  <rect fill="white" z-index="-Infinity"
#   x={render.xMin} y={render.yMin} width={render.width} height={render.height}/>

[
  background
  (key) ->
    # Map blanks to empty string
    key = key.trim()
    key = '' if key == '.'
    piece = key.toLowerCase()
    if key
      read "./Chess_#{piece}#{if piece == key then "d" else "l"}t45.svg"
]
