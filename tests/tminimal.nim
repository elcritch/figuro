
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    mainRect: Figuro

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self.mainRect)

proc draw*(self: Main) {.slot.} =
  rectangle "main":
    self.mainRect = current
    box 10, 10, 600, 120
    cornerRadius 10.0
    fill whiteColor
    if self.hasHovered:
      fill whiteColor.darken(0.12)
    for i in 0 .. 4:
      button "btn":
        box 10 + i * 120, 10, 100, 100
        connect(current, onHover, self, Main.hover)

var
  fig = FiguroApp()
  main = Main()

connect(fig, onDraw, main, Main.draw)

app.width = 720
app.height = 140

startFiguro(fig)
