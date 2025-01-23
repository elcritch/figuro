
## This minimal example shows 5 blue squares.
import figuro/widgets/[button, scrollpane, vertical]
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  # echo "hover: ", kind
  refresh(self)

proc buttonItem(self, node: Figuro, idx: int) =
  Button.new "button":
    # current.gridItem = nil
    with node:
      size 1'fr, 50'ux
      fill rgba(66, 177, 44, 197).to(Color).spin(idx.toFloat*50)
    if idx in [3, 7]:
      node.size 0.9'fr, 120'ux
    connect(node, doHover, self, Main.hover)
    # Text.new "text":
    #   node.setText({font: "TESTING"}, Center, Middle)
    #   fill node, blackColor

proc draw*(self: Main) {.slot.} =
  var node = self
  with node:
    fill css"#0000AA"
  ScrollPane.new "scroll":
    with node:
      offset 2'pp, 2'pp
      cornerRadius 7.0'ux
      size 96'pp, 90'pp
    Vertical.new "":
      with node:
        offset 10'ux, 10'ux
        itemHeight cx"max-content"
      for idx in 0 .. 15:
        buttonItem(self, node, idx)

var main = Main.new()
var frame = newAppFrame(main, size=(600'ui, 480'ui))
startFiguro(frame)
