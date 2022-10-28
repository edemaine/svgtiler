# Test multiple mappings in sequence instead of in parallel

import {map1, map2} from './mapping'

escapeMap = svgtiler.require './escape.txt'

export map = new svgtiler.Mappings map1, map2, escapeMap
