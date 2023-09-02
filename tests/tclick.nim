
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = loadFont: GlyphFont(
      typefaceId: typeface,
      size: 44
    )

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc btnClicked*(self: Button[int],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo "tclick:button:clicked: ", self.state
  self.state.inc
  refresh(self)

proc hovered*[T](self: Button[T], kind: EventKind) {.slot.} =
  # self.fill = parseHtmlColor "#9BDFFA"
  # echo "button hover!"
  # echo "button:hovered: ", kind, " :: ", self.getId
  refresh(self)

proc tick*(self: Main) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)

proc draw*(self: Main) {.slot.} =
  # var current = self
  self.name.add "main"
  echo "\n\nmain:draw: ", current.getId, " parent: ", current.parent.getId

  rectangle "body":
    self.mainRect = current
    box 10, 10, 600, 120
    cornerRadius 10.0
    fill whiteColor.darken(self.hoveredAlpha).spin(10*self.hoveredAlpha)
    for i in 0 .. 4:
      # button "btn", i, typ = void:
      button int, "btn", i:
          box 10 + i * 120, 10, 100, 100
          static:
            echo "button draw: ", Button[int].draw().typeof.repr
            echo "button btnClicked: ",  Button[int].btnClicked().typeof.repr

          echo nd(), "button:draw: ", " :: ", current.getId, " name: ", current.name
          connect(current, onClick, current, Button[int].btnClicked())
          # connect(current, onDraw, current, draw)

          text "text":
            echo nd(), "text: ", current.getId, " parent: ", current.parent.getId
            box 10, 10, 20, 20
            fill blackColor
            setText(font, $widget.state)

var main = Main.new()

connect(main, onDraw, main, Main.draw())
connect(main, onTick, main, Main.tick())

echo "main: ", main.listeners

app.width = 720
app.height = 140

startFiguro(main)
