import pkg/chronicles
import ../widget
import ../ui/animations

type
  Toggle* = ref object of Figuro
    fade* = Fader(minMax: 0.0..50.0,
                     inTimeMs: 120, outTimeMs: 120)

  TextToggle* = ref object of Figuro
    labelText: seq[(UiFont, string)]

proc doClicked*(self: Toggle) {.signal.}
proc doChange*(self: Toggle, value: bool) {.signal.}

proc checked*(self: Toggle, value: bool) {.slot.} =
  if contains(self, Checked) != value: 
    self.setUserAttr({Checked}, value)
    if value: self.fade.fadeIn() else: self.fade.fadeOut()
    emit self.doChange(value)
    refresh(self)

proc clicked*(self: Toggle, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft in buttons and Done == kind:
    self.checked(not contains(self, Checked))
    emit self.doClicked()

proc initialize*(self: Toggle) {.slot.} =
  ## initialize the widget
  self.fade.addTarget(self)

proc draw*(self: Toggle) {.slot.} =
  ## button widget!
  withWidget(self):
    withOptional self:
      fill themeColor("fig-accent-color").lighten(self.fade.amount/200.0)

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

proc checked*(self: TextToggle, value: bool) {.slot.} =
  if contains(self, Checked) != value:
    self.setUserAttr({Checked}, value)
    refresh(self)

proc draw*(self: TextToggle) {.slot.} =
  withWidget(self):
    Toggle.new "toggle-inner":
      size 30'ux, 100'pp
      checked(this, contains(self, Checked))
      connect(this, doChange, self, TextToggle.checked())

    Rectangle.new "text-bg":
      let toggle = this.querySibling("toggle-inner").get()
      size 100'pp-30'ux, 100'pp
      offset ux(toggle.box.w+0'ui), 0'ux

      Text.new "text":
        justify Center
        align Middle
        zlevel 1
        size 100'pp, 100'pp
        text self.labelText

    WidgetContents()

