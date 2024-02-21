
import commons
import ../ui/utils

type
  Button*[T] = ref object of StatefulFiguro[T]
    label*: string
    isActive*: bool
    disabled*: bool

# proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
#   echo "button:hovered: ", kind, " :: ", self.getId,
#           " buttons: ", self.events.mouse

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
  var node = self
  with node:
    clipContent true
    cornerRadius 10.0

  if self.disabled:
    fill node, css"#F0F0F0"
  else:
    fill node, css"#2B9FEA"
    onHover:
      fill node, node.fill.spin(15)
  rectangle "btnBody":
    bubble(doClick)
    boxSizeOf node, node.parent.obj
    TemplateContents(self)

exportWidget(button, Button)
