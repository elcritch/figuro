
## This minimal example shows 5 blue squares.

import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float

proc tick*(self: Main) {.slot.} =
  refresh()
  # echo "tick widget: ", app.requestedFrame, " ", app.tickCount
  self.value = 0.008 * (1+app.tickCount).toFloat
  self.value = clamp(self.value mod 1.0, 0, 1.0)

proc draw*(self: Main) {.slot.} =
  # echo "draw widget!"
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 5:
      button "btn":
        # fill "#A000A0"
        box 20 + (i.toFloat + self.value) * 120, 20, 100, 100
        # box 20 + (i.toFloat + app.value) * 120, 20 * sin(app.value + i.toFloat), 100, 100
        if i == 0:
          current.fill.a = self.value * 1.0

var
  fig = FiguroApp()
  main = Main()

connect(fig, onDraw, main, twidget.draw)
connect(fig, onTick, main, twidget.tick)

app.width = 720
app.height = 140

startFiguro(fig)
