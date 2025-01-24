import figuro/widgets/button
import figuro/ui/animations
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
    bkgFade* = Fader(minMax: 0.0..0.18,
                     inTimeMs: 600, outTimeMs: 500)


proc btnDragStart*(node: Figuro,
                   kind: EventKind,
                   initial: Position,
                   cursor: Position
                  ) {.slot.} =
  discard
  echo "btnDrag:exit: ", node.getId, " ", kind,
          " change: ", initial.positionDiff(cursor),
          " nodeRel: ", cursor.positionRelative(node)

proc btnDragStop*(
    node: Figuro,
    kind: EventKind,
    initial: Position,
    cursor: Position
) {.slot.} =
  echo "btnDrag:exit: ", node.getId, " ", kind,
          " change: ", initial.positionDiff(cursor),
          " nodeRel: ", cursor.positionRelative(node)
  let btn = Button[Fader](node)

proc draw*(self: Main) {.slot.} =
  # var node = self
  with self:
    setName "main"
    fill css"#9F2B00"
    box 0'ux, 0'ux, 400'ux, 300'ux

  let node = self
  Button.new "btn":
    with node:
      box 40'ux, 30'ux, 80'ux, 80'ux
      fill css"#2B9F2B"
      connect(doDrag, node, btnDragStart)

    text "btnText":
      with node:
        box 10'ux, 10'ux, 80'pp, 80'pp
        fill blackColor
        setText({font: "drag me"})

  Button[Fader].new "btn":
    echo "button:id: ", node.getId, " ", node.state.typeof
    with node:
      box 200'ux, 30'ux, 80'ux, 80'ux
      fill css"#9F2B00"
      connect(doDrag, node, btnDragStop)

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
