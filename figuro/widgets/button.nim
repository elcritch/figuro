
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
  self.attrs.excl postDraw
  
  clipContent true
  cornerRadius 10.0

  if self.disabled:
    fill "#F0F0F0"
  else:
    fill "#2B9FEA"
    onHover:
      fill current.fill.spin(15)
      # this changes the color on hover!

from sugar import capture
import macros

macro captureArgs(args, blk: untyped): untyped =
  result = nnkCommand.newTree(bindSym"capture")
  if args.kind in [nnkSym, nnkIdent]:
    result.add args
  else:
    for arg in args:
      result.add args
  # result.add ident"parent"
  # result.add ident"current"
  result.add blk

template button*[T; V](typ: typedesc[T], name: string, value: V, blk: untyped) =
  block:
    # var parent {.inject.}: Figuro = current
    # var current {.inject.}: Button[T]
    preNode(nkRectangle, Button[T], name)
    captureArgs value:
      current.postDraw = proc () =
        let widget {.inject.} = Button[T](current)
        if postDraw in current.attrs:
          return
        `blk`
        # current.attrs.incl postDraw
    # connect(current, onDraw, current, Button[T].draw())
    connect(current, onDraw, current, postDraw)
    connect(current, onClick, current, Button[T].clicked)
    # connect(current, onHover, current, Button[T].hovered)
    postNode()

template button*[V](id: string, value: V, blk: untyped) =
# template button*(id: string, blk: untyped) =
  button[void, V](void, id, value, blk)
