palette = tiles = null

export init = ->
  palette = share.palette ? 'overworld'
  console.log "Using Mario #{palette} palette"

  tiles =
    '': <symbol viewBox="0 0 16 16"/>
    blank: <symbol viewBox="0 0 16 16"/>

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
    goomba: <symbol viewBox="0 0 16 16" z-index="1"><image y="1" xlink:href="goomba_#{palette}.png"/></symbol>
    spiny_left: <symbol viewBox="0 0 16 16" z-index="1"><image y="1" xlink:href="spiny_left.png"/></symbol>
    spiny_right: <symbol viewBox="0 0 16 16" z-index="1"><image y="1" xlink:href="spiny_right.png"/></symbol>

    # Items
    "1up": <symbol viewBox="0 0 16 16"><image xlink:href="1up_#{palette}.png"/></symbol>
    flower: <symbol viewBox="0 0 16 16"><image xlink:href="flower.png"/></symbol>
    mushroom: <symbol viewBox="0 0 16 16"><image xlink:href="mushroom.png"/></symbol>
    star: <symbol viewBox="0 0 16 16"><image xlink:href="star.png"/></symbol>

export preprocess = ->
  svgtiler.background(
    switch palette
      when 'castle'      then 'black'
      when 'overworld'   then '#6b8cff'
      when 'underground' then 'black'
      when 'underwater'  then '#0059ff'
  )

export map = (key) ->
  ### Keys:
  "a,b" expands to the equivalent of a beneath b
  "a+x+y" expands to a shifted by (x, y)
  For negative offsets, use "-" in place of "+"
  Add "*6" for six offset copies, starting with 0 (for fire bars)
  ###
  for subkey in key.split ','
    subkey = subkey.trim()
    if match = /^(.*?)([+-]\d+)([+-]\d+)?(\*\d+)?$/.exec subkey
      subkey = match[1]
      offsetX = parseInt match[2], 10
      offsetY = if match[3] then parseInt match[3], 10 else 0
      range = if match[4] then [0...parseInt match[4][1..], 10] else [1]
    else
      offsetX = offsetY = 0
      range = null
    tile = tiles[subkey]
    unless tile?
      console.warn "Unrecognized tile key: #{subkey}"
      continue
    if offsetX or offsetY or (range? and (range.length != 1 or range[0] != 1))
      ## Translate tile's children by wrapping in a <g transform>
      <symbol {...tile.props}>
        {for mult in range
          <g transform={"translate(#{mult * offsetX},#{mult * offsetY})"}>
            {tile.props.children}
          </g>
        }
      </symbol>
    else
      tile
