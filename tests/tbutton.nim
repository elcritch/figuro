import figuro/widgets/buttonWrap
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Counter* = object

  Main* = ref object of Figuro
    value: int
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc btnDrag*(self: Figuro,
              kind: EventKind,
              cursor: Position) {.slot.} =
  echo "btnDrag: ", self.getId, " ", kind, " position: ", cursor

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    self.name.setLen(0)
    self.name.add "main"
    fill "#9F2B00"
    box 0'ux, 0'ux, 400'ux, 300'ux

    button "btn", state(int):
      box 40'ux, 30'ux, 80'ux, 80'ux
      fill "#2B9F2B"
      connect(current, doDrag, current, btnDrag)

      contents "child":
        node nkText, "btnText":
          box 10'pp, 10'pp, 80'pp, 80'pp
          fill blackColor
          setText({font: "hi"})

    rectangle "btnBody":
      box 200'ux, 30'ux, 80'ux, 80'ux
      fill "#9F2B00"
      connect(current, doDrag, current, btnDrag)


var main = Main.new()
connect(main, doDraw, main, Main.draw())

app.width = 400
app.height = 140
startFiguro(main)
