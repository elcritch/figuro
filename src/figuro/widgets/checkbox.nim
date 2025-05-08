import pkg/chronicles
import ../widget
import ../ui/animations

type
  Checkbox* = ref object of Figuro
    fade* = Fader(minMax: 0.0..1.0,
                  inTimeMs: 240, outTimeMs: 240)

  TextCheckbox* = ref object of Figuro
    isEnabled: bool
    labelText: seq[(UiFont, string)]

proc doClicked*(self: Checkbox) {.signal.}
proc doChange*(self: Checkbox, value: bool) {.signal.}

proc checked*(self: Checkbox, value: bool) {.slot.} =
  if contains(self, Checked) != value:
    self.setUserAttr(Checked, value)
    if value:
      self.fade.fadeIn()
    else:
      self.fade.fadeOut()
    emit self.doChange(value)

proc clicked*(self: Checkbox, kind: EventKind, buttons: set[UiMouse]) {.slot.} =
  if MouseLeft notin buttons:
    return
  case kind:
  of Done:
    self.checked(not contains(self, Checked))
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
    fill themeColor("fig-widget-background-light")
    border 1'ui, css"grey"

    Text.new "checkmark":
      size 100'pp, 100'pp
      let sz = min(this.parent[].box.h, this.parent[].box.w)
      let font = defaultFont().withSize(sz)
      text {font: "✓"}
      foreground blackColor * self.fade.amount
      justify Center
      align Middle

    WidgetContents()
    
proc label*(self: TextCheckbox, spans: openArray[(UiFont, string)]) {.slot.} =
  self.labelText.setLen(0)
  self.labelText.add spans

proc checked*(self: TextCheckbox, value: bool) {.slot.} =
  if contains(self, Checked) != value:
    self.setUserAttr(Checked, value)
    refresh(self)

proc draw*(self: TextCheckbox) {.slot.} =
  withWidget(self):

    Checkbox.new "checkbox":
      size 30'ux, 100'pp
      checked(this, contains(self, Checked))
      connect(this, doChange, self, TextCheckbox.checked())

    Rectangle.new "text-bg":
      let check = this.querySibling("checkbox").get()
      size 30'ux, 100'pp
      offset ux(check.box.w+0'ui), 0'ux

      Text.new "text":
        justify Center
        align Middle
        zlevel 1
        size 100'pp, 100'pp
        text self.labelText
