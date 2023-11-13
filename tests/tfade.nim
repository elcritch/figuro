
## This minimal example shows 5 blue squares.
import figuro/widgets/[horizontal, button]
import figuro/ui/animations
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool = false
    hoveredAlpha: float = 0.0

proc buttonHover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter

proc draw*(self: Main) {.slot.} =
  nodes(self):
    rectangle "body":
      with node:
        box 10'ux, 10'ux, 600'ux, 120'ux
        cornerRadius 10.0
        fill whiteColor.darken(self.hoveredAlpha)
      horizontal "horiz":
        offset node, 10'ux, 0'ux
        itemWidth node, cx"min-content", gap = 20'ui
        for i in 0 .. 4:
          button "btn", captures(i):
            size node, 100'ux, 100'ux
            connect(node, doHover, self, buttonHover)

proc tick*(self: Main, tick: int, now: MonoTime) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)

var main = Main.new()
startFiguro(main)
