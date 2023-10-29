import figuro/widgets/buttonWrap
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
  withDraw(self):
    self.name.setLen(0)
    self.name.add "main"

    rectangle "body":
      box 10'ux, 10'ux, 600'ux, 120'ux
      cornerRadius 10.0
      fill whiteColor.darken(self.hoveredAlpha).
                      spin(10*self.hoveredAlpha)
      for i in 0 .. 4:
        button("btn", state(int), captures(i)):
          let btn = current
          box ux(10 + i*120), 10'ux, 100'ux, 100'ux

          connect(current, doHover, self, Main.hover)
          connect(current, doClick, current, btnClicked)
          if i == 0:
            connect(self, update, current, btnTick)

          contents "child":
            text "text":
              box 10'ux, 10'ux, 80'pp, 80'pp
              fill blackColor
              setText({font: $(btn.state)})

var main = Main.new()

app.width = 720
app.height = 140
startFiguro(main)
