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
  withDraw(self):
    self.name.setLen(0)
    self.name.add "main"
    fill "#9F2B00"
    size 100'pp, 100'pp

    rectangle "count":
      cornerRadius 10.0
      box 40'ux, 30'ux, 80'ux, 40'ux
      fill "#BF4BAB"
      node nkText, "btnText":
        box 0'pp, 0'pp, 100'pp, 100'pp
        fill blackColor
        bindProp(self.counter)
        setText({font: $self.counter.value & " ₿" }, Center, Middle)

    button "btnAdd":
      box 160'ux, 30'ux, 80'ux, 40'ux
      fill "#9F2B00"
      node nkText, "btnText":
        size 100'pp, 100'pp
        fill blackColor
        setText({largeFont: "+"}, Center, Middle)
      ## something like this:
      self.counter.onSignal(doButton) do(counter: Property[int]):
        counter.update(counter.value+1)

    button "btnSub":
      box 240'ux, 30'ux, 80'ux, 40'ux
      fill "#9F2B00"
      node nkText, "btnText":
        size 100'pp, 100'pp
        fill blackColor
        setText({largeFont: "–"}, Center, Middle)
      self.counter.onSignal(doButton) do(counter: Property[int]):
        counter.update(counter.value-1)



var main = Main.new()
connect(main, doDraw, main, Main.draw())

app.width = 400
app.height = 140
startFiguro(main)
