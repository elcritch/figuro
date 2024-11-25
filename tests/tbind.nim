import figuro/widgets/button
import figuro/widget
import figuro


let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)
  largeFont = UiFont(typefaceId: typeface, size: 28)

type
  Main* = ref object of Figuro
    value: int
    counter = Property[int]()

proc draw*(self: Main) {.slot.} =
  self.name.setLen(0)
  self.name.add "main"
  with self:
    fill css"#9F2B00"
    size 100'pp, 100'pp

  var node = self
  rectangle "count":
    with node:
      cornerRadius 10.0
      box 40'ux, 30'ux, 80'ux, 40'ux
      fill css"#3B70DF"
    text "btnText":
      bindProp(self.counter)
      with node:
        box 0'pp, 0'pp, 100'pp, 100'pp
        fill blackColor
        setText({font: $self.counter.value & " ₿" }, Center, Middle)

  Button.new "btnAdd":
    box node, 160'ux, 30'ux, 80'ux, 40'ux
    text "btnText":
      with node:
        size 100'pp, 100'pp
        fill blackColor
        setText({largeFont: "–"}, Center, Middle)
    ## something like this:
    self.counter.onSignal(doButton) do(counter: Property[int]):
      counter.update(counter.value-1)

  Button.new "btnSub":
    box node, 240'ux, 30'ux, 80'ux, 40'ux
    text "btnText":
      with node:
        size 100'pp, 100'pp
        fill blackColor
        setText({largeFont: "+"}, Center, Middle)
    self.counter.onSignal(doButton) do(counter: Property[int]):
      counter.update(counter.value+1)


var main = Main.new()
let frame = newAppFrame(main, size=(400'ui, 140'ui))
startFiguro(frame)
