# Supported rules: css (default), styl

(lang) ->
  lang = 'css' unless lang
  svgtiler """
    -f css-anim.#{lang}
    ( shapes.coffee css-anim.csv )
    ( ascii.coffee ascii.asc )
  """
