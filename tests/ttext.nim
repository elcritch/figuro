
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 20'ui)
  smallFont = UiFont(typefaceId: typeface, size: 13'ui)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Init
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    rectangle "main":
      with this:
        cssEnable false
        box 10'ux, 10'ux, 600'ux, 120'ux
        cornerRadius 10.0
        fill css"#2A9EEA" * 0.7
      Text.new "text":
        with this:
          cssEnable false
          box 10'ux, 10'ux, 400'ux, 100'ux
          foreground blackColor
          align Top
          text({font: "hello world!",
                smallFont: "It's a small world"})
      Text.new "text":
        with this:
          box 10'ux, 10'ux, 400'ux, 100'ux
          cssEnable false
          foreground blackColor
          align Middle
          text({font: "hello world!",
                smallFont: "It's a small world"})
      Text.new "text":
        with this:
          cssEnable false
          box 10'ux, 10'ux, 400'ux, 100'ux
          foreground blackColor
          align Bottom
          text({font: "hello world!",
                smallFont: "It's a small world"})
      Rectangle.new "main":
        with this:
          cssEnable false
          box 10'ux, 10'ux, 400'ux, 100'ux
          fill whiteColor * 0.33

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
