
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widgets/scrollpane
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

    scroll "scroll":
      # offset 20'ux, 20'ux
      # size 90'pp, 80'pp
      clipContent true
      contents "children":
        # Setup CSS Grid Template
        cornerRadius 10.0
        offset 10'ux, 10'ux
        setGridCols 1'fr
        setGridRows csAuto()
        gridAutoRows csContentMax()
        gridAutoFlow grRow
        justifyContent CxCenter

        for i in 0 .. 15:
          button "button", captures(i):
            # current.gridItem = nil
            size 1'fr, 50'ux
            if i == 3:
              size 0.9'fr, 120'ux
            fill rgba(66, 177, 44, 197).to(Color).spin(i.toFloat*50)
            connect(current, doHover, self, Main.hover)

var main = Main.new()
connect(main, doDraw, main, Main.draw)

echo "main: ", main.listeners

app.width = 600
app.height = 480

startFiguro(main)
