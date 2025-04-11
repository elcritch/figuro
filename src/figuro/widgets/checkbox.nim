import pkg/chronicles
import ../widget
import ../ui/animations

type
  Checkbox* = ref object of Figuro
    isEnabled: bool
    fade* = Fader(minMax: 0.0..1.0,
                  inTimeMs: 240, outTimeMs: 240)

  TextCheckbox* = ref object of Figuro
    isEnabled: bool
    labelText: seq[(UiFont, string)]

proc doClicked*(self: Checkbox) {.signal.}
proc doChange*(self: Checkbox, value: bool) {.signal.}

proc enabled*(self: Checkbox, value: bool) {.slot.} =
  if self.isEnabled == value: return
  self.isEnabled = value
  if value:
    self.setActive()
    self.fade.fadeIn()
  else:
    self.setInactive()
    self.fade.fadeOut()
  emit self.doChange(self.isEnabled)

proc isEnabled*(self: Checkbox): bool =
  self.isEnabled

proc clicked*(self: Checkbox, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft notin buttons:
    return
  case kind:
  of Done:
    self.enabled(not self.isEnabled)
    emit self.doClicked()
  else:
    discard

proc initialize*(self: Checkbox) {.slot.} =
  ## initialize the widget
  self.fade.addTarget(self)

proc draw*(self: Checkbox) {.slot.} =
  ## checkbox widget!
  withWidget(self):
    cornerRadius 5'ui
    fill css"white"
    border 1'ui, css"grey"

    WidgetContents()
    
    Text.new "checkmark":
      size 100'pp, 100'pp
      let sz = min(this.parent[].box.h, this.parent[].box.w)
      let font = defaultFont().withSize(sz)
      text {font: "✓"}
      foreground blackColor * self.fade.amount
      justify Center
      align Middle

proc label*(self: TextCheckbox, spans: openArray[(UiFont, string)]) {.slot.} =
  self.labelText.setLen(0)
  self.labelText.add spans

proc isEnabled*(self: TextCheckbox): bool =
  self.isEnabled

proc enabled*(self: TextCheckbox, value: bool) {.slot.} =
  echo "text-checkbox:enabled: ", value
  if self.isEnabled != value:
    self.isEnabled = value
    refresh(self)

proc draw*(self: TextCheckbox) {.slot.} =
  withWidget(self):
    Checkbox.new "checkbox":
      size 30'ux, 100'pp
      enabled this, self.isEnabled
      connect(this, doChange, self, TextCheckbox.enabled())

    Rectangle.new "text-bg":
      let check = this.querySibling("checkbox").get()
      size 30'ux, 100'pp
      offset ux(check.box.w+3'ui), 0'ux

      Text.new "text":
        justify Center
        align Middle
        zlevel 1
        size 100'pp, 100'pp
        text self.labelText
