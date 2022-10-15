for lang in ['css', 'styl']
  exports[lang] = do (lang) -> ->
    svgtiler """
      -f css-anim.#{lang}
      ( shapes.coffee css-anim.csv )
      ( ascii.coffee ascii.asc )
    """

export default exports.css
