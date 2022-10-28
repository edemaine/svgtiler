# Supported rules: cjsx, jsx, coffee
# Default `svgtiler` behavior runs all rules.

langs = ['cjsx', 'jsx', 'coffee']

(lang) ->
  if lang
    svgtiler "-f outlines.#{lang} *.asc"
  else
    svgtiler langs
