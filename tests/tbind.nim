import figuro/widgets/button
import figuro/widget
import figuro


let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 16)
  largeFont = UiFont(typefaceId: typeface, size: 24)

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
      fill "#8F2B8B"
      node nkText, "btnText":
        box 40'pp, 10'ux, 80'pp, 80'pp
        fill blackColor
        bindProp(self.counter)
        setText({font: $self.counter.value})

    button "btnAdd":
      box 160'ux, 30'ux, 80'ux, 40'ux
      fill "#9F2B00"
      node nkText, "btnText":
        box 40'pp, 10'ux, 80'pp, 80'pp
        fill blackColor
        setText({largeFont: "+₿"})
      ## something like this:
      onEvent(doButton, self.counter) do(counter: Property[int]):
        counter.update(counter.value+1)

    button "btnSub":
      box 240'ux, 30'ux, 80'ux, 40'ux
      fill "#9F2B00"
      node nkText, "btnText":
        box 40'pp, 10'ux, 80'pp, 80'pp
        fill blackColor
        setText({largeFont: "–"})
      onEvent(doButton, self.counter) do(counter: Property[int]):
        counter.update(counter.value-1)



var main = Main.new()
connect(main, doDraw, main, Main.draw())

app.width = 400
app.height = 140
startFiguro(main)
