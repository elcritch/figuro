
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

import std/with

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc draw*(self: Main) {.slot.} =
  var node = self
  rectangle "body":
    with node:
      fill css"#D0D0D0"
      box 10'pp, 10'pp, 80'pp, 80'pp
      cornerRadius 10.0'ui

    button "btn":
      with node:
        box 10'pp, 10'pp, 80'pp, 10'pp
        fill css"#2B9FEA"

    button[void] "btn":
      with node:
        box 10'pp, 60'pp, 80'pp, 10'pp
        fill css"#2B9FEA"

var main = Main.new()
let frame = newAppFrame(main, size=(400'ui, 400'ui))
startFiguro(frame)
