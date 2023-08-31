
import commons

type
  FiguroWidget*[T] = ref object of Figuro
    state: T

  Button* = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool

proc hover*(self: Button, kind: EventKind) {.slot.} =
  # self.fill = parseHtmlColor "#9BDFFA"
  # echo "button hover!"
  # echo "child hovered: ", kind
  discard

proc draw*(self: Button) {.slot.} =
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

# connect(current, onHover, current, Button[T].hover)
# connect(current, onDraw, current, Button[T].doPost)

template button*(id: string, blk: untyped) =
  preNode(nkRectangle, Button, id)
  template widget(): Button = Button(current)
  current.postDraw = proc () =
    closureScope:
      `blk`
  # emit current.onDraw()
  postNode()

template button*(id: string, blk: untyped) =
  button(id, void, blk)
