
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
    viewSize: Position
    contentSize: Position
    contentOverflow: UICoord
    contentViewRatio: Position

  ScrollBar* = object
    size: UICoord
    start: Position

proc calculateScroll*(self: ScrollPane,
                      viewBox, childBox: Box,
                      wheelDelta: Position) =
  let
    viewSize = viewBox.wh
    contentSize = childBox.wh
    contentViewRatio = (viewSize/contentSize).clamp(0.0'ui, 1.0'ui)
    contentOverflow = (contentSize.y - viewSize.y).clamp(0'ui, contentSize.y)

  self.window.scrollby.y -= wheelDelta.y * 10.0
  self.window.scrollby.y = self.window.scrollby.y.clamp(0'ui, contentOverflow)
  self.window = ScrollWindow(
    viewSize: viewSize,
    contentSize: contentSize,
    contentViewRatio: contentViewRatio,
    contentOverflow: contentOverflow,
    scrollBy: self.window.scrollby,
  )

proc calculateBar*(props: ScrollProperties,
                   window: ScrollWindow): ScrollBar =
  let
    scrollBarSize = window.contentViewRatio.y * window.viewSize.y
    sizePercent = clamp(window.scrollby.y/window.contentOverflow, 0'ui, 1'ui)
    barX = if props.barLeft: 0'ui
           else: window.viewSize.x - props.width
    barY = sizePercent*(window.viewSize.y - scrollBarSize)
    barStart = initPosition(barX.float, barY.float)

  ScrollBar(
    size: scrollBarSize,
    start: barStart,
  )

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  let child = self.children[0]
  assert child.name == "scrollBody"
  calculateScroll(self, self.screenBox, child.screenBox, wheelDelta)
  self.bar = calculateBar(self.props, self.window)
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
