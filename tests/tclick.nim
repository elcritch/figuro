import figuro/widgets/button
import figuro/widgets/horizontal
import figuro/widget
import figuro/ui/animations
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of Figuro
    backgroundFade* = FadeAnimation(minMax: 0.0..0.15,
                                    incr: 0.010,
                                    decr: 0.005)

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

proc hovered*[T](self: Button[T], kind: EventKind) {.slot.} =
  echo "button:hovered: ", kind, " :: ", self.getId

proc tick*(self: Main, tick: int, time: MonoTime) {.slot.} =
  if self.backgroundFade.tick(self):
    emit self.update()

proc btnHover*(self: Main, evtKind: EventKind) {.slot.} =
  echo "hover: ", evtKind == Enter
  self.backgroundFade.isActive(evtKind == Enter)
  refresh(self)

proc draw*(self: Main) {.slot.} =
  nodes(self):
    node.setName "main"

    rectangle "body":
      with node:
        box 10'ux, 10'ux, 600'ux, 120'ux
        cornerRadius 10.0
        fill whiteColor.darken(self.backgroundFade.alpha)
      horizontal "horiz":
        with node:
          box 10'ux, 0'ux, 100'pp, 100'pp
          itemWidth 100'ux, gap = 20'ui
          layoutItems justify=CxCenter, align=CxCenter

        for i in 0 .. 4:
          Button[int].new("btn", captures(i)):
            let btn = node
            with node:
              size 100'ux, 100'ux
              connect(doHover, self, btnHover)
              connect(doClick, node, btnClicked)
            if i == 0:
              connect(self, update, node, btnTick)

            text "text":
              with node:
                fill blackColor
                setText({font: $(btn.state)}, Center, Middle)

var main = Main.new()

app.width = 720
app.height = 140
startFiguro(main)
