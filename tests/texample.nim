import figuro/widgets/vertical
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of Figuro
    mainRect: Figuro
    fVal: float32

proc drag(
  main: Main;
  kind: EventKind,
  initial: Position;
  current: Position;
) {.slot.} =
  refresh(main)

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    name "root"

    vertical "vert":
      fill whiteColor.darken(0.5)
      offset 30'ux, 10'ux
      size 400'ux, 120'ux

      # echo "TEXAMPLE: ", current.gridTemplate
      fill blackColor * 0.1
      cornerRadius 20

      let i = 3
      let slider1 {.expose.} = rectangle("slider"):
          # var theSlider: Slider[float32]
          size 0.5'fr, 0.5'fr
          fill "#00A0AA"
          text "val":
            setText({font: "test1"}, Center, Middle)
            fill parseHtmlColor"#FFFFFF"
      rectangle "slider":
        # echo "slider1: ", slider1.getId
        size 0.5'fr, 0.5'fr
        # size 60'ux, 40'ux
        fill "#A000AA"
        text "val":
          setText({font: "test2"}, Center, Middle)
          fill parseHtmlColor"#FFFFFF"

var main = Main.new()
connect(main, doDraw, main, Main.draw)

app.width = 720
app.height = 240
startFiguro(main)