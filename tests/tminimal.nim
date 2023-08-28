
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
  if self.hasHovered:
    if self.hoveredAlpha < 0.15:
      self.hoveredAlpha += 0.010
      refresh(self)
  else:
    if self.hoveredAlpha > 0.00:
      self.hoveredAlpha -= 0.005
      refresh(self)

proc draw*(self: Main) {.slot.} =
  rectangle "main":
    self.mainRect = current
    box 10, 10, 600, 120
    cornerRadius 10.0
    fill whiteColor.darken(self.hoveredAlpha).spin(10*self.hoveredAlpha)
    for i in 0 .. 4:
      button "btn", (i, self):
        box 10 + widget.state[0] * 120, 10, 100, 100
        # we need to connect it's onHover event
        connect(current, onHover, widget.state[1], Main.hover)
        # unfortunately, we have many hovers
        # so we need to give hover a type 
        # perfect, the slot pragma adds all this for
        # us

var
  main = Main.new()

connect(main, onDraw, main, Main.draw)
connect(main, onTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 720
app.height = 140

startFiguro(main)
