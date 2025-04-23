import figuro/widgets/button
import figuro
import figuro/ui/animations
let
  typeface = defaultTypeface()
  font = UiFont(typefaceId: typeface, size: 16)

type
  Counter* = object

  FadeKinds* = enum
    FkBlur, FkSpread, FkRadius, FkX, FkY

  Main* = ref object of Figuro
    mainRect: Figuro
    toggles*: array[FadeKinds, bool]
    fades*: array[FadeKinds, Fader]


proc initialize*(self: Main) {.slot.} =
  for i in FadeKinds.toSeq():
    self.toggles[i] = true
    self.fades[i] = Fader(minMax: 0.01..22.0,
                          inTimeMs: 1400, outTimeMs: 1400)
  # self.fades[FkRadius] = Fader(minMax: 4..22.0,
  #                         inTimeMs: 1400, outTimeMs: 1400)

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    fill css"grey"
    # fill css"white"

    for i, idx in FadeKinds.toSeq():
      capture i, idx:
        TextButton[FadeKinds] as "btn":
          this.state = idx
          with this:
            box 200'ux+30'pp, ux(30+i*70), 200'ux, 50'ux
            cornerRadius 10'ui
          label this, {defaultFont(): "Fade " & $this.state & " " & $self.fades[this.state].amount.round(2)}
          onSignal(doSingleClick) do(this: TextButton[FadeKinds]):
            let self = this.queryParent(Main).get()
            if self.toggles[this.state]:
              self.fades[this.state].fadeIn()
            else:
              self.fades[this.state].fadeOut()
            self.toggles[this.state] = not self.toggles[this.state]

    Button[int] as "btn":
      with this:
        box 40'ux, 30'ux, 30'pp, 30'pp
        fill css"#2B9F2B"
        # fill clearColor
        # fill css"#2B9F2B" * 0.5
        border 3'ui, css"red"
        cornerRadius self.fades[FkRadius].amount.UiScalar
      for i in FadeKinds.toSeq():
        self.fades[i].addTarget(this)
      echo "blur: ", self.fades[FkBlur].amount, " spread: ", self.fades[FkSpread].amount, " x: ", self.fades[FkX].amount, " y: ", self.fades[FkY].amount
      when true:
        this.shadow[DropShadow] = Shadow(
          # blur: self.blur.minMax.b.UiScalar - self.blur.amount.UiScalar + 0.1.UiScalar,
          blur: self.fades[FkBlur].amount.UiScalar,
          spread: self.fades[FkSpread].amount.UiScalar,
          x: self.fades[FkX].amount.UiScalar, y: self.fades[FkY].amount.UiScalar,
          color: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.99))
      when true:
        this.shadow[InnerShadow] = Shadow(
          # blur: self.blur.minMax.b.UiScalar - self.blur.amount.UiScalar + 0.1.UiScalar,
          blur: self.fades[FkBlur].amount.UiScalar,
          spread: self.fades[FkSpread].amount.UiScalar,
          x: self.fades[FkX].amount.UiScalar,
          y: self.fades[FkY].amount.UiScalar,
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

echo "DONE"