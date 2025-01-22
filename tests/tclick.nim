import figuro/widgets/[button, horizontal]
import figuro/widget
import figuro/ui/animations
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of Figuro
    bkgFade* = FadeAnimation(minMax: 0.0..0.15,
                             incr: 0.010, decr: 0.005)

proc update*(fig: Main) {.signal.}


proc btnTick*(self: Button[int]) {.slot.} =
  ## slot to increment a button on every tick 
  self.state.inc
  refresh(self)
  # if self.state mod 10 == 0:
  #   quit(1)

proc btnClicked*(self: Button[int],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  ## slot to increment a button when clicked
  ## clicks have a type of `(EventKind, UiButtonView)` 
  ## which we can use to check if it's a mouse click
  if buttons == {MouseLeft} or buttons == {DoubleClick}:
    if kind == Enter:
      self.state.inc
      refresh(self)

proc btnHover*(self: Main, evtKind: EventKind) {.slot.} =
  ## activate fading on hover, deactive when not hovering
  self.bkgFade.isActive(evtKind == Enter)
  refresh(self)

proc draw*(self: Main) {.slot.} =
  ## draw slot for Main widget called whenever an event
  ## triggers a node or it's parents to be refreshed
  var node = self
  node.setName "main"

  # Calls the widget template `rectangle`.
  # This creates a new basic widget node. Generally used to draw generic rectangles.
  Rectangle.new "body":
    with node:
      # sets the bounding box of this node
      box 10'ux, 10'ux, 600'ux, 120'ux
      cornerRadius 10.0
      # `fill` sets the background color. Color apis use the `chroma` library
      fill whiteColor.darken(self.bkgFade.amount)

    # sets up horizontal widget node with alternate syntax
    Horizontal.new "horiz": # same as `horizontal "horiz":`
      with node:
        box 10'ux, 0'ux, 100'pp, 100'pp
        # `itemWidth` is needed to set the width of items
        # in the horizontal widget
        itemWidth 100'ux, gap = 20'ui
        layoutItems justify=CxCenter, align=CxCenter

      for idx in 0 .. 4:
        capture idx:
          Button[int].new("btn"):
            let btn = node
            with node:
              size 100'ux, 100'ux
              cornerRadius 5.0
              connect(doHover, self, btnHover)
              connect(doClick, node, btnClicked)
            if idx == 0:
              connect(self, update, node, btnTick)
            Text.new "text":
              with node:
                fill blackColor
                setText({font: $(btn.state)}, Center, Middle)

proc tick*(self: Main, time: MonoTime, delta: Duration) {.slot.} =
  self.bkgFade.tick(self)
  emit self.update()

var main = Main.new()
var frame = newAppFrame(main, size=(700'ui, 200'ui))
startFiguro(frame)
