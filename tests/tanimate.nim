## This minimal example shows 5 blue squares.

import figuro/timers
import figuro

type
  Item = ref object
    value: float

proc ticker(self: Item) =
  refresh()
  self.value = 0.008 * (1+app.frameCount).toFloat
  self.value = clamp(self.value mod 1.0, 0, 1.0)

var
  item = Item()

proc drawMain() =
  ticker(item)
  
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      rectangle "block":
        box 20 + (i.toFloat + item.value) * 120, 20, 100, 100
        current.fill = parseHtmlColor "#2B9FEA"
        if i == 0:
          current.fill.a = item.value * 1.0

startFidget(drawMain, w = 620, h = 140)
