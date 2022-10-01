palette = background = map = null

svgtiler.onInit ->
  palette = share.palette ? 'overworld'
  console.log "Using Mario #{palette} palette"

  background =
    switch palette
      when 'castle'      then 'black'
      when 'overworld'   then '#6b8cff'
      when 'underground' then 'black'
      when 'underwater'  then '#0059ff'

  map =
    '': <symbol viewBox="0 0 16 16">
          <rect width="16" height="16" fill={background}/>
        </symbol>

    # Environment
    # These are <symbol>s instead of filename strings to enable building below.
    brick: <symbol viewBox="0 0 16 16"><image xlink:href="brick_#{palette}.png"/></symbol>
    brick_lit: <symbol viewBox="0 0 16 16"><image xlink:href="brick_lit_#{palette}.png"/></symbol>
    question: <symbol viewBox="0 0 16 16"><image xlink:href="question_#{palette}.png"/></symbol>
    question_used: <symbol viewBox="0 0 16 16"><image xlink:href="question_used_#{palette}.png"/></symbol>
    raised: <symbol viewBox="0 0 16 16"><image xlink:href="raised_#{palette}.png"/></symbol>
    rock: <symbol viewBox="0 0 16 16"><image xlink:href="rock_#{palette}.png"/></symbol>
    fire_nw: <symbol viewBox="0 0 16 16"><image xlink:href="fire_nw.png"/></symbol>
    fire_ne: <symbol viewBox="0 0 16 16"><image xlink:href="fire_ne.png"/></symbol>
    fire_sw: <symbol viewBox="0 0 16 16"><image xlink:href="fire_sw.png"/></symbol>
    fire_se: <symbol viewBox="0 0 16 16"><image xlink:href="fire_se.png"/></symbol>

    # Players
    mario_small_left: <symbol viewBox="0 0 16 16" z-index="2"><image y="1" xlink:href="mario_small_left.png"/></symbol>
    mario_small_right: <symbol viewBox="0 0 16 16" z-index="2"><image y="1" xlink:href="mario_small_right.png"/></symbol>
    mario_large_left: <symbol viewBox="0 0 16 16" z-index="2"><image y="-15" xlink:href="mario_large_left.png"/></symbol>
    mario_large_right: <symbol viewBox="0 0 16 16" z-index="2"><image y="-15" xlink:href="mario_large_right.png"/></symbol>
    luigi_small_left: <symbol viewBox="0 0 16 16" z-index="2"><image y="1" xlink:href="luigi_small_left.png"/></symbol>
    luigi_small_right: <symbol viewBox="0 0 16 16" z-index="2"><image y="1" xlink:href="luigi_small_right.png"/></symbol>
    luigi_large_left: <symbol viewBox="0 0 16 16" z-index="2"><image y="-15" xlink:href="luigi_large_left.png"/></symbol>
    luigi_large_right: <symbol viewBox="0 0 16 16" z-index="2"><image y="-15" xlink:href="luigi_large_right.png"/></symbol>

    # Enemies
    goomba: <symbol viewBox="0 0 16 16" z-index="1"><image y="1" xlink:href={"goomba_#{palette}".png}/></symbol>
    spiny_left: <symbol viewBox="0 0 16 16" z-index="1"><image y="1" xlink:href="spiny_left.png"/></symbol>
    spiny_right: <symbol viewBox="0 0 16 16" z-index="1"><image y="1" xlink:href="spiny_right.png"/></symbol>

export default build = (key) ->
  ### Keys:
  "a,b" expands to the equivalent of a beneath b
  "a+x+y" expands to a shifted by (x, y)
  For negative offsets, use "-" in place of "+"
  ###
  key = key.trim()
  if ',' in key
    tiles =
      for subkey in key.split ','
        build subkey
    zIndex = Math.max ...(
      for tile in tiles
        tile.props['z-index'] ? 0
    )
    <symbol viewBox="0 0 16 16" z-index={zIndex or null}>
      {for subkey in key.split ','
        tile = build subkey
        if tile?
          tile.props?.children
        else
          console.warn "Unrecognized subtitle '#{subkey}'"
      }
    </symbol>
  else if match = /^(.*?)([+-]\d+)([+-]\d+)?$/.exec key
    tile = map[match[1]]
    offsetX = parseInt match[2]
    offsetY = parseInt (match[3] ? '0')
    return unless tile?
    <symbol {...tile.props}>
      <g transform={"translate(#{offsetX},#{offsetY})"}>
        {tile.props.children}
      </g>
    </symbol>
  else
    map[key]
