
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    hoveredAlpha: float
    scrollby: Position
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

proc scroll*(self: Main, wheelDelta: Position) {.slot.} =
  # self.scrollby.x -= wheelDelta.x * 10.0
  self.scrollby.y -= wheelDelta.y * 10.0
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    box 20, 10, 80'vw, 300
    current.listens.events.incl evScroll
    connect(current, doScroll, self, Main.scroll)
    rectangle "body":
      self.mainRect = current
      # box 20, 10, 80'vw, 300
      boxOf current.parent
      cornerRadius 10.0
      fill whiteColor.darken(0.1)
      clipContent true
      current.offset = self.scrollby
      current.attrs.incl scrollpane

      for i in 0 .. 10:
        button "button", captures(i):
          box 10, 10 + i * 80, 90'vw, 70
          connect(current, doHover, self, Main.hover)

var main = Main.new()
connect(main, doDraw, main, Main.draw)
connect(main, doTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 600
app.height = 480

startFiguro(main)
