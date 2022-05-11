###
This module defines an ASCII character map for animated
circles/squares/triangles as defined in shapes.coffee.
Demonstrates the re-use of exports from other modules.
###

import {shapes} from './shapes.coffee'
#{shapes} = require './shapes.coffee'

o: shapes.circle class: 'light pulse'
O: shapes.circle class: 'dark pulse'
x: shapes.square class: 'light pulse'
X: shapes.square class: 'dark pulse'
t: shapes.triangle class: 'light pulse'
T: shapes.triangle class: 'dark pulse'
