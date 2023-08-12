
## This minimal example shows 5 blue squares.

import figuro/[timers, widget]
import figuro/widgets/button
import figuro

type
  Main* = ref object of Figuro
    value: float

proc tick*(self: Main) {.slot.} =
  refresh()
  self.value = 0.008 * (1+app.frameCount).toFloat
  self.value = clamp(self.value mod 1.0, 0, 1.0)

proc draw*(app: Main) {.slot.} =
  # echo "draw widget!"
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      button "btn":
        box 20 + (i.toFloat + app.value) * 120, 20, 100, 100
        if i == 0:
          current.fill.a = app.value * 1.0

startFiguro(Main, w = 620, h = 140)
