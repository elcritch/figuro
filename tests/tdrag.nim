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

proc btnDragStart*(this: Figuro,
                   kind: EventKind,
                   initial: Position,
                   cursor: Position
                  ) {.slot.} =
  echo "btnDrag:start: ", this.getId, " ", kind
  discard

proc btnDragStop*(
    this: Button[(Fader, string)],
    kind: EventKind,
    initial: Position,
    cursor: Position
) {.slot.} =
  echo "btnDrag:exit: ", this.getId, " ", kind,
          " change: ", initial.positionDiff(cursor),
          " thisRel: ", cursor.positionRelative(this)
  this.state[1] = "Item dropped!"
  this.state[0].fadeIn()
  refresh(this)

proc fading(self: Button[(Fader, string)], value: tuple[amount, perc: float], finished: bool) {.slot.} =
  # echo "fading: ", value.repr
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    setTitle "Dragging Example"

    var startBtn: Figuro
    Button.new "btn":
      startBtn = this
      box 40'ux, 30'ux, 100'ux, 100'ux
      fill css"#2B9F2B"
      connect(doDrag, this, btnDragStart)

      Text.new "btnText":
        align Middle
        justify Center
        text({font: "drag to the red block and release"})

    Button[(Fader, string)].new "btn":
      block fading:
        self.bkgFade.addTarget(this)
        this.state[0] = self.bkgFade
        connect(self.bkgFade, fadeTick, this, fading)
      # echo "button:id: ", this.getId, " ", self.bkgFade.amount
      box 200'ux, 30'ux, 100'ux, 100'ux
      fill css"#9F2B00".spin(50*self.bkgFade.amount)
      ## TODO: how to make a better api for this
      ## we don't want evDrag, only evDragEnd
      ## uithiss.connect only has doDrag signal
      connect(this, doDrag, this, btnDragStop)
      this.listens.signals.incl {evDragEnd}
      let btn = this
      proc clicked(btn: Button[(Fader, string)],
                    kind: EventKind,
                    buttons: UiButtonView) {.slot.} =
        echo "clicked: ", btn.name, " kind: ", kind
        btn.state[1] = ""
        btn.state[0].fadeOut()
        refresh(btn)
      uinodes.connect(this, doMouseClick, this, clicked)
      Text.new "btnText":
        with this:
          foreground blackColor * self.bkgFade.amount / self.bkgFade.minMax.b
          justify Center
          align Middle
          text({font: btn.state[1]})

var main = Main.new()
var frame = newAppFrame(main, size=(350'ui, 180'ui))
startFiguro(frame)
