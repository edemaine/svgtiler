# SVG Tiler
**SVG Tiler** is a tool for drawing diagrams on a grid using text or
spreadsheets, and then substituting SVG symbols to make a big SVG figure,
and optionally convert it to PDF.

To use SVG Tiler, you combine two types of files
(possibly multiple of each type):

1. A **mapping file** specifies how to map symbol names (strings) to
   SVG content (either embedded in the same file or in separate files).
   Mapping files can be specified in a simple ASCII format, or
   as a dynamic mapping defined by JavaScript or CoffeeScript code.
   
2. A **drawing file** specifies a grid of symbol names (strings) which,
   combined with one or more mapping files to define the SVG associated
   with each symbol, compile to a single (tiled) SVG.
   Drawing files can be specified as ASCII art (where each symbol is
   limited to a single character), space-separated ASCII art
   (where symbols are separated by whitespace), or standard CSV/TSV
   formats such as those exported by Google Sheets or Excel.

These input files are listed on the `svgtiler` command line,
with mapping files typically before drawing files.
File types and formats are distinguished automatically by their extension.
For example:

```
svgtiler map1.txt map2.coffee drawing.asc drawings.xls
```

will generate drawing.svg using the mappings in `map1.txt` and `map2.coffee`,
and will generate `drawings_<sheet>.svg` for each sheet in `drawings.xlsx`.

## Mapping Files: .txt, .js, .coffee

In the **.txt format** for mapping files, each line consists of a symbol name
(either having no spaces, or consisting entirely of a single space),
followed by whitespace, followed by either a block of SVG code
(such as `<symbol viewBox="...">...</symbol>`) or a filename containing
such a block.  For example, here is a mapping of `O` to black squares
and both ` ` (space) and empty string to blank squares, all dimensioned
50 &times; 50:

```
O <symbol viewBox="0 0 50 50"><rect width="50" height="50"/></symbol>
  <symbol viewBox="0 0 50 50"></symbol>
 <symbol viewBox="0 0 50 50"></symbol>
```

Here is a mapping of the same symbols to external files:

```
O O.svg
  blank.svg
 blank.svg
```

In the **.js / .coffee formats**, the file consists of JavaScript /
CoffeeScript code, the last line of which should evaluate to either

1. an *object* whose keys are symbol names, or
2. a *function* in one argument, a symbol name (string).
   (This feature allows you to parse symbol names how you want; or check an
    object for a matching key but use a default value otherwise; etc.).

The object or function should map a symbol name to either

1. a string of SVG code (detected by the presence of a `<` character),
2. a filename with `.svg` extension containing SVG code,
2. a filename with `.png`, `.jpg`, `.jpeg`, or `.gif` extension
   containing an image, or
3. a function returning one of the above.

In the last case, the function is called *for each occurrence of the symbol*,
and has `this` bound to a manufactured `Context` object, giving you access to
the following properties:

* `this.key` is the symbol name, or `null` if the `Context` is out of bounds
  of the drawing;
* `this.includes(substring)` computes whether `this.key` contains the given
  `substring` (as would `this.key.includes(substring)` in ECMAScript 2015).
* `this.i` is the row number of the cell of this symbol occurrence (starting
  at 0);
* `this.j` is the column number of the cell of this symbol occurrence
  (starting at 0);
* `this.neighbor(dj, di)` returns a new `Context` for row `i + di` and
  column `j + dj`.  (Note the reversal of coordinates, so that the order
  passed to `neighbor` corresponds to *x* then *y* coordinate.)
  If there is no symbol at that position, you will still get a `Context`
  whose `key` value is `null` and whose `includes()` always returns `false`.
* In particular, it's really useful to call e.g.
  `this.neighbor(1, 0).includes('-')` to check for adjacent symbols that
  change how this symbol should be rendered.
* `this.row(di = 0)` returns an array of `Context` objects, one for each
  symbol in row `i + di` (in particular, including `this` if `di` is the
  default of `0`).  For example, you can use the `some` or `every` methods
  on this array to do bulk tests on the row.
* `this.column(dj = 0)` returns an array of `Context` objects, one for each
  symbol in column `j + dj`.

## Drawing Files: .asc, .ssv, .csv, .tsv, .xlsx, .xls, .ods

The **.asc format** for drawing files represents traditional ASCII art:
each non-newline character represents a one-character symbol name.
For example, here is a simple 5 &times; 5 ASCII drawing using symbols
`O` and ` ` (space):

```
 OOO
O O O
OOOOO
O   O
 OOO
```

The **.ssv, .csv, and .tsv formats** use
[delimiter-separated values (DSV)](https://en.wikipedia.org/wiki/Delimiter-separated_values)
to specify an array of symbol names.  In particular,
[.csv (comma-separated)](https://en.wikipedia.org/wiki/Comma-separated_values)
and
[.tsv (tab-separated)](https://en.wikipedia.org/wiki/Tab-separated_values)
formats are exactly those exported by spreadsheet software such as
Google Drive or Excel, enabling you to draw in that software.
The .ssv format is similar, but where the delimiter between symbol names
is arbitrary whitespace.
(Contrast this behavior with .csv which treats every comma as a delimiter.)
This format is nice to work with in a text editor, allowing you to line up
the columns by padding symbol names with extra spaces.
All three formats support quoting according to the usual DSV rules:
any symbol name (in particular, if it has a delimiter or double quote in it)
can be put in double quotes, and double quotes can be produced in the
symbol name by putting `""` (two double quotes) within the quoted string.
Thus, the one-character symbol name `"` would be represented by `""""`.

The **.xlsx, .xlsm, .xlsb, .xls** (Microsoft Excel),
**.ods, .fods** (OpenDocument), **.dif** (Data Interchange Format),
**.prn** (Lotus), and **.dbf** (dBASE/FoxPro) formats support data straight
from spreadsheet software.  This format is special in that it supports
multiple sheets in one file.  In this case, the output SVG files have
filenames distinguished by an underscore followed by the sheet name.

## Layout Algorithm

Given one or more mapping files and a drawing file, SVG Tiler follows a fairly
simple layout algorithm to place the SVG expansions of the symbols into a
single SVG output.  Each symbol has a bounding box, either specified by
the `viewBox` of the root element, or automatically computed.
The algorithm places symbols in a single row to align their top edges,
with no horizontal space between them.
The algorithm places rows to align their left edges so that the rows' bounding
boxes touch, with the bottom of one row's bounding box equalling the top of
the next row's bounding box.

This layout algorithm works well if each row has a uniform height and each
column has a uniform width, even if different rows have different heights
and different columns have different widths.  But it probably isn't what you
want if symbols have wildly differing widths or heights, so you should set
your `viewBox`es accordingly.

## Additional Features

* Each unique symbols gets defined just once (via SVG's `<symbol>`) and
  then instantiated (via SVG's `<use>`) many times,
  resulting in relatively small and efficient SVG outputs.

* [z-index](https://svgwg.org/svg2-draft/render.html#ZIndexProperty)
  support on symbols defined by mapping files, even though output is
  SVG 1.1 (which does not support z-index): symbol uses get re-ordered to
  simulate the correct z order.  For example,
  `<symbol viewBox="0 0 10 10" style="z-index: 2">...</symbol>`
  will be rendered on top of (later than) all symbols without a
  `style="z-index:..."` specification (which default to a z-index of 0).

* Symbols can draw beyond their `viewBox` via `style="overflow: visible"`
  (as in normal SVG).  Furthermore, the `viewBox` of the overall output
  drawing can still be computed correctly (larger than the bounding box
  of the symbol `viewBox`es) via a special `overflowBox` attribute.
  For example,
  `<symbol viewBox="0 0 10 10" overflowBox="-5 -5 20 20" style="overflow: visible">...</symbol>`
  defines a symbol that gets laid out as if it occupies the [0, 10] &times;
  [0, 10] square, but the symbol can draw outside that square, and the overall
  drawing bounding box will be set as if the symbol occupies the
  [&minus;5, 15] &times; [&minus;5, 15] square.
  Even zero-width and zero-height symbols will get rendered when
  `style="overflow: visible"` is specified, by overriding `viewBox`.

* Very limited automatic `viewBox` setting via bounding box computation
  (but see the code for many SVG features not supported).
  For example, the SVG
  `<rect x="-5" y="-5" width="10" height="10"/>`
  will create a symbol with `viewBox="-5 -5 10 10"`.

* You can automatically convert all exported SVG files into PDF and/or PNG
  if you have Inkscape installed, via the `-p`/`--pdf` and/or `-P` or `--png`
  command-line options.
  For example: `svgtiler -p map.coffee drawings.xls`
  will both `drawings_sheet.svg` and `drawings_sheet.pdf`.
  PNG conversion is intended for pixel art; see the
  [examples/tetris/](Tetris example).

* You can speed up Inkscape conversions process on a multithreaded CPU via the
  `-j`/`--jobs`
  command-line option.
  For example, `svgtiler -j 4 -p map.coffee drawings.xls`
  will run up to four Inkscape jobs at once.

## Installation
After [installing Node](https://nodejs.org/en/download/),
you can install this tool via

    npm install -g svgtiler

## Command-Line Usage

The command-line arguments consist mostly of mapping and/or drawing files.
The files and other arguments are processed *in order*, so for example a
drawing can use all mapping files specified *before* it on the command line.
If the same symbol is defined by multiple mapping files, later mappings take
precedence (overwriting previous mappings).

Here is the output of `svgtiler --help`:

```
Usage: svgtiler (...options and filenames...)

Optional arguments:
  --help                Show this help message and exit.
  -m / --margin         Don't delete blank extreme rows/columns
  --hidden              Process hidden sheets within spreadsheet files
  --tw TILE_WIDTH / --tile-width TILE_WIDTH
                        Force all symbol tiles to have specified width
  --th TILE_HEIGHT / --tile-height TILE_HEIGHT
                        Force all symbol tiles to have specified height
  -p / --pdf            Convert output SVG files to PDF via Inkscape
  -P / --png            Convert output SVG files to PNG via Inkscape
  --no-sanitize         Don't sanitize PDF output by blanking out /CreationDate
  -j N / --jobs N       Run up to N Inkscape jobs in parallel

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
  *.xlsx       Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)
  *.xlsm       Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)
  *.xlsb       Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)
  *.xls        Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)
  *.ods        Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)
  *.fods       Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)
  *.dif        Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)
  *.prn        Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)
  *.dbf        Spreadsheet drawing(s) (Excel/OpenDocument/Lotus/dBASE)

SYMBOL specifiers:  (omit the quotes in anything except .js and .coffee files)

  'filename.svg':   load SVG from specifies file
  'filename.png':   include PNG image from specified file
  'filename.jpg':   include JPEG image from specified file
  '<svg>...</svg>': raw SVG
  -> ...@key...:    function computing SVG, with `this` bound to Context with
                    `key` set to symbol name, `i` and `j` set to coordinates,
                    and supporting `neighbor` and `includes` methods.
```

## About

This take on SVG Tiler was written by Erik Demaine, in discussions with
Jeffrey Bosboom and others, with the intent of subsuming his
[original SVG Tiler](https://github.com/jbosboom/svg-tiler).
In particular, the .txt mapping format and .asc drawing format here
are nearly identical to the formats supported by the original.
