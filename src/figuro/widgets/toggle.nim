import ../widget
import ../ui/animations

type
  Toggle*[T] = ref object of StatefulFiguro[T]
    isEnabled: bool
    fade* = Fader(minMax: 0.0..50.0,
                     inTimeMs: 60, outTimeMs: 60)

proc hover*[T](self: Toggle[T], kind: EventKind) {.slot.} =
  # echo "button:hovered: ", kind, " :: ", self.getId
  discard

proc doClicked*[T](self: Toggle[T]) {.signal.}

proc enabled*[T](self: Toggle[T], value: bool) {.slot.} =
  self.isEnabled = value
  if value:
    self.setActive()
    self.fade.fadeIn()
  else:
    self.setInactive()
    self.fade.fadeOut()

template enabled*(value: untyped) =
  this.enabled(value)

proc clicked*[T](self: Toggle[T], kind: EventKind, buttons: UiButtonView) {.slot.} =
  case kind:
  of Done:
    self.enabled(not self.isEnabled)
    emit self.doClicked()
  else:
    discard

proc initialize*[T](self: Toggle[T]) {.slot.} =
  ## initialize the widget
  self.fade.addTarget(self)

proc draw*[T](self: Toggle[T]) {.slot.} =
  ## button widget!
  withWidget(self):
    
    withOptional self:
      fill css"#2B9FEA".lighten(self.fade.amount/200.0)

    WidgetContents()

    Rectangle.new "thumb-bg":
      size 50'pp, 100'pp
      offset csPerc(self.fade.amount), 0'ux

      Rectangle.new "thumb":
        size 100'pp, 100'pp
        withOptional self:
          fill css"grey"
