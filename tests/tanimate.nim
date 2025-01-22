
## This minimal example shows 5 blue squares.

import figuro/widgets/button
import figuro/widget
import figuro

import std/sugar

type
  Main* = ref object of Figuro
    value: float

proc tick*(self: Main, now: MonoTime, delta: Duration) {.slot.} =
  refresh(self)
  self.value += 0.00013 * delta.inMilliseconds.toFloat
  self.value = clamp(self.value mod 1.0, 0, 1.0)

proc draw*(self: Main) {.slot.} =
  let node = self
  rectangle "main":
    box node, -100'ui, 0'ui, 600'ui, 140'ui
    let j = 1
    for i in 0 .. 9:
      capture i, j:
        rectangle "":
          cssEnable node, false
          let value = self.value
          fill node, css"#AA0000".spin(i.toFloat*20.0)
          node.onHover:
            fill node, node.fill.lighten(0.1)
          let xval = (i.toFloat * 60 + value*600) mod 600.0
          box node,
              ux(xval),
              ux(30 + 20 * sin(xval/640*2*3.14)),
              60'ui, 60'ui
          if i == 0:
            node.fill.a = value * 1.0

var fig = Main.new()

var frame = newAppFrame(fig, size=(500'ui, 140'ui))
startFiguro(frame)
