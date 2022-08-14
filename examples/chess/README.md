# Chess Boards

## Drawings

| Rendering | Repo Files | Source |
|-----------|------------|--------|
| ![Initial chessboard](board-init.svg) | [ASCII input](board-init.asc)<br>[SVG output](board-init.svg) | [Wikipedia: Chess](https://en.wikipedia.org/wiki/Chess) |
| ![Immortal Game chessboard](board-immortal.svg) | [ASCII input](board-immortal.asc)<br>[SVG output](board-immortal.svg) | [Wikipedia: Immortal Game](https://en.wikipedia.org/wiki/Immortal_Game) (last position) |

## Mapping

* [CoffeeScript mapping file](map.coffee) and equivalent
  [JavaScript mapping file](map.jsx), illustrating:
  * Computing the square parity to automatically shade dark squares
  * Using `require` to load and modify external SVG files
    (strip off unnecessary `<svg>` wrapper)
  * JSX notation for creating and composing symbols

## Piece Shapes

Piece shapes are defined by unmodified SVGs from
[Wikimedia's Standard chess diagrams](https://commons.wikimedia.org/wiki/Standard_chess_diagram),
authored by [Cburnett](https://commons.wikimedia.org/wiki/User:Cburnett)
(Colin M.L. Burnett)
and licensed under [BSD license](https://opensource.org/licenses/BSD-3-Clause)
(among other licenses).

| Image | Repo file | Wikimedia link |
|-------|-----------|----------------|
| ![](Chess_bdt45.svg) | [Chess_bdt45.svg](Chess_bdt45.svg) | [Chess_bdt45.svg](https://commons.wikimedia.org/wiki/File:Chess_bdt45.svg) |
| ![](Chess_blt45.svg) | [Chess_blt45.svg](Chess_blt45.svg) | [Chess_blt45.svg](https://commons.wikimedia.org/wiki/File:Chess_blt45.svg) |
| ![](Chess_kdt45.svg) | [Chess_kdt45.svg](Chess_kdt45.svg) | [Chess_kdt45.svg](https://commons.wikimedia.org/wiki/File:Chess_kdt45.svg) |
| ![](Chess_klt45.svg) | [Chess_klt45.svg](Chess_klt45.svg) | [Chess_klt45.svg](https://commons.wikimedia.org/wiki/File:Chess_klt45.svg) |
| ![](Chess_ndt45.svg) | [Chess_ndt45.svg](Chess_ndt45.svg) | [Chess_ndt45.svg](https://commons.wikimedia.org/wiki/File:Chess_ndt45.svg) |
| ![](Chess_nlt45.svg) | [Chess_nlt45.svg](Chess_nlt45.svg) | [Chess_nlt45.svg](https://commons.wikimedia.org/wiki/File:Chess_nlt45.svg) |
| ![](Chess_pdt45.svg) | [Chess_pdt45.svg](Chess_pdt45.svg) | [Chess_pdt45.svg](https://commons.wikimedia.org/wiki/File:Chess_pdt45.svg) |
| ![](Chess_plt45.svg) | [Chess_plt45.svg](Chess_plt45.svg) | [Chess_plt45.svg](https://commons.wikimedia.org/wiki/File:Chess_plt45.svg) |
| ![](Chess_qdt45.svg) | [Chess_qdt45.svg](Chess_qdt45.svg) | [Chess_qdt45.svg](https://commons.wikimedia.org/wiki/File:Chess_qdt45.svg) |
| ![](Chess_qlt45.svg) | [Chess_qlt45.svg](Chess_qlt45.svg) | [Chess_qlt45.svg](https://commons.wikimedia.org/wiki/File:Chess_qlt45.svg) |
| ![](Chess_rdt45.svg) | [Chess_rdt45.svg](Chess_rdt45.svg) | [Chess_rdt45.svg](https://commons.wikimedia.org/wiki/File:Chess_rdt45.svg) |
| ![](Chess_rlt45.svg) | [Chess_rlt45.svg](Chess_rlt45.svg) | [Chess_rlt45.svg](https://commons.wikimedia.org/wiki/File:Chess_rlt45.svg) |
