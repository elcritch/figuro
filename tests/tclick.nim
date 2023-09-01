
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

proc hovered*(self: Button, kind: EventKind) {.slot.} =
  # self.fill = parseHtmlColor "#9BDFFA"
  # echo "button hover!"
  # echo "button:hovered: ", kind, " :: ", self.getId
  refresh(self)

proc tick*(self: Main) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)

proc draw*(self: Main) {.slot.} =
  rectangle "main":
    self.mainRect = current
    box 10, 10, 600, 120
    cornerRadius 10.0
    fill whiteColor.darken(self.hoveredAlpha).spin(10*self.hoveredAlpha)
    for i in 0 .. 4:
      button "btn", i:
          box 10 + i * 120, 10, 100, 100
          # echo "button:draw: ", " :: ", self.getId


var
  main = Main.new()

connect(main, onDraw, main, Main.draw)
connect(main, onTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 720
app.height = 140

startFiguro(main)
