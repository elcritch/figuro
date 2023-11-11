import figuro/widgets/button
import figuro/widgets/horizontal
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Counter* = object

  Main* = ref object of Figuro
    value: int
    hasHovered: bool
    hoveredAlpha: float

proc update*(fig: Main) {.signal.}

proc btnTick*(self: Button[int]) {.slot.} =
  self.state.inc
  # echo "btnTick: ", self.getid
  refresh(self)

proc btnClicked*(self: Button[int],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  if buttons == {MouseLeft} or buttons == {DoubleClick}:
    echo ""
    echo nd(), "tclick:button:clicked: ", self.state, " button: ", buttons
    if kind == Enter:
      self.state.inc
      refresh(self)

proc txtHovered*(self: Figuro, kind: EventKind) {.slot.} =
  echo "TEXT hover! ", kind, " :: ", self.getId

proc txtClicked*(self: Figuro,
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo "TEXT clicked! ", kind, " buttons ", buttons, " :: ", self.getId

proc hovered*[T](self: Button[T], kind: EventKind) {.slot.} =
  echo "button:hovered: ", kind, " :: ", self.getId

proc tick*(self: Main, tick: int, time: MonoTime) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)
  self.value.inc()
  emit self.update()

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self)

proc draw*(self: Main) {.slot.} =
  nodes(self):
    self.name.setLen(0)
    self.name.add "main"

    rectangle "body":
      with node:
        box 10'ux, 10'ux, 600'ux, 120'ux
        cornerRadius 10.0
        fill whiteColor.darken(self.hoveredAlpha).
                        spin(10*self.hoveredAlpha)
      horizontal "horiz":
        with node:
          box 10'ux, 0'ux, 100'pp, 100'pp
          itemWidth 100'ux, gap = 20'ui
          layoutItems justify=CxCenter, align=CxCenter

        for i in 0 .. 4:
          button[int]("btn", captures(i)):
            let btn = node
            with node:
              size 100'ux, 100'ux
              connect(doHover, self, Main.hover)
              connect(doClick, current, btnClicked)
            if i == 0:
              connect(self, update, current, btnTick)

            text "text":
              fill blackColor
              setText({font: $(btn.state)}, Center, Middle)

var main = Main.new()

app.width = 720
app.height = 140
startFiguro(main)
