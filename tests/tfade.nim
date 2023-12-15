
## This minimal example shows 5 blue squares.
import figuro/widgets/[horizontal, button]
import figuro/ui/animations
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    bkgFade* = FadeAnimation(minMax: 0.0..0.15,
                             incr: 0.010, decr: 0.005)

proc buttonHover*(self: Main, evtKind: EventKind) {.slot.} =
  ## activate fading on hover, deactive when not hovering
  self.bkgFade.isActive(evtKind == Enter)
  refresh(self)

proc draw*(self: Main) {.slot.} =
  var node = self
  rectangle "body":
    with node:
      box 10'ux, 10'ux, 600'ux, 120'ux
      cornerRadius 10.0
      fill whiteColor.darken(self.bkgFade.amount)
    horizontal "horiz":
      offset node, 10'ux, 0'ux
      itemWidth node, cx"min-content", gap = 20'ui
      for i in 0 .. 4:
        button "btn", captures(i):
          size node, 100'ux, 100'ux
          connect(node, doHover, self, buttonHover)

proc tick*(self: Main, tick: int, now: MonoTime) {.slot.} =
  self.bkgFade.tick(self)

var main = Main.new()
let frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
