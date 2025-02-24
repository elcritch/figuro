#[
    Shutdown app test using the Figuro library
]#

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
    input_enabled: bool

let
  defaultFont = UiFont(typefaceId: defaultTypeface, size: 50'ui)
  buttonFont = UiFont(typefaceId: defaultTypeface, size: 30'ui)

proc update*(fig: Main) {.signal.}

proc fading*(self: Main, value: tuple[amount, perc: float], finished: bool) {.slot.} =
  refresh(self)

proc btnClicked*(self: Main, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if kind == Done:
    if buttons in [{MouseLeft}, {DoubleClick}, {TripleClick}]:
      self.input_enabled = not self.input_enabled
      refresh(self)

proc btnHover*(self: Main, evtKind: EventKind) {.slot.} =
  ## activate fading on hover, deactive when not hovering
  self.bkgFade.startFade(evtKind == Init)
  self.refresh()

proc initialize*(self: Main) {.slot.} =
  self.setTitle(title)
  self.bkgFade.addTarget(self)
  self.input_enabled = true
  connect(self.bkgFade, fadeTick, self, Main.fading())

proc draw*(self: Main) {.slot.} =
  
  withRootWidget(self):
    fill this, css"#f0f0f0"
    box this, 0'ux, 0'ux, window_size.width, window_size.height

    # Time display background
    rectangle("time-background"):
      with this:
        box 1'pp, 1'pp, 98'pp, 98'pp
        fill css"#ffffff"
        fill blackColor * (self.bkgFade.amount)
        border 1'ui, css"#000000"

      Vertical.new("vlayout"):
        with this:
          size 100'pp, 100'pp
          contentHeight cx"auto", gap = 0'ui
        
        if self.input_enabled:
          # Test text input
          Input.new("time-input"):
            with this:
              size 90'pp, 30'pp
              align Middle
              justify Center
              font defaultFont
              foreground css"black"
              fill css"white"
              border 1'ui, css"black"
              cornerRadius 0.0'ui
            if not this.textChanged(""):
              # set default
              text(this, "00:00:00")
        else:
          # Time display text
          Text.new("time-display"):
            with this:
              size 90'pp, 30'pp
              fill css"white"
              foreground css"red"
              border 1'ui, css"#000000"
              cornerRadius 0.0'ui
              justify FontHorizontal.Center
              align FontVertical.Middle
              font defaultFont
            if this.textChanged(""):
              # set default
              this.text("00:00:00")

        Button[bool].new("countdown-button"):
          with this:
            size 40'pp, 30'pp
            border 1'ui, css"#000000"
            cornerRadius 4.0'ui
            connect(doHover, self, btnHover)
            connect(doMouseClick, self, btnClicked)
          Text.new "text":
            with this:
              foreground blackColor
              justify Center
            align Middle
            text({buttonFont: "COUNTDOWN"})

var main = Main.new()
var frame = newAppFrame(main, size = window_size, style = DecoratedFixedSized)
startFiguro(frame)