
## This minimal example shows 5 blue squares.
import figuro/widgets/[button, vertical, slider, input, toggle]
import figuro
import cssgrid/prettyprints

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
    
    Vertical.new "widgets-vert":
      size this, 100'pp-20'ux, 100'pp-20'ux
      contentHeight this, cx"min-content", gap = 20'ui
      # border this, 3'ui, css"green"
      cornerRadius 10.0'ui

      Rectangle.new "filler":
        size 10'ux, 40'ux

      TextButton.new "slider1":
        size 80'pp, 60'ux
        this.label({defaultFont(): "Click me!"})
        cornerRadius 10.0'ui

      Slider[float].new "slider1":
        size 80'pp, 60'ux
        fill css"white".darken(0.3)
        this.min = 0.0
        this.max = 1.0
        onInit:
          this.state = 0.5

      TextSlider[float].new "slider2":
        size 80'pp, 60'ux
        fill css"white".darken(0.3)
        this.min = 0.0
        this.max = 1.0
        this.label {defaultFont(): $(this.state.round(2))}

      Toggle.new "toggle":
        size 30'ux, 30'ux
        fill css"white".darken(0.3)

      Toggle.new "toggle":
        size 30'ux, 30'ux
        onInit:
          enabled true

      Rectangle.new "filler":
        size 10'ux, 40'ux

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 640'ui))
startFiguro(frame)
