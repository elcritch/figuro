import pkg/chronicles
import ../widget
import ../ui/animations

type
  Toggle* = ref object of Figuro
    isEnabled: bool
    fade* = Fader(minMax: 0.0..50.0,
                     inTimeMs: 60, outTimeMs: 60)

  TextToggle* = ref object of Figuro
    isEnabled: bool
    labelText: seq[(UiFont, string)]

proc doClicked*(self: Toggle) {.signal.}
proc doChange*(self: Toggle, value: bool) {.signal.}

proc enabled*(self: Toggle, value: bool) {.slot.} =
  self.isEnabled = value
  if value:
    self.setActive()
    self.fade.fadeIn()
  else:
    self.setInactive()
    self.fade.fadeOut()
  emit self.doChange(self.isEnabled)

template enabled*(value: untyped) =
  this.enabled(value)

proc isEnabled*(self: Toggle): bool =
  self.isEnabled

proc clicked*(self: Toggle, kind: EventKind, buttons: UiButtonView) {.slot.} =
  case kind:
  of Done:
    self.enabled(not self.isEnabled)
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

proc isEnabled*(self: TextToggle): bool =
  self.isEnabled

proc enabled*(self: TextToggle, value: bool) {.slot.} =
  if self.isEnabled != value:
    self.isEnabled = value
    refresh(self)

proc draw*(self: TextToggle) {.slot.} =
  withWidget(self):
    Toggle.new "toggle":
      size 30'ux, 100'pp
      enabled self.isEnabled
      connect(this, doChange, self, TextToggle.enabled())

    Rectangle.new "text-bg":
      size 100'pp-30'ux, 100'pp
      offset 30'ux, 0'ux

      Text.new "text":
        justify Center
        align Middle
        zlevel 1
        size 100'pp, 100'pp
        text self.labelText

