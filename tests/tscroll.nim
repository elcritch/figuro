
## This minimal scrollpane example
import figuro/widgets/[button, scrollpane, vertical]
import figuro
import cssgrid/prettyprints

let
  font = UiFont(typefaceId: defaultTypeface, size: 22)

type
  Main* = ref object of Figuro

proc buttonItem(self, this: Figuro, idx: int) =
  Button.new "button":
    size 1'fr, 50'ux
    # this.cxMin = [40'ux, 50'ux]
    fill rgba(66, 177, 44, 197).to(Color).spin(idx.toFloat*20)
    if idx in [3, 7]:
      size 0.9'fr, 120'ux

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    # prettyPrintWriteMode = cmTerminal
    fill css"#0000AA"
    setTitle("Scrolling example")
    ScrollPane.new "scroll":
      offset 2'pp, 2'pp
      cornerRadius 7.0'ux
      size 96'pp, 90'pp
      fill css"white"
      Vertical.new "vertical":
        offset 10'ux, 10'ux
        contentHeight cx"min-content"
        for idx in 0 .. 15:
          buttonItem(self, this, idx)

var main = Main.new()
var frame = newAppFrame(main, size=(600'ui, 480'ui))
startFiguro(frame)

# node:  [xy: 0.0x0.0; wh:600.0x480.0]
#   node: main [xy: 0.0x0.0; wh:600.0x480.0]
#     node: scroll [xy: 12.0x9.6; wh:576.0x432.0]
#       node: scrollBody [xy: 0.0x0.0; wh:576.0x432.0]
#         node: vertical [xy: 10.0x10.0; wh:566.0x940.0]
#           node: button [xy: 0.0x0.0; wh:566.0x50.0]
#             node: buttonInner [xy: 0.0x0.0; wh:566.0x50.0]
#           node: button [xy: 0.0x50.0; wh:566.0x50.0]
#             node: buttonInner [xy: 0.0x0.0; wh:566.0x50.0]
#           node: button [xy: 0.0x100.0; wh:566.0x50.0]
#             node: buttonInner [xy: 0.0x0.0; wh:566.0x50.0]
#           node: button [xy: 28.3x150.0; wh:509.4x120.0]
#             node: buttonInner [xy: 0.0x0.0; wh:509.4x120.0]