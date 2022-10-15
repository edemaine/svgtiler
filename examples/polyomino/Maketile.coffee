langs = ['cjsx', 'jsx', 'coffee']

for lang in langs
  exports[lang] = do (lang) -> ->
    svgtiler "-f outlines.#{lang} *.asc"

export default ->
  for lang in langs
    exports[lang]()
