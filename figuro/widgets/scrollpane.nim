
import commons
import ../ui/utils

type
  ScrollPane* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    scrollby: Position
    mainRect: Figuro

import pretty

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  # self.scrollby.x -= wheelDelta.x * 10.0
  let yoffset = wheelDelta.y * 10.0
  let current = self.children[0]
  assert current.name == "scrollBody"

  let
    viewHeight = self.screenBox.h
    contentOverflow = (current.screenBox.h - viewHeight).clamp(0'ui, current.screenBox.h)
  echo "SCROLL: ph: ", viewHeight, " ch: ", contentOverflow
  self.scrollby.y -= yoffset
  self.scrollby.y = self.scrollby.y.clamp(0'ui, contentOverflow)

  refresh(self)

proc draw*(self: ScrollPane) {.slot.} =
  withDraw self:
    current.listens.events.incl evScroll
    connect(current, doScroll, self, ScrollPane.scroll)
    rectangle "scrollBody":
      size 100'pp, cx"max-content"
      # cornerRadius 10.0
      fill whiteColor.darken(0.2)
      clipContent true
      current.offset = self.scrollby
      current.attrs.incl scrollPanel
      TemplateContents(self)

      # echo "SCROLL BODY: ", node.box, " => ", node.children[0].box
      # boxSizeOf node.children[0]

proc getWidgetParent*(self: ScrollPane): Figuro =
  # self.children[0] # "scrollBody"
  self

exportWidget(scroll, ScrollPane)
