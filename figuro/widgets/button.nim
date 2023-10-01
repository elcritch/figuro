
import commons
import ../ui/utils

type
  ButtonClicks* = enum
    Single
    Double
    Triple

  Button*[T] = ref object of StatefulFiguro[T]
    label*: string
    isActive*: bool
    disabled*: bool
    clicks*: set[ButtonClicks]

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  echo "button:hovered: ", kind, " :: ", self.getId

proc clicked*[T](self: Button[T],
                 kind: EventKind,
                 buttons: UiButtonView) {.slot.} =
  echo nd(), "button:clicked: ", buttons, " kind: ", kind, " :: ", self.getId, " clickOn: ", self.clicks

  static:
    echo "CLICKED!"

  if self.clicks == {Single} and buttons == {MouseLeft}:
    discard
    echo "1"
  elif self.clicks == {Double} and buttons == {MouseLeft, DoubleClick}:
    discard
    echo "2"
  else:
    echo "3"
    return

  if not self.isActive:
    refresh(self)
  self.isActive = true

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
