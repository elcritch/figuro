
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widgets/scrollpane
import figuro/widgets/vertical
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withDraw self:
    fill "#0000AA"
    name "root"
    scroll "scroll":
      offset 2'pp, 2'pp
      cornerRadius 7.0'ux
      size 96'pp, 90'pp
      fig.settings.size.y = 20'ui
      contents "children":
        vertical "":
          # Setup CSS Grid Template
          offset 10'ux, 10'ux
          itemHeight cx"max-content"
          for i in 0 .. 15:
            button "button", captures(i):
              # current.gridItem = nil
              size 1'fr, 50'ux
              if i in [3, 7]:
                size 0.9'fr, 120'ux
              fill rgba(66, 177, 44, 197).to(Color).spin(i.toFloat*50)
              connect(current, doHover, self, Main.hover)

var main = Main.new()

app.width = 600
app.height = 480

startFiguro(main)
