# CSS Animation Example

## Input:

* [CSS style sheet](css-anim.css) defines classes:
  * `light` and `dark` for coloring
  * `pulse` for CSS animation
* [CoffeeScript mapping file](shapes.coffee)
* [CSV data](css-anim.csv)

  | 0 | 1 | 2 | 3 | 4 |
  | ------ | ------ | ------ | ------ | ------ |
  | circle | circle light | circle dark | circle light pulse | circle dark pulse |
  | square | square light | square dark | square light pulse | square dark pulse |
  | triangle | triangle light | triangle dark | triangle light pulse | triangle dark pulse |

## Output:

[SVG](css-anim.svg)

![](css-anim.svg)
