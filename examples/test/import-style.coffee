imported = require './imported-style.svg'

# Check that <style> contents preserved (roughly) verbatim.
# In particular, that braces don't get treated like JSX.
style = imported.props.children.find (child) => child?.type == 'style'
unless style?.props.children == \
       '@media (min-width: 0px) { [data-kind="{tile}"] > rect { fill: red; } }'
  throw new Error 'Wrong imported <style> contents'

(key) -> imported
