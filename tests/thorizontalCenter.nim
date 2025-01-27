
## This minimal example shows 5 blue squares.
import figuro/widgets/[button, horizontal]
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool = false
    hoveredAlpha: float = 0.0

proc buttonHover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Init
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
  Rectangle.new "body":
    with node:
      box 5'pp, 5'pp, 90'pp, 600'ux
      cornerRadius 10.0
      fill whiteColor.darken(self.hoveredAlpha)
      border 3'ui, blackColor
       
    Horizontal.new "horiz":
      offset node, 0'ux, 0'ux
      size node, 100'pp, 200'ux
      itemWidth node, 1'fr, gap = 20'ui
      border node, 3'ui, css"#00ff00"
      for i in 0 .. 4:
        capture i:
          Button[int].new "btn":
            with node:
              size 100'ux, 100'ux
              # we need to connect the nodes onHover event
              connect(doHover, self, buttonHover)

    Horizontal.new "horiz2":
      offset node, 0'pp, 200'ux
      size node, 100'pp, 70'ux
      itemWidth node, 1'fr, gap = 20'ui
      border node, 3'ui, css"#ff0000"
      for i in 0 .. 4:
        capture i:
          Button[int].new "btn":
            with node:
              fill blackColor
              size 100'ux, 100'ux
              # we need to connect the nodes onHover event
              connect(doHover, self, buttonHover)

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 640'ui))
startFiguro(frame)
