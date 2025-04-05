
## This minimal example shows 5 blue squares.
import figuro/widgets/[button, vertical, slider]
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool = false
    hoveredAlpha: float = 0.0


proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    size 100'pp, 100'pp
    cornerRadius 10.0'ui
    fill css"lightgrey"
    border 3'ui, blackColor
    padding 10'ux
    
    Vertical.new "horiz":
      size this, 100'pp-20'ux, 100'pp-20'ux
      contentHeight this, cx"min-content", gap = 20'ui
      border this, 3'ui, css"green"
      cornerRadius 10.0'ui

      Rectangle.new "filler":
        size 10'ux, 40'ux

      Rectangle.new "slider-bg":
        offset 50'ux, 0'ux
        size 80'pp, 60'ux

        Slider[float].new "slider":
          size 80'pp, 100'pp
          offset 10'pp, 0'ux
          fill css"white".darken(0.3)
          this.min = 0.0
          this.max = 1.0
          # if NfInitialized notin self.flags:
          #   this.state = 0.5

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 640'ui))
startFiguro(frame)
