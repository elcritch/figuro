
## This minimal example shows 5 blue squares.

import figuro/[timers, widget]
import figuro

type
  Main* = ref object of Figuro
    value: float

method render(app: Main) =
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      rectangle "block":
        box 20 + i * 120, 20, 100, 100
        current.fill = parseHtmlColor "#2B9FEA"

startFiguro(Main(), w = 620, h = 140)
