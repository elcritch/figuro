
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
  

proc clicked*[T](self: Button[T],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo nd(), "button:clicked: ", buttons,
              " kind: ", kind, " :: ", self.getId

  if not self.isActive:
    refresh(self)
  self.isActive = true

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  withDraw(self):
      
    rectangle "btnBody":
      boxOf current.parent
      clipContent true
      cornerRadius 10.0

      if self.disabled:
        fill "#F0F0F0"
      else:
        fill "#2B9FEA"
        onHover:
          fill current.fill.spin(15)
          # this changes the color on hover!

proc getWidgetParent*[T](self: Button[T]): Figuro =
  echo "getWidgetParent:button: ", self.getId, " chil: ", self.children.len()
  if self.children.len() > 0:
    self.children[0] # "btnBody"
  else:
    self

exportWidget(button, Button)
