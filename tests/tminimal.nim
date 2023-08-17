
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float

proc draw*(self: Main) {.slot.} =
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      button "btn":
        box 20 + i * 120, 20, 100, 100
        fill "#2B9FEA"
        onHover:
          echo "on over"
          current.fill = parseHtmlColor "#FF0000"

var
  fig = FiguroApp()
  main = Main()

connect(fig, onDraw, main, tminimal.draw)

app.width = 720
app.height = 140

startFiguro(fig)
