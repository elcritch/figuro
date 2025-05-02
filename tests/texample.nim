import figuro/widgets/vertical
import figuro

let
  typeface = defaultTypeface()
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of Figuro
    mainRect: Figuro
    fVal: float32

proc drag(main: Main; kind: EventKind,
          initial: Position, current: Position) {.slot.} =
  refresh(main)

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    var vert: Vertical
    Vertical.new "vert":
      vert = this
      fill whiteColor.darken(0.5)
      offset 30'ux, 10'ux
      size 400'ux, 120'ux
      contentHeight 90'ux

      fill blackColor * 0.1
      cornerRadius 20

      Rectangle.new "slider":
        size 200'ux, 45'ux
        fill css"#00A0AA"
        Text as "txt1":
          align Middle
          justify Center
          text {font: "test2"}
          foreground css"#FFFFFF"
      Rectangle.new "slider":
        size 0.5'fr, 0.5'fr
        fill css"#A000AA"
        Text as "txt2":
          align Middle
          justify Center
          text {font: "test2"}
          foreground css"#FFFFFF"
  

var main = Main.new()
var frame = newAppFrame(main, size=(440'ui, 440'ui))
startFiguro(frame)
