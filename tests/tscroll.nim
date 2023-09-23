
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self)

proc tick*(self: Main) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)

import pretty

proc scroll*(fig: Main, wheelDelta: Position) {.slot.} =
  echo "scroll: ", wheelDelta

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    rectangle "body":
      self.mainRect = current
      box 20, 10, 80'vw, 300
      cornerRadius 10.0
      fill whiteColor.darken(0.1)
      clipContent true
      current.listens.events.incl evScroll

      for i in 0 .. 10:
        button "btn", captures(i):
          box 10, 10 + i * 80, 90'vw, 70
          connect(current, doHover, self, Main.hover)

var main = Main.new()
connect(main, doDraw, main, Main.draw)
connect(main, doTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 600
app.height = 480

startFiguro(main)
