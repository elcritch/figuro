import ../widget

type
  ButtonClicks* = enum
    Single
    Double
    Triple

  Button*[T] = ref object of StatefulFiguro[T]
    label*: string
    disabled*: bool
    clickMode*: set[ButtonClicks] = {Single}

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  # echo "button:hovered: ", kind, " :: ", self.getId
  discard

proc doButton*[T](self: Button[T]) {.signal.}

# proc dragged*[T](node: Button[T],
#                    kind: EventKind,
#                    initial: Position,
#                    cursor: Position
#                   ) {.slot.} =
#   echo "dragged: ", node.name
proc clickPressed*[T](self: Button[T], pressed: UiButtonView, down: UiButtonView) {.slot.} =
  echo "click pressed: ", self.name, " => ", pressed, " down: ", down

proc clicked*[T](self: Button[T], kind: EventKind, buttons: UiButtonView) {.slot.} =
  echo "clicked: ", buttons, " kind: ", kind, " :: ", self.getId, " clickOn: ", self.clickMode
  if kind == Exit:
    return
  elif self.clickMode == {Single} and MouseLeft in buttons:
    discard
  elif self.clickMode == {Double} and buttons == {MouseLeft, DoubleClick}:
    discard
  else:
    return

  refresh(self)
  emit self.doButton()

# proc handleDown*[T](self: Button[T], kind: EventKind, buttons: UiButtonView) {.slot.} =

proc tick*[T](self: Button[T], now: MonoTime, delta: Duration) {.slot.} =
  discard

proc initialize*[T](self: Button[T]) {.slot.} =
  connect(self, doClickPressed, self, clickPressed)

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  withWidget(self):

    with self:
      clipContent true
    withOptional self:
      cornerRadius 10.0'ui

    if self.disabled:
      withOptional self:
        fill css"#F0F0F0"
    else:
      withOptional self:
        fill css"#2B9FEA"
      self.onHover:
        # withOptional self:
        fill self, self.fill.lighten(0.14)
        # this changes the color on hover!
    
    rectangle "buttonInner":
      WidgetContents()

# exportWidget(button, Button)
