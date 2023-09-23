
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
  self.scrollby.y -= wheelDelta.y * 10.0
  self.scrollby.y = self.scrollby.y.clamp(0.0, self.box.y)
  refresh(self)

proc draw*(self: ScrollPane) {.slot.} =
  withDraw(self):
    box 20, 10, 80'vw, 300
    current.listens.events.incl evScroll
    connect(current, doScroll, self, ScrollPane.scroll)
    rectangle "body":
      boxOf current.parent
      cornerRadius 10.0
      fill whiteColor.darken(0.1)
      clipContent true
      current.offset = self.scrollby
      current.attrs.incl scrollPanel

proc getWidgetParent*(self: ScrollPane): Figuro =
  echo "SCROLL BODY"
  self.children[0] # "body"

exportWidget(scroll, ScrollPane)