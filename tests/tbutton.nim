import figuro/widgets/button
import figuro

let
  typeface = defaultTypeface()
  font = UiFont(typefaceId: typeface, size: 16)

type
  Counter* = object

  Main* = ref object of Figuro
    mainRect: Figuro

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    fill css"grey"
    # fill css"white"

    Button[int] as "btn":
      with this:
        box 40'ux, 30'ux, 30'pp, 30'pp
        fill css"#2B9F2B"
        # fill clearColor
        # fill css"#2B9F2B" * 0.5
        border 1'ui, css"red"
        cornerRadius 30'ui
      
      when true:
        this.shadow[DropShadow] = Shadow(
          blur: 20.0'ui,
          spread: 10.0'ui,
          x: 4.0'ui,
          y: 2.0'ui,
          color: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.7))
      when false:
        this.shadow[InnerShadow] = Shadow(
          blur: 5.0'ui,
          spread: 5.0'ui,
          x: 0.0'ui, y: 6.0'ui,
          color: Color(r: 1.0, g: 1.0, b: 1.0, a: 0.5))

      Text.new "btnText":
        size 100'pp, 100'pp
        foreground blackColor
        justify Center
        align Middle
        text({font: "testing"})

var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 200'ui))
startFiguro(frame)
