import figuro/widgets/button
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = loadFont: GlyphFont(typefaceId: typeface, size: 44)

type
  Counter* = object

  Main* = ref object of Figuro
    value: int
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc update*(fig: Figuro) {.signal.}

proc btnTick*(self: Button[int]) {.slot.} =
  # echo "BUTTON: TICK: ", self.getId
  self.state.inc
  refresh(self)

proc btnClicked*(self: Button[int],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo ""
  echo nd(), "tclick:button:clicked: ", self.state
  if kind == Enter:
    self.state.inc
    refresh(self)

proc txtHovered*(self: Figuro, kind: EventKind) {.slot.} =
  echo "TEXT hover! ", kind, " :: ", self.getId
  # refresh(self)

proc txtClicked*(self: Figuro,
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo "TEXT clicked! ", kind, " buttons ", buttons, " :: ", self.getId
  # refresh(self)

proc hovered*[T](self: Button[T], kind: EventKind) {.slot.} =
  # self.fill = parseHtmlColor "#9BDFFA"
  # echo "button hover!"
  echo "button:hovered: ", kind, " :: ", self.getId
  # refresh(self)

proc tick*(self: Main) {.slot.} =
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
      self.mainRect = current
      box 10, 10, 600, 120
      cornerRadius 10.0
      fill whiteColor.darken(self.hoveredAlpha).
                      spin(10*self.hoveredAlpha)
      let x = 10
      for i in 0 .. 4:
        button "btn", state(int), captures(i):
          box 10 + i*120, 10, 100, 100

          connect(current, onHover, self, Main.hover)
          connect(current, onClick, current, btnClicked)
          if i == 0:
            connect(self, update, current, btnTick)

          node nkText, "text":
            box 10, 10, 70, 70
            fill blackColor
            setText(font, $(Button[int](current.parent).state))
            connect(current, onClick, current, Figuro.txtClicked())
            bubble(onClick)
            connect(current, onHover, current, Figuro.txtHovered())

var main = Main.new()
connect(main, onDraw, main, Main.draw())
connect(main, onTick, main, Main.tick())

app.width = 720
app.height = 140
startFiguro(main)
