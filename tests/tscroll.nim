
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

import pretty

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    offset 20'pp, 10'pp
    # size ux(100'vw), ux(100'vh)
    size 100'ux, 100'ux
    current.name.setLen(0)
    current.name.add("root")

    scroll "scroll":
      # box 20, 10, 80'vw, 300
      offset 20'ux, 10'ux
      size 90'pp, 80'pp

      contents "children":
        for i in 0 .. 9:
          button "button", captures(i):
            # box 10, 10 + i * 80, 40'vw, 70
            offset 10'ux, ux(10 + i * 80)
            size 90'pp, 70'ux
            connect(current, doHover, self, Main.hover)

var main = Main.new()
connect(main, doDraw, main, Main.draw)

echo "main: ", main.listeners

app.width = 600
app.height = 480

startFiguro(main)
