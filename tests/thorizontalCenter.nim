
## This minimal example shows 5 blue squares.
import figuro/widgets/[button, horizontal, griddebug]
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
  withWidget(self):
    Rectangle.new "body":
      with this:
        box 5'pp, 5'pp, 90'pp, 600'ux
        cornerRadius 10.0'ui
        fill whiteColor.darken(self.hoveredAlpha)
        border 3'ui, blueColor
        
      GridDebug.new "debug-grid":
        this.state = (blackColor, "horiz")
      GridDebug.new "debug-grid":
        this.state = (blackColor, "horiz2")

      Horizontal.new "horiz":
        offset this, 0'ux, 0'ux
        size this, 100'pp, 200'ux
        contentWidth this, 1'fr, gap = 20'ui
        border this, 3'ui, css"#00ff00"
        for i in 0 .. 3:
          capture i:
            Button[int].new "btn":
              with this:
                size 100'ux, 100'ux
                # we need to connect the nodes onHover event
                connect(doHover, self, buttonHover)

      Horizontal.new "horiz2":
        offset this, 0'pp, 200'ux
        size this, 100'pp, 20'pp
        contentWidth this, cx"max-content", gap = 20'ui
        border this, 3'ui, css"#ff0000"
        for i in 0 .. 3:
          capture i:
            Button[int].new "btn":
              with this:
                fill blackColor
                size 50'ux, 50'ux
                # we need to connect the nodes onHover event
                connect(doHover, self, buttonHover)

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 640'ui))
startFiguro(frame)
