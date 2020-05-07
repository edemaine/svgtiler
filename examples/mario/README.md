# Super Mario Bros.

## Input:

* [CoffeeScript mapping file](mario.coffee)
* [JSON file](palette.coffee) to define which "palette" to use
  ("castle", "overworld", "underground", or "underwater")
* Sprites thanks to [The Spriters Resource](https://www.spriters-resource.com/nes/supermariobros/):

  | Palette     | Sprites   |
  | ----------- | --------- |
  | castle      | ![](brick_castle.png) ![](brick_lit_castle.png) ![](brick_used_castle.png) ![](goomba_castle.png) ![](question_castle.png) ![](question_used_castle.png) ![](raised_castle.png) ![](rock_castle.png)
  | overworld   | ![](brick_overworld.png) ![](brick_lit_overworld.png) ![](brick_used_overworld.png) ![](goomba_overworld.png) ![](question_overworld.png) ![](question_used_overworld.png) ![](raised_overworld.png) ![](rock_overworld.png)
  | underground | ![](brick_underground.png) ![](brick_lit_underground.png) ![](brick_used_underground.png) ![](goomba_underground.png) ![](question_underground.png) ![](question_used_underground.png) ![](raised_underground.png) ![](rock_underground.png)
  | underwater  | ![](brick_underwater.png) ![](brick_lit_underwater.png) ![](brick_used_underwater.png) ![](goomba_underwater.png) ![](question_underwater.png) ![](question_used_underwater.png) ![](raised_underwater.png) ![](rock_underwater.png)
  | (general)   | ![](fire_ne.png) ![](fire_nw.png) ![](fire_se.png) ![](fire_sw.png) ![](luigi_large_left.png) ![](luigi_large_right.png) ![](luigi_small_left.png) ![](luigi_small_right.png) ![](mario_big_left.png) ![](mario_big_right.png) ![](mario_small_left.png) ![](mario_small_right.png) ![](spiny_left.png) ![](spiny_right.png)

* [Tab-separated data](door.tsv) for door gadget from the paper
  "[Super Mario Bros. is Harder/Easier than We Thought](http://erikdemaine.org/papers/Mario_FUN2016/paper.pdf)"
  (Figure 6 on page 12):

  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 |
  | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ |
  | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised |
  |  |  |  |  |  |  |  | raised | raised | raised |  |  |  |  |  |  |  |
  | raised | raised | raised | raised | raised | raised |  |  | raised |  |  | raised | raised | raised | raised | raised | raised |
  | raised | raised |  |  |  | raised | raised |  | ,fire_se |  | raised | raised |  |  |  | raised | raised |
  | ,mario_small_right+4 |  |  | raised |  |  |  |  | raised |  | ,spiny_right+8 |  |  | raised |  |  | raised |
  | raised | raised | raised | raised | raised | raised | raised | brick,fire_se | raised | brick,fire_se | raised | raised | raised | raised | raised |  |  |
  |  |  |  |  |  |  |  |  | raised |  |  |  |  |  |  |  | raised |
  | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised | raised |

## Output:

  | Palette     | PNG                       | SVG                       |
  | ----------- | ------------------------- | ------------------------- |
  | castle      | ![](door_castle.png)      | ![](door_castle.svg)      |
  | overworld   | ![](door_overworld.png)   | ![](door_overworld.svg)   |
  | underground | ![](door_underground.png) | ![](door_underground.svg) |
  | underwater  | ![](door_underwater.png)  | ![](door_underwater.svg)  |
