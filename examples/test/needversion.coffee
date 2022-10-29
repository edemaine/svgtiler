svgtiler.needVersion '>=1'
try
  svgtiler.needVersion '<1'
catch e
  if e instanceof svgtiler.SVGTilerError
    console.log "Success! #{e}"
  else
    throw e
