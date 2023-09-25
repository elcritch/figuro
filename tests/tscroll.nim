
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
    box 20, 10, 80'vw, 300
    echo "self:vw: ", current.box.w, " aw: ", app.windowSize.x

    scroll "scroll":
      # box 20, 10, 80'vw, 300
      box 20, 10, 480, 300
      echo "body:vw: ", current.box.w, " aw: ", app.windowSize.x

      contents "children":
        for i in 0 .. 0:
          button "button", captures(i):
            box 10, 10 + i * 80, 90'pw, 70
            connect(current, doHover, self, Main.hover)

var main = Main.new()
connect(main, doDraw, main, Main.draw)
connect(main, doTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 600
app.height = 480

startFiguro(main)
