
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
    clickMode*: set[ButtonClicks] = {Single}

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  # echo "button:hovered: ", kind, " :: ", self.getId
  discard

proc doButton*[T](self: Button[T]) {.signal.}

proc clicked*[T](self: Button[T],
                 kind: EventKind,
                 buttons: UiButtonView) {.slot.} =
  # echo nd(), "button:clicked: ", buttons, " kind: ", kind, " :: ", self.getId, " clickOn: ", self.clickMode
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

proc tick*[T](self: Button[T], tick: int, now: MonoTime) {.slot.} =
  discard

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  nodes(self):
    clipContent true
    cornerRadius 10.0

    if self.disabled:
      optionally:
        fill css"#F0F0F0"
    else:
      optionally:
        fill css"#2B9FEA"
      onHover:
        optionally:
          fillHover current.fill.lighten(0.14)
          # this changes the color on hover!

exportWidget(button, Button)
