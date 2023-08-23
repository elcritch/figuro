
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = loadFont: GlyphFont(
      typefaceId: typeface,
      size: 44
    )

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    mainRect: Figuro

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  # echo "main: child hovered: ", kind
  refresh(self.mainRect)

proc draw*(self: Main) {.slot.} =
  rectangle "main":
    self.mainRect = current
    box 10, 10, 600, 120
    cornerRadius 10.0
    fill "#2A9EEA".parseHtmlColor * 0.7
    # fill whiteColor
    text "text":
      box 10, 10, 400, 10
      fill blackColor
      setText(font, "hello world!")
    rectangle "main":
      box 10, 10, 400, 80
      fill whiteColor * 0.8

var
  fig = FiguroApp()
  main = Main()

connect(fig, onDraw, main, Main.draw)

app.width = 720
app.height = 140

startFiguro(fig)
