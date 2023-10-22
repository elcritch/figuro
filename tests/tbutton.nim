import figuro/widgets/buttonWrap
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
  withDraw(self):
    self.name.setLen(0)
    self.name.add "main"
    fill css"#9F2B00"
    box 0'ux, 0'ux, 400'ux, 300'ux

    button "btn", state(int):
      box 40'ux, 30'ux, 80'ux, 80'ux
      fill css"#2B9F2B"
      connect(current, doDrag, current, btnDrag)

      contents "child":
        text "btnText":
          box 10'ux, 10'ux, 80'pp, 80'pp
          fill blackColor
          setText({font: "drag me"})

    rectangle "btnBody":
      box 200'ux, 30'ux, 80'ux, 80'ux
      fill css"#9F2B00"
      connect(current, doDrag, current, btnDrag)


var main = Main.new()
connect(main, doDraw, main, Main.draw())

app.width = 400
app.height = 140
startFiguro(main)
