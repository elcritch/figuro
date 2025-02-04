
## This minimal scrollpane example
import figuro/widgets/[button, scrollpane, vertical]
import figuro

let
  font = UiFont(typefaceId: defaultTypeface, size: 22)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Init
  # echo "hover: ", kind
  refresh(self)

proc buttonItem(self, node: Figuro, idx: int) =
  Button.new "button":
    # current.gridItem = nil
    with this:
      size 1'fr, 50'ux
      fill rgba(66, 177, 44, 197).to(Color).spin(idx.toFloat*20)
    if idx in [3, 7]:
      node.size 0.9'fr, 120'ux
    connect(node, doHover, self, Main.hover)

proc draw*(self: Main) {.slot.} =
  withWidget(self):
    with this:
      fill css"#0000AA"
      setTitle("Scrolling example")
    ScrollPane.new "scroll":
      with this:
        offset 2'pp, 2'pp
        cornerRadius 7.0'ux
        size 96'pp, 90'pp
      Vertical.new "":
        with this:
          offset 10'ux, 10'ux
          contentHeight cx"max-content"
        for idx in 0 .. 15:
          buttonItem(self, node, idx)

var main = Main.new()
var frame = newAppFrame(main, size=(600'ui, 480'ui))
startFiguro(frame)
