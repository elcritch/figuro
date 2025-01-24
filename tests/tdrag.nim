import figuro/widgets/button
import figuro/ui/animations
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 16)

type
  Counter* = object

  Main* = ref object of Figuro
    bkgFade* = Fader(minMax: 0.0..0.18,
                     inTimeMs: 600, outTimeMs: 900)


proc btnDragStart*(node: Figuro,
                   kind: EventKind,
                   initial: Position,
                   cursor: Position
                  ) {.slot.} =
  # echo "btnDrag:start: ", node.getId, " ", kind
  discard

proc btnDragStop*(
    node: Button[(Fader, string)],
    kind: EventKind,
    initial: Position,
    cursor: Position
) {.slot.} =
  echo "btnDrag:exit: ", node.getId, " ", kind,
          " change: ", initial.positionDiff(cursor),
          " nodeRel: ", cursor.positionRelative(node)
  node.state[1] = "Item dropped!"
  node.state[0].fadeIn()
  refresh(node)

proc fading(self: Button[(Fader, string)], value: tuple[amount, perc: float], finished: bool) {.slot.} =
  # echo "fading: ", value.repr
  refresh(self)

proc draw*(self: Main) {.slot.} =
  # var node = self
  with self:
    setName "main"
    fill css"#9F2B00"
    box 0'ux, 0'ux, 400'ux, 300'ux

  let node = self
  var startBtn: Figuro
  Button.new "btn":
    startBtn = node
    with node:
      box 40'ux, 30'ux, 80'ux, 80'ux
      fill css"#2B9F2B"
      uinodes.connect(doDrag, node, btnDragStart)
      # uinodes.connect(doDrag, node, btnDragStop)

    text "btnText":
      with node:
        box 10'ux, 10'ux, 80'pp, 80'pp
        fill blackColor
        setText({font: "drag me"})

  Button[(Fader, string)].new "btn":
    block fading:
      self.bkgFade.addTarget(node)
      node.state[0] = self.bkgFade
      connect(self.bkgFade, fadeTick, node, fading)
    # echo "button:id: ", node.getId, " ", self.bkgFade.amount
    with node:
      box 200'ux, 30'ux, 80'ux, 80'ux
      fill css"#9F2B00".spin(50*self.bkgFade.amount)
    ## TODO: how to make a better api for this
    ## we don't want evDrag, only evDragEnd
    ## uinodes.connect only has doDrag signal
    connect(node, doDrag, node, btnDragStop)
    node.listens.signals.incl {evDragEnd}
    let btn = node
    proc clicked(btn: Button[(Fader, string)],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
      btn.state[1] = ""
      btn.state[0].fadeOut()
      refresh(btn)
    uinodes.connect(node, doClick, node, clicked)
    text "btnText":
      with node:
        fill blackColor * self.bkgFade.amount / self.bkgFade.minMax.b
        setText({font: btn.state[1]}, Center, Middle)

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 140'ui))
startFiguro(frame)
