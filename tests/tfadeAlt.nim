
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widgets/horizontal
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool = false
    hoveredAlpha: float = 0.0

proc buttonHover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self)

proc tick*(self: Main, now: MonoTime, delta: Duration) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)

proc draw*(self: Main) {.slot.} =
  var node = self
  BasicFiguro.new "body":
    with node:
      box 10'ux, 10'ux, 600'ux, 120'ux
      cornerRadius 10.0
      fill whiteColor.darken(self.hoveredAlpha)
    Horizontal.new "horiz":
      offset node, 10'ux, 0'ux
      itemWidth node, cx"min-content", gap = 20'ui
      for i in 0 .. 4:
        capture i:
          Button[int].new "btn":
            with node:
              size 100'ux, 100'ux
              # we need to connect the nodes onHover event
              connect(doHover, self, buttonHover)

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
