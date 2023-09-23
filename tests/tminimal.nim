
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


proc draw*(self: Main) {.slot.} =
  withDraw(self):
    box 0, 0, 100'vw, 100'vh
    rectangle "body":
      fill "#D0D0D0"
      box 10'pw, 10'ph, 80'pw, 80'ph
      cornerRadius 10.0

      button "btn":
        box 10'pw, 10'ph, 80'pw, 10'ph
        fill "#2B9FEA"

      button "btn":
        box 10'pw, 60'ph, 80'pw, 10'ph
        fill "#2B9FEA"

var main = Main.new()
connect(main, doDraw, main, Main.draw)
connect(main, doTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 400
app.height = 400

startFiguro(main)
