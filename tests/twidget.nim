
## This minimal example shows 5 blue squares.

import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    mainRect: Figuro

proc tick*(self: Main) {.slot.} =
  refresh(self)
  if self.mainRect != nil:
    echo "tick main: ", self.mainRect.uid
  # echo "tick widget: ", app.requestedFrame, " ", app.tickCount
  self.value = 0.004 * (1+app.tickCount).toFloat
  self.value = clamp(self.value mod 1.0, 0, 1.0)

proc draw*(self: Main) {.slot.} =
  echo "draw widget!"
  frame "main":
    self.mainRect = current
    echo "draw mainRect"
    box 0, 0, 620, 140
    for i in 0 .. 5:
      button "btn":
        # fill "#A000A0"
        # box 20 + (i.toFloat + self.value) * 120, 20, 40, 40
        box 20 + (i.toFloat + self.value) * 120, 30 + 20 * sin(self.value + i.toFloat), 60, 60
        if i == 0:
          current.fill.a = self.value * 1.0

var
  main = Main.new()

echo "fig: uid: ", main.agentId
connect(main, onDraw, main, Main.draw)
connect(main, onTick, main, Main.tick)

app.width = 720
app.height = 140

startFiguro(main)
