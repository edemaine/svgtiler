# Render piece attack graph

size = 45  # width and height of svg files

graphs = share.graphs ? 'knprbq'  # which piece attack graphs to draw
friendly = share.friendly ? false  # include friendly fire attacks?
graphColor = 'hsl(286,65%,50%,70%)'
pieces = new Set ['k', 'n', 'p', 'r', 'b', 'q']
pieces.add lc.toUpperCase() for lc in (x for x from pieces)

player = (key) ->
  key == key.toLowerCase()

svgtiler.afterRender (render) ->
  {drawing} = render
  edges = []
  for row, y in drawing.keys
    for key, x in row
      p1 = player key
      key = key.toLowerCase()
      continue unless graphs.includes key

      longMove = (dx, dy) ->
        x2 = x + dx
        y2 = y + dy
        while (neighbor = drawing.get x2, y2)?
          return [x2, y2] if pieces.has neighbor
          x2 += dx
          y2 += dy
        return null # no piece found

      switch key
        when 'k'
          neighbors = [[x-1, y+1], [x, y+1], [x+1, y], [x+1, y+1]]
        when 'n'
          neighbors = [[x-2, y+1], [x-1, y+2], [x+1, y+2], [x+2, y+1]]
        when 'p'
          neighbors = [[x-1, y+1], [x+1, y+1]]
        when 'r'
          neighbors = [
            longMove +1, 0
            longMove 0, +1
          ]
        when 'b'
          neighbors = [
            longMove +1, +1
            longMove -1, +1
          ]
        when 'q'
          neighbors = [
            longMove +1, 0
            longMove 0, +1
            longMove +1, +1
            longMove -1, +1
          ]
        else
          console.warn "Unknown piece type for graph: #{graph}"
          continue

      for neighbor in neighbors when neighbor?
        [x2, y2] = neighbor
        key2 = drawing.get x2, y2
        continue unless pieces.has key2
        p2 = player key2
        continue unless friendly or p1 != p2
        edges.push \
          <line x1={x * size + size/2}
                y1={y * size + size/2}
                x2={x2 * size + size/2}
                y2={y2 * size + size/2}
                stroke={graphColor} stroke-width="10" stroke-linecap="round"
          />

  <svg>{edges}</svg>

null
