# svgtiler
**SVG Tiler** is a tool for drawing diagrams on a grid using text or
spreadsheets, and then substituting SVG symbols to make a big SVG figure.

To use SVG Tiler, you combine two types of files
(possibly multiple of each type):

1. A **mapping file** specifies how to map symbol names (strings) to
   SVG content (either embedded in the same file or in separate files).
   Mapping files can be specified in a simple ASCII format, or
   as a dynamic mapping defined by JavaScript or CoffeeScript code.
   
2. A **drawing file** specifies a grid of symbols (strings) which,
   combined with one or more mapping files to define the SVG associated
   with each symbol, compile to a single (tiled) SVG.
   Drawing files can be specified as ASCII art (where each symbol is
   limited to a single character), space-separated ASCII art
   (where symbols are separated by whitespace), or standard CSV/TSV
   formats such as those exported by Google Sheets or Excel.

File types and formats are distinguished automatically by their extension.

## Mapping Files

In the **.txt format** for mapping files, each line consists of a symbol name
(either having no spaces, or consisting entirely of a single space),
followed by whitespace, followed by either a block of SVG code
(such as `<symbol viewBox="...">...</symbol>`) or a filename containing
such a block.  For example, here is a mapping of `O` to black squares
and ` ` (space) to blank squares, both dimensioned 50 &times; 50:

```
O <symbol viewBox="0 0 50 50"><rect width="50" height="50"/></symbol>
  <symbol viewBox="0 0 50 50"></symbol>
```

In the **.js / .coffee formats**, the file consists of JavaScript /
CoffeeScript code, the last line of which should evaluate to either

1. an *object* whose keys are symbol names, or
2. a *function* taking a symbol name (string) as input
   (allowing you to parse symbol names how you want, or check an object
    for a match but use a default value otherwise, etc.).

The object or function should map a symbol name to either

1. a string of SVG code (detected by the presense of a `<` character),
2. a filename containing SVG code, or
3. a function returning one of the above.

In the last case, the function is called for *each occurrence of the symbol*,
and has `this` bound to a manufactured `Context` object, giving you access to
the following properties:

* `this.key` is the symbol name, or `null` if the `Context` is out of bounds;
* `this.includes(substring)` computes whether `this.key` includes `substring`
  as a substring (as would `this.key.includes(substring)` in ECMAScript 2015).
* `this.i` is the row number of the cell of this symbol occurrence (starting
  at 0);
* `this.j` is the column number of the cell of this symbol occurrence
  (starting at 0);
* `this.neighbor(dj, di)` returns a new `Context` for row `i + di` and
  column `j + dj`.  (Note the reversal of coordinates, so that the order
  passed to `neighbor` corresponds to *x* then *y* coordinate.)
  If there is no symbol at that position, you will still get a `Context`
  supporting `includes`, but the `key` value will be `null`.
* In particular, it's really useful to check e.g.
  `this.neighbor(1, 0).includes('-')` to check for adjacent symbols that
  change how this symbol should be rendered.

## Drawing Files

The **.asc format** for drawing files represents traditional ASCII art:
each non-newline character represents a one-character symbol name.
For example, here is a simple 5 &times; 5 ASCII drawing using symbols
`X` and ` ` (space):

```
 XXX
X X X
XXXXX
X   X
 XXX
```

The **.ssv, .csv, and .tsv formats** use
[delimeter-separated values (DSV)](https://en.wikipedia.org/wiki/Delimiter-separated_values)
to specify an array of symbol names.  In particular,
[.csv (comma-separated)](https://en.wikipedia.org/wiki/Comma-separated_values)
and
[.tsv (tab-separated)](https://en.wikipedia.org/wiki/Tab-separated_values)
formats are exactly those exported by spreadsheet software such as
Google Drive or Excel, enabling drawing in that software.
The .ssv format is similar, but where the delimeter between symbol names
is an arbitrary string of whitespace.
(Compare this behavior with .csv which treats every comma as a delimeter.)
This format is nice to work with in a text editor, lining up the columns
by padding symbol names with extra spaces.

All three formats support quoting according to the usual rules:
any symbol name (in particular, if it has a delimeter or double quote in it)
can be put in double quotes, and double quotes can be produced in the
symbol name by putting `""` (two double quotes) within the quoted string.
Thus, the one-character symbol name `"` would be represented by `""""`.




## Additional Features

* Re-uses repeated symbols in the drawing via SVG's `<symbol>` and `<use>`,
  leading to relatively small and efficient SVG outputs.

* z-index support on symbols defined by mapping files, even though
  output is SVG 1.1: symbols get re-ordered to implement z order.
  `<symbol viewBox="0 0 10 10" overflowBox="-5 -5 20 20" style="overflow: visible; z-index: 2">`

* Symbols can draw beyond their `viewBox`, and overall `viewBox` of the
  output drawing can still be set correctly (larger than the bounding box
  of the symbol `viewBox`es) via a special `overflowBox` attribute.
  For example,
  `<symbol viewBox="0 0 10 10" overflowBox="-10 -5 30 20" style="overflow: visible">...</symbol>`
  defines a symbol that gets laid out as if it occupies the [0, 10] &times;
  [0, 10] square, but can draw outside that square, and the overall drawing
  bounding box will be set as if the symbol occupies the [&minus;10, 20]
  &times; [&minus;5, 15] rectangle.

* Very limited automatic `viewBox` setting via bounding box computation
  (but see code for many SVG features not supported).
  For example, the SVG
  `<rect x="-5" y="-5" width="10" height="10"/>`
  will create a symbol with `viewBox="-5 -5 10 10"`.

## Installation
After [installing Node](https://nodejs.org/en/download/),
you can install this tool via

    npm install -g svgtiler

## Usage

```
Usage: svgtiler (...options and filenames...)

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

## About

This take on SVG Tiler was written by Erik Demaine, in discussions with
Jeffrey Bosboom and others, with the intent of subsuming his
[original SVG Tiler](https://github.com/jbosboom/svg-tiler).
In particular, the .txt mapping format and .asc drawing format here
are nearly identical to the formats supported by the original.
