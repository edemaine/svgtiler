# Supported rules: coffee, txt
# Default `svgtiler` behavior runs all rules.

langs = ['coffee', 'txt']

export make = (lang) ->
  if lang
    svgtiler "-f --tw 50 --th 50 tilt.#{lang} *.asc *.csv"
  else
    svgtiler langs
