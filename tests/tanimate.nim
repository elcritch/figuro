
## This minimal example shows 5 blue squares.

import figuro/widgets/button
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
  withRootWidget(self):
    setTitle "Animation Example"
    box this, -100'ui, 0'ui, 600'ui, 140'ui
    fill css"#0F0F0F"
    let j = 1
    for i in 0 .. 9:
      capture i, j:
        Rectangle.new "":
          cssEnable this, false
          let value = self.value
          fill this, css"#AA0000".spin(i.toFloat*20.0)
          this.onHover:
            fill this, this.fill.lighten(0.1)
          let xval = (i.toFloat * 60 + value*600) mod 600.0
          box this,
              ux(xval),
              ux(30 + 20 * sin(xval/640*2*3.14)),
              60'ui, 60'ui
          if i == 0:
            this.fill.a = value * 1.0

var fig = Main.new()

var frame = newAppFrame(fig, size=(500'ui, 140'ui), style = DecoratedFixedSized)
startFiguro(frame)
