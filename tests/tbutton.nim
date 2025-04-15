import figuro/widgets/button
import figuro
import figuro/ui/animations
let
  typeface = defaultTypeface()
  font = UiFont(typefaceId: typeface, size: 16)

type
  Counter* = object

  Main* = ref object of Figuro
    mainRect: Figuro
    toggle: bool = true
    toggleSpread: bool = true
    blur* = Fader(minMax: 0.01..22.0,
                     inTimeMs: 400, outTimeMs: 400)
    spread* = Fader(minMax: 0.01..12.0,
                     inTimeMs: 200, outTimeMs: 200)

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
        border 3'ui, css"red"
        cornerRadius 20'ui
      self.blur.addTarget(this)
      self.spread.addTarget(this)
      onSignal(doSingleClick) do(self: Main):
        if self.toggle:
          self.blur.fadeIn()
        else:
          self.blur.fadeOut()
        self.toggle = not self.toggle
      onSignal(doRightClick) do(self: Main):
        echo "doRightClick"
        if self.toggleSpread:
          self.spread.fadeIn()
        else:
          self.spread.fadeOut()
        self.toggleSpread = not self.toggleSpread

      # echo "blur: ", self.blur.amount, " spread: ", self.spread.amount
      when false:
        this.shadow[DropShadow] = Shadow(
          blur: self.blur.minMax.b.UiScalar - self.blur.amount.UiScalar + 0.1.UiScalar,
          # blur: self.blur.amount.UiScalar,
          # spread: self.spread.amount.UiScalar,
          spread: 0.0'ui,
          x: 0.0'ui,
          y: self.spread.amount.UiScalar,
          color: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.3))
      when true:
        this.shadow[InnerShadow] = Shadow(
          # blur: self.blur.minMax.b.UiScalar - self.blur.amount.UiScalar + 0.1.UiScalar,
          blur: self.blur.amount.UiScalar,
          spread: self.spread.amount.UiScalar,
          # x: 6.0'ui, y: 6.0'ui,
          x: 0'ui, y: 0'ui,
          color: Color(r: 1.0, g: 1.0, b: 1.0, a: 0.99))

      Text.new "btnText":
        size 100'pp, 100'pp
        foreground blackColor
        justify Center
        align Middle
        text({font: "testing"})

var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 200'ui))
startFiguro(frame)
