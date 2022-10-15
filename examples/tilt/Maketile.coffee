langs = ['coffee', 'txt']

for lang in langs
  exports[lang] = do (lang) -> ->
    svgtiler "-f --tw 50 --th 50 tilt.#{lang} *.asc *.csv"

export default ->
  for lang in langs
    exports[lang]()
