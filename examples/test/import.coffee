imported = require './imported.svg'

# Check that <style> contents preserved (roughly) verbatim.
# In particular, that braces don't get treated like JSX.
style = imported.props.children.find (child) => child?.type == 'style'
unless style?.props.children == \
       '@media (min-width: 0px) { #imported_tile[data-kind="{tile}"] > rect { fill: url(#imported_paint); } }'
  throw new Error 'Wrong imported <style> contents'

# Check raw vs. processed SVG strings.
unless imported.raw.includes('id="tile"') and
       imported.svg.includes('id="imported_tile"') and
       imported.svg.includes('stroke="url(#imported_outline)"') and
       imported.svg.includes('fill="white">url(#paint)</text>')
  throw new Error 'Wrong imported SVG strings'

(key) -> imported
