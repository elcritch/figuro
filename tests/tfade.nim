
## This minimal example shows 5 blue squares.
import figuro/widgets/[horizontal, button]
import figuro/ui/animations
import figuro

import sugar

type
  Main* = ref object of Figuro
    bkgFade* = Fader(minMax: 0.0..0.18,
                     inTimeMs: 600, outTimeMs: 500)

proc initialize*(self: Main) {.slot.} =
  self.setTitle("Click Test!")
  self.bkgFade.addTarget(self)

proc buttonHover*(self: Main, evtKind: EventKind) {.slot.} =
  ## activate fading on hover, deactive when not hovering
  if evtKind == Init:
    self.bkgFade.fadeIn()
  else:
    self.bkgFade.fadeOut()
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withWidget(self):
    rectangle "body":
      usingHorizontalLayout cx"min-content", gap = 20'ui

      box 10'ui, 10'ui, 600'ui, 120'ui
      cornerRadius 10.0'ui
      fill whiteColor.darken(self.bkgFade.amount)

      for i in 0 .. 4:
        capture i:
          Button.new "btn":
            size this, 100'ux, 100'ux
            connect(this, doHover, self, buttonHover)

# proc tick*(self: Main, now: MonoTime, delta: Duration) {.slot.} =
#   self.bkgFade.tick(self)
#   echo "TICK", now

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
