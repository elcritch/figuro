
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
    size* = initPosition(10'ui, 10.0'ui)
    barLeft: bool
    barTop: bool
  
  ScrollWindow* = object
    scrollby: Position
    viewSize: Position
    contentSize: Position
    contentOverflow: Position
    contentViewRatio: Position

  ScrollBar* = object
    size: Position
    start: Position

proc calculateScroll*(self: ScrollPane,
                      viewBox, childBox: Box,
                      wheelDelta: Position) =
  let
    viewSize = viewBox.wh
    contentSize = childBox.wh
    contentViewRatio = (viewSize/contentSize).clamp(0.0'ui, 1.0'ui)
    contentOverflow = (contentSize - viewSize).clamp(0'ui, contentSize.y)

  self.window.scrollby -= wheelDelta * 10.0'ui
  self.window.scrollby = self.window.scrollby.clamp(0'ui, contentOverflow)
  self.window = ScrollWindow(
    viewSize: viewSize,
    contentSize: contentSize,
    contentViewRatio: contentViewRatio,
    contentOverflow: contentOverflow,
    scrollBy: self.window.scrollby,
  )

proc calculateBar*(props: ScrollProperties,
                   window: ScrollWindow,
                   isY: bool,
                   ): ScrollBar =

  let
    sizePercent = clamp(window.scrollby/window.contentOverflow, 0'ui, 1'ui)
    scrollBarSize = window.contentViewRatio * window.viewSize

  if not isY:
    let
      barX = if props.barLeft: 0'ui
             else: window.viewSize.x - props.size.y
      barY = sizePercent.y*(window.viewSize.y - scrollBarSize.y)
    ScrollBar(
      size: initPosition(props.size.y, scrollBarSize.y),
      start: initPosition(barX, barY),
    )
  else:
    let
      barX = sizePercent.x*(window.viewSize.x - scrollBarSize.x)
      barY = if props.barTop: 0'ui
             else: window.viewSize.y - props.size.x
    ScrollBar(
      size: initPosition(scrollBarSize.x, props.size.x),
      start: initPosition(barX, barY),
    )

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  let child = self.children[0]
  assert child.name == "scrollBody"
  calculateScroll(self, self.screenBox, child.screenBox, wheelDelta)
  self.bar = calculateBar(self.props, self.window, false)
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
      box self.bar.start.x, self.bar.start.y, self.bar.size.x, self.bar.size.y
      fill blackColor

proc getWidgetParent*(self: ScrollPane): Figuro =
  # self.children[0] # "scrollBody"
  self

exportWidget(scroll, ScrollPane)
