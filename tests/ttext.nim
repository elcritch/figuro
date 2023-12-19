
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 20'ui)
  smallFont = UiFont(typefaceId: typeface, size: 13'ui)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self)

import pretty

proc draw*(self: Main) {.slot.} =
  var node = self
  rectangle "main":
    with node:
      box 10'ux, 10'ux, 600'ux, 120'ux
      cornerRadius 10.0
      fill css"#2A9EEA" * 0.7
    text "text":
      with node:
        box 10'ux, 10'ux, 400'ux, 100'ux
        fill blackColor
        setText({font: "hello world!",
                  smallFont: "It's a small world"}, vAlign=Top)
    text "text":
      with node:
        box 10'ux, 10'ux, 400'ux, 100'ux
        fill blackColor
        setText({font: "hello world!",
                  smallFont: "It's a small world"}, vAlign=Middle)
    text "text":
      with node:
        box 10'ux, 10'ux, 400'ux, 100'ux
        fill blackColor
        setText({font: "hello world!",
                  smallFont: "It's a small world"}, vAlign=Bottom)
    rectangle "main":
      with node:
        box 10'ux, 10'ux, 400'ux, 100'ux
        fill whiteColor * 0.33

var main = Main.new()
let frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
