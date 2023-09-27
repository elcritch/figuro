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


proc draw*(self: Main) {.slot.} =
  withDraw(self):
    self.name.setLen(0)
    self.name.add "main"
    fill "#9F2B00"
    box 0'ux, 0'ux, 400'ux, 300'ux

    rectangle "btnBody":
      box 10'ux, 10'ux, 10'ux, 10'ux
      fill "#9F2B00"

    button "btn", state(int):
      box 10'ux, 10'ux, 80'pp, 80'pp
      fill "#2B9F2B"

      contents "child":
        node nkText, "btnText":
          box 10'pp, 10'pp, 80'pp, 80'pp
          fill blackColor
          setText({font: "hi"})

var main = Main.new()
connect(main, doDraw, main, Main.draw())
connect(main, doTick, main, Main.tick())

app.width = 720
app.height = 140
startFiguro(main)
