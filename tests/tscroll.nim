
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widgets/scrollpane
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    offset 1'pp, 1'pp
    size 100'pp, 100'pp
    name "root"

    scroll "scroll":
      size 90'pp, 80'pp

      contents "children":
        for i in 0 .. 9:
          button "button", captures(i):
            size 90'pp, 70'ux
            connect(current, doHover, self, Main.hover)

var main = Main.new()
connect(main, doDraw, main, Main.draw)

echo "main: ", main.listeners

app.width = 600
app.height = 480

startFiguro(main)
