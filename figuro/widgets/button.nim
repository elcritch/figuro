
import commons

type
  StatefulWidget*[T] = ref object of Figuro
    state*: T

  Button*[T] = ref object of StatefulWidget[T]
    label*: string
    isActive*: bool
    disabled*: bool

proc hovered*[T](self: Button[T], kind: EventKind) {.slot.} =
  # self.fill = parseHtmlColor "#9BDFFA"
  # echo "button hover!"
  # echo "button:hovered: ", kind, " :: ", self.getId
  refresh(self)
  discard

proc clicked*[T](self: Button[T],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo nd(), "button:clicked: ", buttons, " kind: ", kind, " :: ", self.getId
  if not self.isActive:
    refresh(self)
  self.isActive = true

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  # current = self
  # echo "button:draw"
  var current = self
  
  clipContent true
  cornerRadius 10.0

  if self.disabled:
    fill "#F0F0F0"
  else:
    fill "#2B9FEA"
    onHover:
      fill current.fill.spin(15)
      # this changes the color on hover!

template button*[T; V](typ: typedesc[T], name: string, value: V, blk: untyped) =
  block:
    var parent: Figuro = Figuro(current)
    var current {.inject.}: Button[T] = nil
    preNode(nkRectangle, name, current, parent)
    captureArgs value:
      current.postDraw = proc (widget: Figuro) =
        echo nd(), "button:postDraw: ", " name: ", (widget).getName()
        echo nd(), "button:postDraw: ", widget.getId, " widget is button: ", widget is Button[T]
        var current {.inject.}: Button[T] = Button[T](widget)
        # echo "BUTTON: ", current.getId, " parent: ", current.parent.getId
        # let widget {.inject.} = Button[T](current)
        if postDraw in widget.attrs:
          return
        `blk`
        widget.attrs.incl postDraw
    # connect(current, onDraw, current, Button[T].draw())
    # connect(current, onDraw, current, postDraw)
    connect(current, onClick, current, Button[T].clicked)
    # connect(current, onHover, current, Button[T].hovered)
    postNode(Figuro(current))

# template button*[V](id: string, value: V, blk: untyped) =
# # template button*(id: string, blk: untyped) =
#   button[void, V](void, id, value, blk)
