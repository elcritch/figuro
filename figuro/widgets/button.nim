
import commons

type
  Button*[T] = ref object of Figuro
    val: T
    label: string
    isActive: bool
    disabled: bool

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  # self.fill = parseHtmlColor "#9BDFFA"
  # echo "button hover!"
  # echo "child hovered: ", kind
  discard

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  current = self
  
  clipContent true
  cornerRadius 10.0

  if self.disabled:
    fill "#F0F0F0"
  else:
    fill "#2B9FEA"
    onHover:
      fill current.fill.spin(15)
      # this changes the color on hover!

template button*(id: string, blk: untyped) =
  preNode(nkRectangle, Button[T], id)
  connect(current, onHover, current, Button.hover)
  proc doPost(self: Button[T]) {.slot.} =
    `blk`
  connect(current, onDraw, current, Button.doPost)
  postNode()

template button*[T](id: string, val: T, blk: untyped) =
  preNode(nkRectangle, Button[T], id)
  connect(current, onHover, current, Button[T].hover)
  proc doPost(self: Button[T]) {.slot.} =
    `blk`
  connect(current, onDraw, current, Button[T].doPost)
  postNode()
