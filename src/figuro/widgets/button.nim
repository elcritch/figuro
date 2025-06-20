import ../widget
import ../ui/animations

type
  ButtonClicks* = enum
    Single
    Double
    Triple

  Button*[T] = ref object of StatefulFiguro[T]
    clickMode*: set[ButtonClicks] = {Single}
    fade* = Fader(minMax: 0.0..1.0,
                     inTimeMs: 60, outTimeMs: 60)

  TextButton*[T] = ref object of Button[T]
    labelText: seq[(UiFont, string)]

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  # echo "button:hovered: ", kind, " :: ", self.getId
  discard

proc doClicked*[T](self: Button[T]) {.signal.}

proc clicked*[T](self: Button[T], kind: EventKind, buttons: set[UiMouse]) {.slot.} =
  # echo "clicked: ", " kind: ", kind, " :: ", buttons, " id: ", self.getId, " clickOn: ", self.clickMode
  case kind:
  of Init:
    self.fade.fadeIn()
    self.setUserAttr(Active, true)
  of Exit:
    self.setUserAttr(Active, false)
    self.fade.fadeOut()
    return
  of Done:
    self.setUserAttr(Active, false)
    # if MouseLeft in buttons:
    #   emit self.doSingleClick()
    # if DoubleClick in buttons:
    #   emit self.doDoubleClick()
    # if MouseRight in buttons:
    #   emit self.doRightClick()
    # if TripleClick in buttons:
    #   emit self.doTripleClick()

    if self.clickMode == {Double} and DoubleClick notin buttons:
      return
    elif self.clickMode == {Single} and MouseLeft notin buttons:
      return

    self.fade.fadeOut()
    emit self.doClicked()

proc initialize*[T](self: Button[T]) {.slot.} =
  ## initialize the widget
  self.fade.addTarget(self)

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  withWidget(self):

    clipContent true
    withOptional self:
      cornerRadius 10.0'ui

    if Disabled in self.userAttrs:
      withOptional self:
        fill css"#F0F0F0"
    else:
      withOptional self:
        fill themeColor("fig-accent-color")

      if self.fade.active or Active in self.userAttrs:
        this.fill = this.fill.lighten(0.14*self.fade.amount)
    
    WidgetContents()

proc label*[T](self: TextButton[T], spans: openArray[(UiFont, string)]) {.slot.} =
  self.labelText.setLen(0)
  self.labelText.add spans

proc draw*[T](self: TextButton[T]) {.slot.} =
  ## button widget!
  withWidget(self):

    if Disabled in self.userAttrs:
      withOptional self:
        fill themeColor("fig-widget-background-color")
    else:
      withOptional self:
        fill themeColor("fig-accent-color")

      if self.fade.active or Active in self.userAttrs:
        this.fill = this.fill.lighten(0.14*self.fade.amount)

    Text.new "text":
      size 100'pp, 100'pp
      justify Center
      align Middle
      text self.labelText

    WidgetContents()
