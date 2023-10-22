import figuro/widgets/vertical
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of Figuro
    mainRect: Figuro
    fVal: float32

proc drag(main: Main; kind: EventKind,
          initial: Position, current: Position) {.slot.} =
  refresh(main)

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    name "root"

    let vert {.expose.} = vertical "vert":
      fill whiteColor.darken(0.5)
      offset 30'ux, 10'ux
      size 400'ux, 120'ux
      itemHeight 90'ux

      # echo "TEXAMPLE: ", current.gridTemplate
      fill blackColor * 0.1
      cornerRadius 20

      let slider1 {.expose.} =
        rectangle "slider":
          size 200'ux, 45'ux
          fill "#00A0AA"
          text "val":
            setText({font: "test1"}, Center, Middle)
            fill css"#FFFFFF"
      rectangle "slider":
        size 0.5'fr, 0.5'fr
        fig.fill = css"#A000AA"
        text "val":
          setText({font: "test2"}, Center, Middle)
          fill css"#FFFFFF"
    gridTemplateDebugLines Figuro(vert)

var main = Main.new()
connect(main, doDraw, main, Main.draw)

app.width = 440
app.height = 440
startFiguro(main)
