
import commons

type
  Widget*[T] = ref object of Figuro
    state: T

  Button*[T] = ref object of Widget[T]
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

template button*[T](id: string, value: T, blk: untyped) =
  preNode(nkRectangle, Button[T], id)
  template widget(): Button[T] = Button[T](current)
  widget.state = value
  connect(current, onHover, current, Button[T].hover)
  proc doPost(inst: Button[T]) {.slot.} =
    `blk`
  connect(current, onDraw, current, Button[T].doPost)
  emit current.onDraw()
  postNode()

template button*(id: string, blk: untyped) =
  button(id, void, blk)
