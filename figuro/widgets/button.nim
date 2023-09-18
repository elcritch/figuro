
import commons
import ../ui/utils

type
  Button*[T] = ref object of StatefulFiguro[T]
    label*: string
    isActive*: bool
    disabled*: bool

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  echo "button:hovered: ", kind, " :: ", self.getId,
          " buttons: ", self.events.mouse
  

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
