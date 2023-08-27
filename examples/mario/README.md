# Super Mario Bros.

## Mapping Input:

* [CoffeeScript mapping file](mario.coffee)
* [JSON file](palette.coffee) to define which "palette" to use
  ("castle", "overworld", "underground", or "underwater")
* Sprites thanks to [The Spriters Resource](https://www.spriters-resource.com/nes/supermariobros/):

  | Palette     | Sprites   |
  | ----------- | --------- |
  | castle      | ![brick](brick_castle.png) ![lit brick](brick_lit_castle.png) ![used brick](brick_used_castle.png) ![Goomba](goomba_castle.png) ![question block](question_castle.png) ![used question block](question_used_castle.png) ![raised block](raised_castle.png) ![rock](rock_castle.png) ![1-up](1up_castle.png)
  | overworld   | ![brick](brick_overworld.png) ![lit brick](brick_lit_overworld.png) ![used brick](brick_used_overworld.png) ![Goomba](goomba_overworld.png) ![question block](question_overworld.png) ![used question block](question_used_overworld.png) ![raised block](raised_overworld.png) ![rock](rock_overworld.png) ![1-up](1up_overworld.png)
  | underground | ![brick](brick_underground.png) ![lit brick](brick_lit_underground.png) ![used brick](brick_used_underground.png) ![Goomba](goomba_underground.png) ![question block](question_underground.png) ![used question block](question_used_underground.png) ![raised block](raised_underground.png) ![rock](rock_underground.png) ![1-up](1up_underground.png)
  | underwater  | ![brick](brick_underwater.png) ![lit brick](brick_lit_underwater.png) ![used brick](brick_used_underwater.png) ![Goomba](goomba_underwater.png) ![question block](question_underwater.png) ![used question block](question_used_underwater.png) ![raised block](raised_underwater.png) ![rock](rock_underwater.png) ![1-up](1up_underwater.png)
  | (general)   | ![fire bar facing northeast](fire_ne.png) ![fire bar facing northwest](fire_nw.png) ![fire bar facing southeast](fire_se.png) ![fire bar facing southwest](fire_sw.png) ![large Luigi facing left](luigi_large_left.png) ![large Luigi facing right](luigi_large_right.png) ![small Luigi facing left](luigi_small_left.png) ![small Luigi facing right](luigi_small_right.png) ![large Mario facing left](mario_large_left.png) ![large Mario facing right](mario_large_right.png) ![small Mario facing left](mario_small_left.png) ![small Mario facing right](mario_small_right.png) ![spiny facing left](spiny_left.png) ![spiny facing right](spiny_right.png) ![fire flower](flower.png) ![growth mushroom](mushroom.png) ![star](star.png)

## Door Gadget:

**Input:** [Tab-separated drawing](door.tsv) for door gadget from the paper
"[Super Mario Bros. is Harder/Easier than We Thought](https://erikdemaine.org/papers/Mario_FUN2016/)"
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

**Output:**

| Palette     | PNG                       | SVG                       |
| ----------- | ------------------------- | ------------------------- |
| castle      | ![](door_castle.png)      | ![](door_castle.svg)      |
| overworld   | ![](door_overworld.png)   | ![](door_overworld.svg)   |
| underground | ![](door_underground.png) | ![](door_underground.svg) |
| underwater  | ![](door_underwater.png)  | ![](door_underwater.svg)  |

## Clause Gadget:

**Input:** [Tab-separated drawing](clause.tsv) for clause gadget from the paper
"[Classic Nintendo Games are (Computationally) Hard](https://erikdemaine.org/papers/Nintendo_TCS/)"
(Figure 11 on page 11), with stars added to show the question block contents:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 |
| ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ |
| blank |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  | raised |  |  |  |  |  |  |  |  | raised |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  | raised |  |  |  |  |  |  |  |  | raised |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  | raised |  |  |  |  |  |  |  |  | raised |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  | raised |  |  |  |  |  |  |  |  | raised |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  | raised |  | star |  |  | star |  |  | star | raised |  |  | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 | question_used,fire_se-6+6*6 |
| raised | raised | raised | raised | raised | question | raised | raised | question | raised | raised | question | raised |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| raised | raised | raised | raised |  |  | raised |  |  | raised |  |  | raised |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| raised | raised | raised | raised |  |  | raised |  |  | raised |  |  | raised | raised | raised | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 | question_used,fire_nw+6-6*6 |

**Output:**

| Palette     | PNG                       | SVG                       |
| ----------- | ------------------------- | ------------------------- |
| castle      | ![](clause_castle.png)      | ![](clause_castle.svg)      |
| overworld   | ![](clause_overworld.png)   | ![](clause_overworld.svg)   |
| underground | ![](clause_underground.png) | ![](clause_underground.svg) |
| underwater  | ![](clause_underwater.png)  | ![](clause_underwater.svg)  |
