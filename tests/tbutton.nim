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
    box 0, 0, 400, 300

    rectangle "btnBody":
      box 10, 10, 10, 10
      fill "#9F2B00"

    button "btn", state(int):
      echo nd(), "button:WIDGET: ", current.getId
      box 40, 40, 100, 100
      fill "#2B9F2B"

      contents:
        node nkText, "btnText":
          echo nd(), "btnText:WIDGET: ", current.getId
          box 10'pw, 10'pw, 80'pw, 80'ph
          fill blackColor
          setText({font: "hi"})


var main = Main.new()
connect(main, doDraw, main, Main.draw())
connect(main, doTick, main, Main.tick())

app.width = 720
app.height = 140
startFiguro(main)
