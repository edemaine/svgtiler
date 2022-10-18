# Test svgtiler.Mappings being provided as mapping values

export map1 = new svgtiler.Mapping (key) ->
  <symbol width="50" height="50" boundingBox="-3 -3 56 56"
   z-index={if key == 'purple' then 1}>
    <rect width="50" height="50" stroke={key} stroke-width="6" fill="gray"/>
  </symbol>

export map2 = (key) ->
  <symbol viewBox="-25 -25 50 50" z-index="2">
    <circle r="17" fill={key}/>
  </symbol>

export default new svgtiler.Mapping -> [
  map1
  map2
]
