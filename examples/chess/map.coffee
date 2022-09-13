size = 45  # width and height of svg files

# checkerboard backgrounds
light = null
dark = <path stroke="#000" d="M 7.5,0 L 0,7.5 M 15,0 L 0,15 M 22.5,0 L 0,22.5 M 30,0 L 0,30 M 37.5,0 L 0,37.5 M 45,0 L 0,45 M 45,7.5 L 7.5,45 M 45,15 L 15,45 M 45,22.5 L 22.5,45 M 45,30 L 30,45 M 45,37.5 L 37.5,45"/>

read = (filename) ->
  dom = require filename
  # Strip off top level <svg>...</svg>
  console.assert dom.type == 'svg'
  dom.props.children

svgtiler.afterRender (render) ->
  <rect fill="white" z-index="-1"
   x={render.xMin} y={render.yMin} width={render.width} height={render.height}/>

(key) ->
  # Map blanks to empty string
  key = key.trim()
  key = '' if key == '.'
  piece = key.toLowerCase()
  <symbol viewBox="0 0 #{size} #{size}">
    {if (@i + @j) % 2 == 0
      light
    else
      dark
    }
    {if key.trim() and key != '.'
      read "./Chess_#{piece}#{if piece == key then "d" else "l"}t45.svg"
    }
  </symbol>
