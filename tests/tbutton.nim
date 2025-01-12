import figuro/widgets/button
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 16)

type
  Counter* = object

  Main* = ref object of Figuro
    value: int
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc btnDrag*(node: Figuro,
              kind: EventKind,
              initial: Position,
              cursor: Position) {.slot.} =
  echo "btnDrag: ", node.getId, " ", kind,
          " change: ", initial.positionDiff(cursor),
          " nodeRel: ", cursor.positionRelative(node)

proc draw*(self: Main) {.slot.} =
  with self:
    setName "main"
    fill css"#9F2B00"
    box 0'ux, 0'ux, 400'ux, 300'ux

  let node = self
  Button[int].new "btn":
    with node:
      box 40'ux, 30'ux, 80'ux, 80'ux
      fill css"#2B9F2B"

    block:
      text "btnText":
        with node:
          box 10'ux, 10'ux, 80'pp, 80'pp
          fill blackColor
          setText({font: "testing"}, Center, Middle)


var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 140'ui))
startFiguro(frame)
