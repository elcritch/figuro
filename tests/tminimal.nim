
## This minimal example shows 5 blue squares.
import figuro/widgets/[button]
import figuro

import std/sugar

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    size 100'pp, 100'pp
    Rectangle.new "body":
      fill css"#D0D0D0"
      box 10'pp, 10'pp, 80'pp, 80'pp
      cornerRadius 10.0'ui

      Button[int].new "btn":
        box 10'pp, 60'pp, 80'pp, 10'pp
        fill themeColor("fig-accent-color")

      for i in 1..2:
        capture i:
          Button.new "btn":
            box 10'pp, UiScalar(40 * i + 10), 80'pp, 10'pp
            fill themeColor("fig-accent-color")


var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 400'ui))
startFiguro(frame)
