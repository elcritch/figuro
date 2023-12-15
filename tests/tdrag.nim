import figuro/widgets/button
import figuro/ui/animations
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


proc btnDragStart*(node: Figuro,
                   kind: EventKind,
                   initial: Position,
                   cursor: Position
                  ) {.slot.} =
  discard

proc btnDragStop*(
    node: Figuro,
    kind: EventKind,
    initial: Position,
    cursor: Position
) {.slot.} =
  echo "btnDrag:exit: ", node.getId, " ", kind,
          " change: ", initial.positionDiff(cursor),
          " nodeRel: ", cursor.positionRelative(node)
  let btn = Button[FadeAnimation](node)
  # btn.state.setMax()

proc draw*(self: Main) {.slot.} =
  var node = self
  with node:
    setName "main"
    fill css"#9F2B00"
    box 0'ux, 0'ux, 400'ux, 300'ux

  rectangle "btn":
    with node:
      box 40'ux, 30'ux, 80'ux, 80'ux
      fill css"#2B9F2B"
      connect(doDrag, node, btnDragStart)

    contents "child":
      text "btnText":
        with node:
          box 10'ux, 10'ux, 80'pp, 80'pp
          fill blackColor
          setText({font: "drag me"})

  buttonOf[FadeAnimation] "btn":
    echo "button:id: ", node.getId, " ", node.state.typeof
    with node:
      box 200'ux, 30'ux, 80'ux, 80'ux
      fill css"#9F2B00"
      connect(doDrag, node, btnDragStop)

var main = Main.new()
let frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
