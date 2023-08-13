
## This minimal example shows 5 blue squares.

import figuro/widgets/button
import figuro/widget
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
    for i in 0 .. 5:
      button "btn":
        box 20 + (i.toFloat + app.value) * 120, 20, 100, 100
        if i == 0:
          current.fill.a = app.value * 1.0

var
  app = FiguroApp()
  main = Main()

connect(app, onDraw, main, twidget.draw)
connect(app, onTick, main, twidget.tick)

startFiguro(app, w = 720, h = 140)
