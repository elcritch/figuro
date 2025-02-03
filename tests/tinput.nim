
## This minimal example shows 5 blue squares.
import figuro/widgets/input
import figuro/widgets/button
import figuro

let
  # typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: defaultTypeface, size: 22'ui)
  smallFont = UiFont(typefaceId: defaultTypeface, size: 12'ui)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    mainRect: Figuro

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Done
  refresh(self.mainRect)

proc draw*(self: Main) {.slot.} =
  var node = self
  # self.theme.font = UiFont(typefaceId: self.frame[].theme.font.typefaceId, size: 22)
  rectangle "body":
    self.mainRect = node
    with node:
      box 10'ux, 10'ux, 600'ux, 120'ux
      cornerRadius 10.0
      fill "#2A9EEA".parseHtmlColor * 0.7
    Input.new "input":
      box node, 10'ux, 10'ux, 400'ux, 100'ux
      align node, Middle 
      justify node, Center
      font node, UiFont(typefaceId: defaultTypeface, size: 20'ui)
      font node, css"red"
      fill node, css"grey"

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
