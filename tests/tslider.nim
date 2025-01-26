import figuro/widgets/[horizontal, vertical, button]
import figuro/ui/animations
import figuro

import sugar

type
  Main* = ref object of Figuro
    bkgFade* = Fader(minMax: 0.0..1.0,
                     inTimeMs: 200, outTimeMs: 200)

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
  let node = self
  rectangle "body":
    with node:
      fill blackColor.lighten(0.7)
      zlevel 20.ZLevel
      box ux(140*self.bkgFade.amount - 140), 0'ux, 140'ux, 100'pp
      cornerRadius 0.0
    Vertical.new "menu":
      box node, 0'ux, 10'ux, 100'pp, 95'pp
      itemHeight node, cx"min-content", gap = 20'ui
      Button.new "close":
        size node, 120'ux, 60'ux
        connect(node, doClicked, self, deactivateSlider)
        text "text":
          fill node, blackColor
          setText(node, {defaultFont: "Close Menu"}, Center, Middle)
  Horizontal.new "horiz":
    offset node, 30'pp, 0'ux
    itemWidth node, cx"min-content", gap = 20'ui
    Button.new "pen":
      size node, 120'ux, 60'ux
      connect(node, doClicked, self, activateSlider)
      text "text":
        fill node, blackColor
        setText(node, {defaultFont: "Open Menu"}, Center, Middle)

    Button.new "close":
      size node, 120'ux, 60'ux
      connect(node, doClicked, self, deactivateSlider)
      text "text":
        fill node, blackColor
        setText(node, {defaultFont: "Close Menu"}, Center, Middle)

var main = Main.new()
var frame = newAppFrame(main, size=(500'ui, 300'ui))
startFiguro(frame)
