import figuro/widgets/buttonWrap
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 16)
  largeFont = UiFont(typefaceId: typeface, size: 24)

type
  Counter* = object

  Main* = ref object of Figuro
    value: int
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro
    counter = Property[int]()

proc btnDrag*(node: Figuro,
              kind: EventKind,
              initial: Position,
              cursor: Position) {.slot.} =
  echo "btnDrag: ", node.getId, " ", kind,
          " change: ", initial.positionDiff(cursor),
          " nodeRel: ", cursor.positionRelative(node)

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
        setText({largeFont: "+"})
      proc incr(counter: Property[int]) =
        counter.update(counter.value+1)
      proc incr(counter: Property[int], ek: EventKind, b: UiButtonView) {.slot.} =
        echo "incr: ", counter.value
        if ek == Enter: incr(counter)
      connect(current, doClick, self.counter, incr)

    button "btnSub":
      box 240'ux, 30'ux, 80'ux, 40'ux
      fill "#9F2B00"
      node nkText, "btnText":
        box 40'pp, 10'ux, 80'pp, 80'pp
        fill blackColor
        setText({largeFont: "–"})

      proc decr(counter: Property[int], ek: EventKind, b: UiButtonView) {.slot.} =
        echo "decr: ", counter.value
        if ek == Enter:
          counter.update(counter.value-1)
      connect(current, doClick, self.counter, Property[int].decr())


var main = Main.new()
connect(main, doDraw, main, Main.draw())

app.width = 400
app.height = 140
startFiguro(main)
