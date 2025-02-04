import figuro/widgets/button
import figuro


let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)
  largeFont = UiFont(typefaceId: typeface, size: 28)

type
  Main* = ref object of Figuro
    counter: Sigil[int]

proc initialize*(self: Main) {.slot.} =
  self.counter = newSigil(0)

proc draw*(self: Main) {.slot.} =
  withWidget(self):
    setName "main"
    fill css"#9F2B00"
    size 100'pp, 100'pp

    rectangle "count":
      cornerRadius 10.0'ui
      box 40'ux, 30'ux, 80'ux, 40'ux
      fill css"#3B70DF"
      Text.new "btnText":
        size 100'pp, 100'pp
        foreground blackColor
        justify Center
        align Middle
        text({font: $self.counter{} & " ₿" })

    Button as "btnSub":
      box 160'ux, 30'ux, 80'ux, 40'ux
      Text.new "btnText":
        size 100'pp, 100'pp
        foreground blackColor
        justify Center
        align Middle
        text({largeFont: "–"})
      onSignal(doClicked) do(self: Main):
        self.counter <- self.counter{} - 1

    Button as "btnAdd":
      box 240'ux, 30'ux, 80'ux, 40'ux
      Text.new "btnText":
        size 100'pp, 100'pp
        foreground blackColor
        justify Center
        align Middle
        text({largeFont: "+"})
      ## something like this:
      onSignal(doClicked) do(self: Main):
        self.counter <- self.counter{} + 1

var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 140'ui))
startFiguro(frame)
