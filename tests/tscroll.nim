
## This minimal scrollpane example
import figuro/widgets/[button, scrollpane, vertical]
import figuro
# import cssgrid/prettyprints
import figuro/ui/layout

let
  font = UiFont(typefaceId: defaultTypeface(), size: 22)

type
  Main* = ref object of Figuro

proc buttonItem(self, this: Figuro, idx: int) =
  Button.new "button":
    size 1'fr, 50'ux
    cssEnable false
    fill rgba(66, 177, 44, 197).to(Color).spin(idx.toFloat*20)
    if idx in [3, 7]:
      size 0.9'fr, 120'ux

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    size 100'pp, 100'pp
    # prettyPrintWriteMode = cmTerminal
    # printLayout(self, cmTerminal)
    fill css"#0000AA"
    setTitle("Scrolling example")
    onSignal(doMouseClick) do(self: Main,
                              kind: EventKind,
                              buttons: UiButtonView):
            if kind == Done:
              # printLayout(self, cmTerminal)
              printLayout(self, 0)
    ScrollPane.new "scroll":
      # printLayout(self, 0)
      offset 2'pp, 2'pp
      cornerRadius 7.0'ux
      size 96'pp, 90'pp
      fill css"white"
      Vertical.new "vertical":
        offset 10'ux, 10'ux
        size 100'pp-20'ux, cx"max-content"
        contentHeight cx"max-content"
        for idx in 0 .. 100:
          buttonItem(self, this, idx)

var main = Main()
var frame = newAppFrame(main, size=(600'ui, 480'ui))
startFiguro(frame)