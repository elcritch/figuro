
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
  nodes self:
    with node:
      fill css"#0000AA"
    ScrollPane.new "scroll":
      with node:
        offset 2'pp, 2'pp
        cornerRadius 7.0'ux
        size 96'pp, 90'pp
      node.settings.size.y = 20'ui
      contents "children":
        Vertical.new "":
          # Setup CSS Grid Template
          with node:
            offset 10'ux, 10'ux
            itemHeight cx"max-content"
          for i in 0 .. 15:
            Button.new "button", captures(i):
              # current.gridItem = nil
              with node:
                size 1'fr, 50'ux
                fill rgba(66, 177, 44, 197).to(Color).spin(i.toFloat*50)
              if i in [3, 7]:
                node.size 0.9'fr, 120'ux
              node.connect(doHover, self, Main.hover)

var main = Main.new()
let frame = newAppFrame(main, size=(600'ui, 480'ui))
startFiguro(frame)
