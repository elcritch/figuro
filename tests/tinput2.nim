#[
    Shutdown app test using the Figuro library
]#

import std/times
import figuro/widgets/button
import figuro/widgets/input
import figuro/widgets/vertical
import figuro/ui/animations
import figuro

const
  title = "Nim Shutdown App (Figuro edition)"
  window_size = (width: 480'ui, height: 180'ui)
  offset = (left: 4'ux, top: 4'ux)

type 
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    bkgFade = Fader(minMax: 0.0 .. 0.18, inTimeMs: 600, outTimeMs: 500)
    running: bool
    count: Duration

let
  defaultFont = UiFont(typefaceId: defaultTypeface(), size: 50'ui, lineHeightScale: 0.7692)
  buttonFont = UiFont(typefaceId: defaultTypeface(), size: 30'ui)

proc update*(fig: Main) {.signal.}

proc fading*(self: Main, value: tuple[amount, perc: float], finished: bool) {.slot.} =
  refresh(self)

proc parseCount*(text: string): Duration =
  echo "parse count: ", text

proc btnHover*(self: Main, evtKind: EventKind) {.slot.} =
  ## activate fading on hover, deactive when not hovering
  self.bkgFade.startFade(evtKind == Init)
  self.refresh()

proc initialize*(self: Main) {.slot.} =
  self.setTitle(title)
  self.bkgFade.addTarget(self)
  self.running = false
  connect(self.bkgFade, doFadeTick, self, Main.fading())

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    size 100'pp, 100'pp
    fill this, css"#f0f0f0"

    # Time display background
    Rectangle.new "time-background":
      box 1'pp, 1'pp, 98'pp, 98'pp
      fill css"#ffffff"
      fill blackColor * (self.bkgFade.amount)
      border 1'ui, css"#000000"

      Vertical.new "vlayout":
        size 100'pp, 100'pp
        contentHeight cx"auto", gap = 0'ui
        
        Rectangle.new "input-outer":
          # Test text input
          border 1'ui, css"black"
          size 90'pp, 30'pp
          Input.new("time-input"):
            size 100'pp, 100'pp
            align Middle
            justify Center
            font defaultFont()
            foreground css"black"
            fill css"white"
            border 1'ui, css"black"
            disabled self.running
            options({OverwriteMode, NoErase, NoSelection})
            skipOnInput ':'
            if this.disabled:
              fill this.fill.darken(0.4)
              foreground css"grey"
            proc overrideUpdateInput(this: Input, rune: Rune) {.slot.} =
              let isDigit = rune <=% Rune('9') and rune.char in {'0'..'9'}
              template currCharColon(): bool = this.text.runeAtCursor() == Rune(':')
              if isDigit:
                this.updateInput(rune)
                this.text.cursorNext()

            connect(this, doUpdateInput, this, overrideUpdateInput)
            if not this.textChanged(""):
              # set default
              this.setText("00:00:00")

        Button[bool].new("countdown-button"):
          proc btnClicked(self: Main, kind: EventKind, buttons: set[UiMouse]) {.slot.} =
            if kind == Done:
              if buttons in [{MouseLeft}, {DoubleClick}, {TripleClick}]:
                self.running = not self.running
                # self.count = this.text().parseCount()
                refresh(self)
          size 50'pp, 30'pp
          border 1'ui, css"#000000"
          cornerRadius 4.0'ui
          connect(doHover, self, btnHover)
          connect(doMouseClick, self, btnClicked)

          Text.new "text":
            size 100'pp, 100'pp
            foreground blackColor
            justify Center
            align Middle
            if not self.running:
              text({buttonFont: "COUNTDOWN"})
            else:
              text({buttonFont: "CANCEL"})

var main = Main.new()
var frame = newAppFrame(main, size = window_size, style = DecoratedFixedSized)
startFiguro(frame)