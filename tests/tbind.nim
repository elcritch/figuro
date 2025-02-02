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
    with node:
      setName "main"
      fill css"#9F2B00"
      size 100'pp, 100'pp

    rectangle "count":
      with node:
        cornerRadius 10.0
        box 40'ux, 30'ux, 80'ux, 40'ux
        fill css"#3B70DF"
      text "btnText":
        # bindProp(self.counter)
        with node:
          box 0'pp, 0'pp, 100'pp, 120'pp
          fill blackColor
          setText({font: $self.counter{} & " ₿" }, Center, Middle)
        echo "UPDATED: "

    Button as "btnAdd":
      box node, 160'ux, 30'ux, 80'ux, 40'ux
      text "btnText":
        with node:
          size 100'pp, 120'pp
          fill blackColor
          setText({largeFont: "+"}, Center, Middle)
      ## something like this:
      onSignal(doClicked, to=self) do(self: Main):
        echo "PLUS"
        self.counter <- self.counter{} + 1

    Button as "btnSub":
      box node, 240'ux, 30'ux, 80'ux, 40'ux
      text "btnText":
        with node:
          size 100'pp, 120'pp
          fill blackColor
          setText({largeFont: "-"}, Center, Middle)
      onSignal(doClicked, to=self) do(self: Main):
        self.counter <- self.counter{} - 1


var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 140'ui))
startFiguro(frame)
