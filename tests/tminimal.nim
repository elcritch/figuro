
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  # echo "main: child hovered!"
  discard
  refresh(self)

proc draw*(self: Main) {.slot.} =
  rectangle "main":
    box 0, 0, 620, 140
    fill whiteColor
    if self.hasHovered:
      fill whiteColor.darken(0.1)
    for i in 0 .. 4:
      button "btn":
        box 20 + i * 120, 20, 100, 100
        # onHover:
        #   fill "#FF0000"
        connect(current, onHover, self, Main.hover)

var
  fig = FiguroApp()
  main = Main()

connect(fig, onDraw, main, Main.draw)

app.width = 720
app.height = 140

startFiguro(fig)