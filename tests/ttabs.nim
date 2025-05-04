
## This minimal scrollpane example
import figuro/widgets/[button, scrollpane, tabs, vertical]
import figuro
import cssgrid/prettyprints
# import figuro/ui/layout

let
  font = UiFont(typefaceId: defaultTypeface(), size: 22)

type
  Main* = ref object of Figuro

proc buttonItem(self, this: Figuro, idx: int) =
  Button.new "button":
    size 1'fr, 50'ux
    cssEnable false
    fill rgba(66, 177, 44, 197).to(Color).spin(idx.toFloat*20 mod 360)
    if idx mod 10 in [3, 7]:
      size 0.9'fr, 120'ux
    
    paddingLR 20'ux, 20'ux

    Text.new "text":
      size 100'pp, 100'pp
      text {defaultFont(): "Item " & $idx}

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    size 100'pp, 100'pp
    # prettyPrintWriteMode = cmTerminal
    # printLayout(self, cmTerminal)
    setTitle("Scrolling example")
    onSignal(doRightClick) do(self: Main):
      echo "doRightClick"
      printLayout(self, cmTerminal)

    Tabs.new "tabs1":
      size 100'pp, 100'pp
      fill themeColor("fig-widget-background-color").darken(0.3)

      TabItem.new "First Tab":
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

      TabItem.new "Second Tab":
        Rectangle.new "rectangle":
          size 96'pp, 90'pp
          fill css"blue"

      TabItem.new "Third Tab":
        Rectangle.new "rectangle":
          size 96'pp, 90'pp
          fill css"green"

var main = Main()
var frame = newAppFrame(main, size=(600'ui, 480'ui))
startFiguro(frame)