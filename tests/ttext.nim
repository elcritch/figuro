
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22'ui)
  smallFont = UiFont(typefaceId: typeface, size: 12'ui)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    mainRect: Figuro

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self.mainRect)

proc draw*(self: Main) {.slot.} =
  nodes(self):
    rectangle "main":
      self.mainRect = current
      box 10'ux, 10'ux, 600'ux, 120'ux
      cornerRadius 10.0
      fill "#2A9EEA".parseHtmlColor * 0.7
      text "text":
        box 10'ux, 10'ux, 400'ux, 100'ux
        fill blackColor
        setText({font: "hello world!\n",
                 smallFont: "it's a small world"})
      rectangle "main":
        box 10'ux, 10'ux, 400'ux, 100'ux
        fill whiteColor * 0.33

var
  fig = Main.new()

connect(fig, doDraw, fig, Main.draw)

app.width = 720
app.height = 140

startFiguro(fig)
