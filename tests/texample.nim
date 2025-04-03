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
      with this:
        fill whiteColor.darken(0.5)
        offset 30'ux, 10'ux
        size 400'ux, 120'ux
        contentHeight 90'ux

        fill blackColor * 0.1
        cornerRadius 20

      rectangle "slider":
        with this:
          size 200'ux, 45'ux
          fill css"#00A0AA"
        Text as "txt1":
          with this:
            align Middle
            justify Center
            text {font: "test2"}
            foreground css"#FFFFFF"
      rectangle "slider":
        with this:
          size 0.5'fr, 0.5'fr
          fill css"#A000AA"
        Text as "txt2":
          # size 100'pp, 100'pp
          with this:
            align Middle
            justify Center
            text {font: "test2"}
            foreground css"#FFFFFF"
    

var main = Main.new()
var frame = newAppFrame(main, size=(440'ui, 440'ui))
startFiguro(frame)
