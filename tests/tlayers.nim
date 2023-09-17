
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
    rectangle "container":
      fill "#D0D0D0"
      box 3'pw, 10'ph, 30'pw, 80'ph
      cornerRadius 10.0
      # clipContent true

      # button "btn":
      #   box 10'pw, 10'ph, 130'pw, 20'ph
      #   current.zlevel = 20.ZLevel

      # button "btn":
      #   box 10'pw, 60'ph, 130'pw, 20'ph
      #   current.zlevel = -5.ZLevel

    rectangle "container":
      fill "#D0D0D0"
      box 50'pw, 10'ph, 30'pw, 80'ph
      cornerRadius 10.0
      # clipContent true

      button "btn":
        box 10'pw, 10'ph, 130'pw, 20'ph
        current.zlevel = 20.ZLevel

      button "btn":
        box 10'pw, 60'ph, 130'pw, 20'ph
        current.zlevel = -5.ZLevel

var main = Main.new()
connect(main, doDraw, main, Main.draw)
connect(main, doTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 800
app.height = 400

startFiguro(main)
