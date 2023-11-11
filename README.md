
# Figuro

An (experimental) UI toolkit for Nim. It's based on Fidget, though will likely begin to diverge significantly.

The core idea is to split it into two main pieces:

1. Widget / UI Application
2. Rendering Engine

## Trying it out

Note that you *have* to follow these instructions. Using the normal Atlas installation *won't* give you the correct packages.

```sh
# recommended to install an up to date atlas
nimble install 'https://github.com/nim-lang/atlas@#head'

# new atlas workspace
mkdir fig_ws && cd fig_ws
atlas init --deps=vendor

# get deps
git clone https://github.com/elcritch/figuro.git

# sync deps
atlas replay --cfgHere --ignoreUrls figuro/atlas.lock
nim c -r figuro/tests/tclick.nim
```

![Click Example](tests/tclick-screenshot.png)

Currently during the early development only Atlas with `atlas.lock` files are intended to work. Nimble lock files are updated but may or may not work.

Eventually these issues will be resolved.

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
  withDraw(self):
    # current = self
    rectangle "body":
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

## Goal

Massive profits and world domination of course. ;) Failing that the ability to write cool UI apps easily, in pure Nim.

## Docs

Initial docs section.

### Useful Compilation Flags

- `-d:debugLayout` prints a node tree with the layout of each node before and after computing a layout
- `-d:debugEvents` prints the events received from Windy and which nodes got the events

### Drawing model

Each widget must inherit from the `Fidget` type. `Fidget` itself inherits from `Agent` which means it can work with signals & slots.

Each widget is composed of a `draw` slot and a widget-macro which is exported using `exportWidget`. Draw slots expect the widget object to already be created.

The purpose of the widget macro which sets up a new block, calls `preNode()` and `postNode()` with the user code inserted into a anonymous callback. This callback is called by the `postNode()` proc by emitting a `doDraw` signal.

Each `doDraw` signal on a widget is connected to multiple slots which ready a widget for drawing, runs pre-draw callbacks, run any widget draw slot, and runs post-draw callbacks. User code passed to the widget-macros become the pre-draw callback for that widget instance. For advanced needs, a post-draw callback can be manually supplied.  

### Layout and Controlling Widget Size and Position

There are two modes of layout: basic and grid. Both of these use the same core set of layout constraints which can be used to configued the width & height or the offset in x & y. Normally layout constraints are referred to as just constraints for brevity. The basic APIs are `box`, `size`, and `offset` which all set layout constraints. Each widget has a `box` which can manually set the position, but can be overwritten by the layout system. It's recommended to avoid directly modifying it. Instead set `cxOffset` and `cxSize`.

Simple example:

```nim
proc draw*(self: Main) {.slot.} =
  nodes self:
    fill "#0000AA"
    size 100'pp, 100'pp ## this will set to 100 percent
                        ## of the parents width and height
                        ## Note this is a root object
                        ## so it's parent is considered the window
                        ## size
    rectangle "container":
      offset 20'ux, 20'ux ## offsets container 20'ux (aka 20'ui) points
      size 90'pp, 80'pp ## sets width to 90 perc and 80 percent of parents width
      clipContent true
      cornerRadius 10.0
      text "val":
        ## No size or position given defaults to `UiNone`. This defaults
        ## to the free size of it's parent after offsets are subtracted
        setText({font: "hello world!"}, Center, Middle)

```

The layout constraints are modeled on [CSS Grid](https://css-tricks.com/snippets/css/complete-guide-grid/) and for more advanced layouts understanding CSS Grid will be helpful. The reason for this is that CSS Grid is one of the most flexible layout systems avaialable on the web and yet remains simple to use once you understand the basics, unlike alternatives like flexbox or even raw table layouts.

Note that the easiest way to set layout constraint values are to use their numeric literal types. These are:

- `1'fr` for fraction
- `1'ux` for fixed ui coordinates
- `100'pp` for percentage
- `cx"auto"` or `csAuto()` is the default and uses the full available size of it's parent size (current.wh = parent.wh - current.xy)
- `1'ux` is equivalent to `1'ui` which is just a UICoord scalar
- `ux(1+i*2)` to convert expressions to fixed ui coordinates
- `cs"min-content"` minimum content size (currently grid layout only)
- `cs"max-content"` minimum content size (currently grid layout only)

Helper proc's for formula based constraints are `csFixed(x)`, `csMin(x,y)`, `csMax(x,y)`, `csMinMax(x,y)`, and `csMinMax(x,y)`. Note that the multi-argued constraints are still a WIP and don't work currently.

Internally a layout constraint, normally shortened to just *constraint*, is formed from two pieces: the `Constraint` container object and an optional inner `ConstraintSize` object. 

#### CSS Grid Layout

A CSS Grid layout allows you to create either a fixed pre-sized grid or a dynamically expandable grid.

##### CSS Grid Automatic Vertical Layout

This example shows how to setup a *vertical group* using a CSS Grid with one full width column (set by `setGridCols 1'fr`). It grows by adding new rows with a height of `60ux` (set by `gridAutoRows 60ux`) whenver more child widgets are added. Items are vertically aligned (`alignItems CxStart`) and horizontally justified (`justifyItems CxCenter`). The child widgets have their sizes set to `size 60'ux, 40'ux`. Alternatively `CxStretch` could be used to force the child widgets to take up a whole column and row.

```nim
    rectangle "main":
      fill whiteColor
      offset 30'ux, 10'ux
      size 400'ux, 120'ux

      setGridCols 1'fr
      setGridRows 60'ux
      gridAutoRows 60'ux
      gridAutoFlow grRow
      justifyItems CxCenter
      alignItems CxStart

      rectangle("slider"):
        size 60'ux, 40'ux
        fill "#00A0AA"
      rectangle "slider":
        size 60'ux, 40'ux
        fill "#A000AA"
```

#### Constraint Reference Table

Here's the full list of options (see CSS Grid for more details): 

```nim
type
  ConstraintSizes* = enum
    UiAuto ## default size option for nodes
           ## it's the size of the parent width/height 
           ## minus the x/y positions of the node
    UiFrac ## represents `fr` aka CSS Grid fractions
    UiPerc ## represents percentage of parent box or grid
    UiFixed ## represents fixed coordinate size
    UiContentMin ## represents layout to use min-content, `cmin` is calculated internally
    UiContentMax ## represents layout to use max-content, `cmax` is calculated internally

  Constraints* = enum
    UiValue ## holds a single `ConstraintSize`
    UiMin ## minimum of lhs and rhs (partially supported)
    UiMax ## maximum of lhs and rhs (partially supported)
    UiSum ## sum of lhs and rhs (partially supported)
    UiMinMax ## min-max of lhs and rhs (partially supported)
    UiNone ## none item - excluded from CSS Grid layout & basic layout
    UiEnd ## marks end track of a CSS Grid layout
```

