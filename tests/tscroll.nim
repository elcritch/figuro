
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
    box 20, 10, 100'vw, 100'vh
    current.name.setLen(0)
    current.name.add("root")

    scroll "scroll":
      # box 20, 10, 80'vw, 300
      box csFixed(20), csFixed(10), csPerc(90), csPerc(80)
      echo "widget:scroll:name: ", current.name, " pn: ", current.parent.name
      echo "widget:scroll:cb: ", current.box, " pb: ", current.parent.box
      echo "cxScroll: ", current.cxSize

      contents "children":
        for i in 0 .. 9:
          button "button", captures(i):
            # box 10, 10 + i * 80, 40'vw, 70
            box csFixed(10), csFixed(10 + i * 80), csPerc(90), csFixed(70)
            connect(current, doHover, self, Main.hover)

var main = Main.new()
connect(main, doDraw, main, Main.draw)
connect(main, doTick, main, Main.tick)

echo "main: ", main.listeners

app.width = 600
app.height = 480

startFiguro(main)
