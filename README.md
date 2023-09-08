
# Figuro

An (experimental) UI toolkit for Nim. It's based on Fidget, though will likely begin to diverge significantly.

The core idea is to split it into two main pieces:

1. Widget / UI Application
2. Rendering Engine

## Demo

```sh
git clone https://github.com/elcritch/figuro
cd figuro/
atlas replay atlas.lock
nim c -r "tests/tclick.nim" 
```

## Updates

Note much of the below has been completed in some form, but the descriptions likely aren't 100% accurate anymore.


## Widget and Application Layer

The UI Application side will draw UI Nodes using widgets. Widgets will comprise of objects with base set of proc's and various signals / slots. Each widget will then use a Fidget-like API to draw themselves.

All of the widgets will share the same UI Node roots, similar to Fidget. However, events will be handled using slots and signals. Ideally this gives us the best of both worlds: immediate mode like drawing, with traditional event systems, and out-of-order drawing. This should resolve the ordering issues with Fidget / Fidgetty when dealing with overlapping widgets.

## Render Engine

Once the UI Application has finished drawing, it "serializes" the UI Figuro Nodes into a flattened list of Render Nodes. These Render Nodes are designed to be fast to copy by reducing allocations.

This will enable the render enginer to run on in a shared library while the widget / application layer runs in a NimScript.

## Widget Model

Example widget which are called Figuros:

```nim
import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self)

proc tick*(self: Main) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)

proc draw*(self: Main) {.slot.} =
  var current = self
  # current = self
  rectangle "body":
    self.mainRect = current
    box 10, 10, 600, 120
    cornerRadius 10.0
    fill whiteColor.darken(self.hoveredAlpha).spin(10*self.hoveredAlpha)
    for i in 0 .. 4:
      button "btn", captures(i):
          box 10 + i * 120, 10, 100, 100
          # echo nd(), "btn: ", i
          # we need to connect it's onHover event
          connect(current, onHover, self, Main.hover)
          # unfortunately, we have many hovers
          # so we need to give hover a type 
          # perfect, the slot pragma adds all this for
          # us

var main = Main.new()
connect(main, onDraw, main, Main.draw)
connect(main, onTick, main, Main.tick)

app.width = 720
app.height = 140
startFiguro(main)
```

## Signals and Slots

Shamelessly stolen from QT.

```nim
import figuro
type
  Counter* = ref object of Figuro
    value: int
    avg: int

proc valueChanged*(tp: Counter, val: int) {.signal.}
proc avgChanged*(tp: Counter, val: float) {.signal.}

proc setValue*(self: Counter, value: int) {.slot.} =
  echo "setValue! ", value
  if self.value != value:
    self.value = value
  emit self.valueChanged(value)

proc value*(self: Counter): int =
  self.value

var
  a {.used.} = Counter()
  b {.used.} = Counter()
connect(a, valueChanged,
        b, setValue)
## or equivalently:
## connect(a, valueChanged,
##         b, Counter.setValue())
a.setValue(42)
assert a.value == 42
assert b.value == 42
```

## Docs

Well you can write some! Or not, but eventually I'll try to add some. First we need to actually have a widget and event system.

## Goal

Massive profits and world domination of course. ;) Failing that the ability to write cool UI apps easily, in pure Nim.
