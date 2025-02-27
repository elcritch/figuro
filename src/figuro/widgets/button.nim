import ../widget
import ../ui/animations

type
  ButtonClicks* = enum
    Single
    Double
    Triple

  Button*[T] = ref object of StatefulFiguro[T]
    label*: string
    disabled*: bool
    clickMode*: set[ButtonClicks] = {Single}
    isPressed*: bool
    fade* = Fader(minMax: 0.0..1.0,
                     inTimeMs: 60, outTimeMs: 60)

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  # echo "button:hovered: ", kind, " :: ", self.getId
  discard

proc doClicked*[T](self: Button[T]) {.signal.}

proc clicked*[T](self: Button[T], kind: EventKind, buttons: UiButtonView) {.slot.} =
  # echo "clicked: ", " kind: ", kind, " :: ", buttons, " id: ", self.getId, " clickOn: ", self.clickMode
  case kind:
  of Init:
    self.fade.fadeIn()
    self.isPressed = true
  of Exit:
    self.isPressed = false
    self.fade.fadeOut()
    return
  of Done:
    self.isPressed = false
    if self.clickMode == {Double} and DoubleClick notin buttons:
      return
    elif self.clickMode == {Single} and MouseLeft notin buttons:
      return

    self.fade.fadeOut()
    emit self.doClicked()

# proc handleDown*[T](self: Button[T], kind: EventKind, buttons: UiButtonView) {.slot.} =

proc tick*[T](self: Button[T], now: MonoTime, delta: Duration) {.slot.} =
  discard

proc initialize*[T](self: Button[T]) {.slot.} =
  ## initialize the widget
  self.fade.addTarget(self)

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  withWidget(self):

    with this:
      clipContent true
    withOptional self:
      cornerRadius 10.0'ui

    if self.disabled:
      withOptional self:
        fill css"#F0F0F0"
    else:
      withOptional self:
        fill css"#2B9FEA"

      if self.fade.active or self.isPressed:
        this.fill = this.fill.lighten(0.14*self.fade.amount)
    
    WidgetContents()
