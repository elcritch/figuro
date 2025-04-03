import figuro/widgets/[horizontal, vertical, button]
import figuro/ui/animations
import figuro

import sugar

type
  Main* = ref object of Figuro
    bkgFade* = Fader(minMax: 0.0..1.0,
                     inTimeMs: 260, outTimeMs: 200)

proc initialize*(self: Main) {.slot.} =
  self.setTitle("Click Test!")
  self.bkgFade.addTarget(self)

proc activateSlider*(self: Main) {.slot.} =
  ## activate fading on hover, deactive when not hovering
  self.bkgFade.fadeIn()
proc deactivateSlider*(self: Main) {.slot.} =
  ## activate fading on hover, deactive when not hovering
  self.bkgFade.fadeOut()

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    rectangle "body":
      fill rgba(66, 177, 44, 197).to(Color).spin(100).darken(0.3*self.bkgFade.amount)
      zlevel 20.ZLevel
      box ux(140*self.bkgFade.amount - 140), 0'ux, 140'ux, 100'pp
      cornerRadius 0.0'ui
      Vertical.new "menu":
        box 0'ux, 10'ux, 100'pp, 95'pp
        contentHeight this, cx"max-content", gap = 20'ui
        Button.new "Close":
          size 120'ux, 40'ux
          connect(doClicked, self, deactivateSlider)
          Text.new "text":
            size 100'pp, 100'pp
            foreground blackColor
            justify Center
            align Middle
            text({defaultFont(): "Close Menu"})
    Horizontal.new "horiz":
      offset 30'pp, 0'ux
      contentWidth this, cx"max-content", gap = 20'ui

      Button.new "Open":
        size 120'ux, 60'ux
        connect(this, doClicked, self, activateSlider)
        Text.new "text":
          size 100'pp, 100'pp
          foreground blackColor
          justify Center
          align Middle
          text({defaultFont(): "Open Menu"})

      Button.new "Close":
        size this, 120'ux, 60'ux
        connect(this, doClicked, self, deactivateSlider)
        Text.new "text":
          size 100'pp, 100'pp
          foreground blackColor
          justify Center
          align Middle
          text({defaultFont(): "Close Menu"})

var main = Main.new()
var frame = newAppFrame(main, size=(800'ui, 600'ui))
startFiguro(frame)
