import pkg/chronicles
import ../widget
import ../ui/animations

type
  Toggle* = ref object of StatefulFiguro[bool]
    fade* = Fader(minMax: 0.0..50.0,
                     inTimeMs: 60, outTimeMs: 60)

  TextToggle* = ref object of Toggle
    labelText: seq[(UiFont, string)]

proc hover*(self: Toggle, kind: EventKind) {.slot.} =
  # echo "button:hovered: ", kind, " :: ", self.getId
  discard

proc doClicked*(self: Toggle) {.signal.}

proc enabled*(self: Toggle, value: bool) {.slot.} =
  self.state = value
  if value:
    self.setActive()
    self.fade.fadeIn()
  else:
    self.setInactive()
    self.fade.fadeOut()

template enabled*(value: untyped) =
  this.enabled(value)

proc clicked*(self: Toggle, kind: EventKind, buttons: UiButtonView) {.slot.} =
  case kind:
  of Done:
    self.enabled(not self.state)
    emit self.doClicked()
  else:
    discard

proc initialize*(self: Toggle) {.slot.} =
  ## initialize the widget
  self.fade.addTarget(self)

proc draw*(self: Toggle) {.slot.} =
  ## button widget!
  withWidget(self):
    
    withOptional self:
      fill css"#2B9FEA".lighten(self.fade.amount/200.0)

    Rectangle.new "thumb-bg":
      size 50'pp, 100'pp
      offset csPerc(self.fade.amount), 0'ux

      Rectangle.new "thumb":
        size 100'pp, 100'pp
        withOptional self:
          fill css"grey"

    WidgetContents()

proc label*(self: TextToggle, spans: openArray[(UiFont, string)]) {.slot.} =
  self.labelText.setLen(0)
  self.labelText.add spans

template label*(spans: openArray[(UiFont, string)]) =
  this.label(spans)

proc draw*(self: TextToggle) {.slot.} =
  withWidget(self):
    draw(Toggle(self))
    Text.new "toggle-text":
      justify Center
      align Middle
      zlevel 1
      size 40'ux, 10'ux
      offset 50'pp-20'ux, 50'pp-8'ux
      text self.labelText