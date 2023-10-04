import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of Figuro
    mainRect: Figuro
    fVal: float32

import macros


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
    fill blackColor

    rectangle "main":
      fill whiteColor.darken(0.5)
      offset 30'ux, 10'ux
      size 400'ux, 120'ux

      setGridCols 1'fr
      setGridRows 60'ux
      gridAutoRows 60'ux
      gridAutoFlow grRow
      justifyItems CxCenter
      alignItems CxStart
      echo "TEXAMPLE: ", current.gridTemplate
      fill blackColor

      let i = 3
      let slider1 {.expose.} = rectangle("slider"):
          # var theSlider: Slider[float32]
          size 60'ux, 40'ux
          fill "#00A0AA"
          # slider "floatSlider", state(float32):
          #   widget.valueRange = 0f..10f
          #   theSlider = widget
          #   connect(current, doDrag, self, Main.drag)
          text "val":
            setText({font: "test1"}, Center, Middle)
            fill parseHtmlColor"#FFFFFF"
      rectangle "slider":
        echo "slider1: ", slider1.getId
        # var theSlider: Slider[int]
        size 60'ux, 40'ux
        fill "#A000AA"
        # slider "intSlider", state(int):
        #   widget.valueRange = 0..10
        #   theSlider = widget
        #   connect(current, doDrag, self, Main.drag)
        text "val":
          setText({font: "test2"}, Center, Middle)
          fill parseHtmlColor"#FFFFFF"

var main = Main.new()
connect(main, doDraw, main, Main.draw)

app.width = 720
app.height = 140
startFiguro(main)