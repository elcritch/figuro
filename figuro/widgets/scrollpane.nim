
import commons
import ../ui/utils

type
  ScrollPane* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    props*: ScrollProperties
    window*: ScrollWindow
    bar*: ScrollBar

  ScrollProperties* = object
    width*: UICoord = 20.0'ui
    barLeft: bool
  
  ScrollWindow* = object
    scrollby: Position
    viewHeight: UICoord
    contentHeight: UICoord
    contentOverflow: UICoord
    contentViewRatio: UICoord

  ScrollBar* = object
    size: UICoord
    start: Position

proc calculateScroll*(self: ScrollPane,
                      viewBox, childBox: Box,
                      wheelDelta: Position) =
  let
    viewHeight = viewBox.h
    contentHeight = childBox.h
    contentViewRatio = (viewHeight/contentHeight).clamp(0.0'ui, 1.0'ui)
    contentOverflow = (contentHeight - viewHeight).clamp(0'ui, contentHeight)

  echo "SCROLL: pre: ", " delta: ", wheelDelta.y * 10.0,  " scrollBy: ", self.window.scrollby.y, " after: ", self.window.scrollby.y - wheelDelta.y * 10.0
  self.window.scrollby.y -= wheelDelta.y * 10.0
  self.window.scrollby.y = self.window.scrollby.y.clamp(0'ui, contentOverflow)
  echo "SCROLL: ph: ", viewHeight, " ch: ", contentOverflow, " ratio: ", contentViewRatio, " scrollBy: ", self.window.scrollby.y
  echo ""

  let
    scrollBarSize = contentViewRatio * viewHeight
    sizePercent = clamp(self.window.scrollby.y/contentOverflow, 0'ui, 1'ui)
    barX = if self.props.barLeft: 0'ui
           else: viewBox.w - self.props.width
    barY = sizePercent*(viewHeight - scrollBarSize)
    barStart = initPosition(barX.float, barY.float)

  self.window = ScrollWindow(
    viewHeight: viewHeight,
    contentHeight: contentHeight,
    contentViewRatio: contentViewRatio,
    contentOverflow: contentOverflow,
    scrollBy: self.window.scrollby,
  )
  self.bar = ScrollBar(
    size: scrollBarSize,
    start: barStart,
  )

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  let child = self.children[0]
  assert child.name == "scrollBody"
  calculateScroll(self, self.screenBox, child.screenBox, wheelDelta)
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
      current.offset = self.window.scrollby
      current.attrs.incl scrollPanel
      TemplateContents(self)

      # echo "SCROLL BODY: ", node.box, " => ", node.children[0].box
      # boxSizeOf node.children[0]
    rectangle "scrollBody":
      box self.bar.start.x, self.bar.start.y, self.props.width, self.bar.size
      fill blackColor

proc getWidgetParent*(self: ScrollPane): Figuro =
  # self.children[0] # "scrollBody"
  self

exportWidget(scroll, ScrollPane)
