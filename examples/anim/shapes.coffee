###
Supports keys of the form "shape class class ..."
where "shape" is one of "circle" or "square" or "triangle",
and "class" are CSS classes.
###

export shapes =
  circle: (attrs) ->
    <symbol viewBox="-50 -50 100 100">
      <circle {...attrs} r="40"/>
    </symbol>
  square: (attrs) ->
    <symbol viewBox="-10 -10 100 100">
      <rect {...attrs} width="80" height="80"/>
    </symbol>
  triangle: (attrs) ->
    r = 45
    coords =
      for i in [0...3]
        [r * Math.cos (i/3+1/12) * Math.PI*2
         r * Math.sin (i/3+1/12) * Math.PI*2]
    <symbol viewBox="-50 -50 100 100">
      <path {...attrs} d={'M' + coords.join('L') + 'Z'}/>
    </symbol>

(key) ->
  [shape, classes...] = key.split /\s+/
  attrs = class: classes.join ' '
  # SVG parser complains about empty class attribute
  delete attrs.class unless attrs.class
  shapes[shape] attrs
