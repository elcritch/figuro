
import commons
import ../ui/utils

type
  ButtonClicks* = enum
    Single
    Double
    Triple

  Button*[T] = ref object of StatefulFiguro[T]
    label*: string
    disabled*: bool
    clickOn*: set[ButtonClicks] = {Single}

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  echo "button:hovered: ", kind, " :: ", self.getId

proc doButton*[T](self: Button[T]) {.signal.}

proc clicked*[T](self: Button[T],
                 kind: EventKind,
                 buttons: UiButtonView) {.slot.} =
  echo nd(), "button:clicked: ", buttons, " kind: ", kind, " :: ", self.getId, " clickOn: ", self.clickOn

  if self.clickOn == {Single} and buttons == {MouseLeft}:
    discard
    echo "1"
  elif self.clickOn == {Double} and buttons == {MouseLeft, DoubleClick}:
    discard
    echo "2"
  else:
    echo "3"
    return

  refresh(self)
  emit self.doButton()

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  withDraw(self):
    clipContent true
    cornerRadius 10.0

    if self.disabled:
      fill "#F0F0F0"
    else:
      fill "#2B9FEA"
      onHover:
        fill current.fill.spin(15)
        # this changes the color on hover!

exportWidget(button, Button)
