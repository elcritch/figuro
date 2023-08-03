
## This minimal example shows 5 blue squares.

import figura/engine

proc drawMain() =
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      rectangle "block":
        box 20 + i * 120, 20, 100, 100
        current.fill = parseHtmlColor "#2B9FEA"

startFidget(drawMain, w = 620, h = 140)
