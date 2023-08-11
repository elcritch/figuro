
# Figuro

An (experimental) UI toolkit for Nim. It's based on Fidget, though will likely begin to diverge significantly.

The core idea is to split it into two main pieces:

1. Widget / UI Application
2. Rendering Engine

## Demo

```sh
atlas replay
nim c -r "tests/twidget.nim" 
```

## Widget and Application Layer

The UI Application side will draw UI Nodes using widgets. Widgets will comprise of objects with base set of proc's and various signals / slots. Each widget will then use a Fidget-like API to draw themselves.

All of the widgets will share the same UI Node roots, similar to Fidget. However, events will be handled using slots and signals. Ideally this gives us the best of both worlds: immediate mode like drawing, with traditional event systems, and out-of-order drawing. This should resolve the ordering issues with Fidget / Fidgetty when dealing with overlapping widgets.

## Render Engine

Once the UI Application has finished drawing, it "serializes" the UI Figuro Nodes into a flattened list of Render Nodes. These Render Nodes are designed to be fast to copy by reducing allocations.

This will enable the render enginer to run on in a shared library while the widget / application layer runs in a NimScript.

## Widget Model

Example widget which are called Figuros:

```nim
type
  Button* = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool

...

proc draw*(self: Button) {.slot.} =
  ## button widget!  
  clipContent true

  if self.disabled:
    fill "#FF0000"
  else:
    fill "#2B9FEA"
    onHover:
      fill "#00FF00"
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
a.setValue(42)
check a.value == 42
check b.value == 42
```

## Docs

Well you can write some! Or not, but eventually I'll try to add some. First we need to actually have a widget and event system.

## Goal

Massive profits and world domination of course. ;) Failing that the ability to write cool UI apps easily, in pure Nim.
