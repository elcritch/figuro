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

    Button[int] as "btn":
      with this:
        box 40'ux, 30'ux, 80'ux, 80'ux
        # fill css"#2B9F2B"
        fill clearColor
        border 1'ui, css"red"
      
      this.shadow[DropShadow] = Shadow(blur: 10.0'ui, spread: 10.0'ui, x: 2.0'ui, y: 2.0'ui,
                                  color: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.5))
      # this.shadow[InnerShadow] = Shadow(blur: 8.0'ui, x: 3.0'ui, y: 3.0'ui,
      #                             color: Color(r: 1.0, g: 1.0, b: 1.0, a: 0.5))

      Text.new "btnText":
        size 100'pp, 100'pp
        foreground blackColor
        justify Center
        align Middle
        text({font: "testing"})

var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 200'ui))
startFiguro(frame)
