import figuro/widgets/[button, horizontal]
import figuro/ui/animations
import figuro

let
  typeface = defaultTypeface()
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of Figuro
    bkgFade* = Fader(minMax: 0.0..0.18,
                     inTimeMs: 600, outTimeMs: 500)

proc update*(fig: Main) {.signal.}

proc fading*(self: Main, value: tuple[amount, perc: float], finished: bool) {.slot.} =
  refresh(self)

proc btnHover*(self: Main, evtKind: EventKind) {.slot.} =
  ## activate fading on hover, deactive when not hovering
  self.bkgFade.startFade(evtKind == Init)
  refresh(self)

proc btnTick*(self: Button[int]) {.slot.} =
  ## slot to increment a button on every tick 
  self.state.inc
  refresh(self)

proc btnClicked*(self: Button[int],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  ## slot to increment a button when clicked
  ## clicks have a type of `(EventKind, UiButtonView)` 
  ## which we can use to check if it's a mouse click
  if kind == Done:
    if buttons in [{MouseLeft}, {DoubleClick}, {TripleClick}]:
      self.state.inc
      refresh(self)
    elif buttons == {MouseRight}:
      self.state.dec
      refresh(self)

proc initialize*(self: Main) {.slot.} =
  self.setTitle("Click Test!")
  self.bkgFade.addTarget(self)
  connect(self.bkgFade, fadeTick, self, Main.fading())

proc draw*(self: Main) {.slot.} =
  ## draw slot for Main widget called whenever an event
  ## triggers a node or it's parents to be refreshed
  withRootWidget(self):
    this.setName "main"

    # Calls the widget template `rectangle`.
    # This creates a new basic widget node. Generally used to draw generic rectangles.
    Rectangle as "body":
      with this:
        # sets the bounding box of this node
        box 10'ux, 10'ux, 600'ux, 120'ux
        cornerRadius 10.0'ui
        # `fill` sets the background color. Color apis use the `chroma` library
        fill blackColor * (self.bkgFade.amount)

      # sets up horizontal widget node with alternate syntax
      Horizontal as "horiz": # same as `horizontal "horiz":`
        with this:
          box 10'ux, 0'ux, 100'pp, 100'pp
          # `contentWidth` is needed to set the width of items
          # in the horizontal widget
          contentWidth 100'ux, gap = 20'ui
          layoutItems justify=CxCenter, align=CxCenter

        for idx in 0 .. 4:
          capture idx:
            Button[int] as "btn":
              let btn = this
              with this:
                size 100'ux, 100'ux
                cornerRadius 5.0'ui
                connect(doHover, self, btnHover)
                connect(doMouseClick, this, btnClicked)
              if idx == 0:
                connect(self, update, this, btnTick)
              Text as "":
                with this:
                  foreground blackColor
                  align Middle
                  justify Center
                  text({font: $(btn.state)})

proc tick*(self: Main, time: MonoTime, delta: Duration) {.slot.} =
  emit self.update()

var main = Main.new()
var frame = newAppFrame(main, size=(700'ui, 200'ui))
startFiguro(frame)
