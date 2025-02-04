
## This minimal example shows 5 blue squares.
import figuro/widgets/[input, button, vertical, horizontal]
import figuro

let
  # typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: defaultTypeface, size: 22'ui)
  smallFont = UiFont(typefaceId: defaultTypeface, size: 12'ui)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    lastText = ""

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    fill this, css"blue"
    box this, 0'ux, 0'ux, 100'pp, 100'pp
    
    # Time display background
    rectangle "time-background":
      with this:
        box 20'pp, 10'pp, 60'pp, 80'pp
        fill css"#ffffff"
        border 1'ui, css"#000000"

      usingVerticalLayout cx"auto", gap = 20'ui
      # Time display text
      Text.new "time":
        with this:
          size 40'pp, 50'ux
          fill css"white"
          foreground css"red"
          border 1'ui, css"#000000"
          cornerRadius 10.0
          justify FontHorizontal.Center
          align FontVertical.Middle
          font defaultFont
        if this.textChanged(""):
          # set default
          this.text("00:00:00")

      # Test text input
      Input.new "input":
        with this:
          size 40'pp, 50'ux
          align Middle
          justify Center
          font defaultFont
          foreground css"black"
          fill css"white"
          border 1'ui, css"black"
          cornerRadius 10.0
        if not this.textChanged(""):
          # set default
          echo "SET DEFAULT TEXT"
          text(this, "00:00:00")

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 240'ui))
startFiguro(frame)
