
## This minimal example shows 5 blue squares.

import figuro/widgets/button
import figuro/widget
import figuro

import std/sugar

type
  Main* = ref object of Figuro
    value: float

proc tick*(self: Main, tick: int, now: MonoTime) {.slot.} =
  refresh(self)
  self.value = 0.004 * (1+tick).toFloat
  self.value = clamp(self.value mod 1.0, 0, 1.0)

proc draw*(self: Main) {.slot.} =
  rectangle "main", parent=self:
    box node, 0'ui, 0'ui, 620'ui, 140'ui
    let j = 1
    for i in 0 .. 5:
      Button.new "btn":
        capture i, j:
          let value = self.value
          fill node, css"#AA0000"
          node.onHover:
            fill node, css"#F00000"
          box node,
              ux(20 + (i.toFloat + value) * 120),
              ux(30 + 20 * sin(value + i.toFloat)),
              60'ui, 60'ui
          if i == 0:
            node.fill.a = value * 1.0

var fig = Main.new()

let frame = newAppFrame(fig, size=(720'ui, 140'ui))
startFiguro(frame)
