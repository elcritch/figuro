
import commons
import ../ui/utils

type
  ScrollPane* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    scrollby: Position
    width*: UICoord = 20.0'ui
    barLeft: bool
    bar*: ScrollBar
  
  ScrollBar* = object
    viewHeight: UICoord
    contentHeight: UICoord
    contentOverflow: UICoord
    contentViewRatio: UICoord
    size: UICoord
    sizePercent: UICoord
    start: Position

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  # self.scrollby.x -= wheelDelta.x * 10.0
  let yoffset = wheelDelta.y * 10.0
  let current = self.children[0]
  assert current.name == "scrollBody"
  let
    viewHeight = self.screenBox.h
    contentHeight = current.screenBox.h
    contentViewRatio = (viewHeight/contentHeight).clamp(0.0'ui, 1.0'ui)
    contentOverflow = (contentHeight - viewHeight).clamp(0'ui, current.screenBox.h)

  echo "SCROLL: ph: ", viewHeight, " ch: ", contentOverflow, " ratio: ", contentViewRatio
  self.scrollby.y -= yoffset
  self.scrollby.y = self.scrollby.y.clamp(0'ui, contentOverflow)

  let
    scrollBarSize = contentViewRatio * viewHeight
    sizePercent = clamp(self.scrollby.y/contentOverflow, 0'ui, 1'ui)
    barX = if self.barLeft: 0'ui
                   else: self.screenBox.w - self.width
    barY = sizePercent*(viewHeight - scrollBarSize)
    barStart = initPosition(barX.float, barY.float)

  self.bar = ScrollBar(
    viewHeight: viewHeight,
    contentHeight: contentHeight,
    contentViewRatio: contentViewRatio,
    contentOverflow: contentOverflow,
    size: scrollBarSize,
    sizePercent: sizePercent,
    start: barStart,
  )

  refresh(self)

proc draw*(self: ScrollPane) {.slot.} =
  withDraw self:
    current.listens.events.incl evScroll
    connect(current, doScroll, self, ScrollPane.scroll)
    rectangle "scrollBody":
      ## max-content is important here
      ## todo: do the same for horiz?
      size 100'pp, cx"max-content"
      fill whiteColor.darken(0.2)
      clipContent true
      current.offset = self.scrollby
      current.attrs.incl scrollPanel
      TemplateContents(self)

      # echo "SCROLL BODY: ", node.box, " => ", node.children[0].box
      # boxSizeOf node.children[0]
    rectangle "scrollBody":
      box self.bar.start.x, self.bar.start.y, self.width, self.bar.size
      fill blackColor

proc getWidgetParent*(self: ScrollPane): Figuro =
  # self.children[0] # "scrollBody"
  self

exportWidget(scroll, ScrollPane)
