# svgtiler
SVG Tiler is a tool for drawing diagrams on a grid using text or spreadsheets,
and then substituting SVG symbols to make a big SVG figure.

## Installation
After [installing Node](https://nodejs.org/en/download/),
you can install this tool via

    npm install -g svgtiler

## Usage

```
Usage: /usr/bin/nodejs /usr/bin/svgtiler (...options and filenames...)
--help [-h] [-tw TILE_WIDTH] [-th TILE_HEIGHT] ...

Optional arguments:
  --help                Show this help message and exit.
  --tw TILE_WIDTH / --tile-width TILE_WIDTH
                        Force all symbol tiles to have specified width
                        (default: null, which means read width from SVG)
  --th TILE_HEIGHT / --tile-height TILE_HEIGHT
                        Force all symbol tiles to have specified height
                        (default: null, which means read height from SVG)

Filename arguments:  (mappings before drawings!)

  *.txt        ASCII mapping file
               Each line is <symbol-name><space><raw SVG or filename.svg>
  *.js         JavaScript mapping file
               Object mapping symbol names to SYMBOL e.g. dot: 'dot.svg'
  *.coffee     CoffeeScript mapping file
               Object mapping symbol names to SYMBOL e.g. dot: 'dot.svg'
  *.asc        ASCII drawing (one character per symbol)
  *.ssv        Space-delimiter drawing (one word per symbol)
  *.csv        Comma-separated drawing (spreadsheet export)
  *.tsv        Tab-separated drawing (spreadsheet export)

SYMBOL specifiers:

  'filename.svg':   load SVG from specifies file
  '<svg>...</svg>': raw SVG
  (context) -> ...: function computing SVG
```
