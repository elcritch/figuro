
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

proc tick*(self: Main, tick: int, now: MonoTime) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)

proc draw*(self: Main) {.slot.} =
  var current = self
  # current = self
  rectangle "body":
    self.mainRect = current
    box 10'ux, 10'ux, 600'ux, 120'ux
    cornerRadius 10.0
    fill whiteColor.darken(self.hoveredAlpha).spin(10*self.hoveredAlpha)
    for i in 0 .. 4:
      button "btn", captures(i):
        box ux(10 + i * 120), 10'ux, 100'ux, 100'ux
        # fill css"#2B9FEA"
        # we need to connect it's onHover event
        connect(current, doHover, self, Main.hover)
        # unfortunately, we have many hovers
        # so we need to give hover a type 
        # perfect, the slot pragma adds all this for
        # us

var main = Main.new()
# connect(main, doDraw, main, Main.draw)
# connect(main, doTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 720
app.height = 140

startFiguro(main)
