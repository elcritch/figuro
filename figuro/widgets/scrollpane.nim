
import commons
import ../ui/utils

type
  ScrollPane* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    settings*: ScrollSettings
    window*: ScrollWindow
    barx*: ScrollBar
    bary*: ScrollBar

  ScrollSettings* = object
    size* = initPosition(10'ui, 10.0'ui)
    horizontal*: bool = false
    vertical*: bool = true
    barLeft*: bool
    barTop*: bool
  
  ScrollWindow* = object
    scrollby*: Position
    viewSize*: Position
    contentSize*: Position
    contentOverflow*: Position
    contentViewRatio*: Position

  ScrollBar* = object
    size*: Position
    start*: Position

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

proc calculateBar*(settings: ScrollSettings,
                   window: ScrollWindow,
                   isY: bool,
                   ): ScrollBar =
  let
    sizePercent = clamp(window.scrollby/window.contentOverflow, 0'ui, 1'ui)
    scrollBarSize = window.contentViewRatio * window.viewSize
  if isY:
    let
      barX = if settings.barLeft: 0'ui
             else: window.viewSize.x - settings.size.y
      barY = sizePercent.y*(window.viewSize.y - scrollBarSize.y)
    ScrollBar(size: initPosition(settings.size.y, scrollBarSize.y),
              start: initPosition(barX, barY))
  else:
    let
      barX = sizePercent.x*(window.viewSize.x - scrollBarSize.x)
      barY = if settings.barTop: 0'ui
             else: window.viewSize.y - settings.size.x
    ScrollBar(size: initPosition(scrollBarSize.x, settings.size.x),
              start: initPosition(barX, barY))

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  let child = self.children[0]
  assert child.name == "scrollBody"
  calculateScroll(self, self.screenBox, child.screenBox, wheelDelta)
  if self.settings.vertical:
    self.bary = calculateBar(self.settings, self.window, isY=true)
  if self.settings.horizontal:
    self.barx = calculateBar(self.settings, self.window, isY=false)
  refresh(self)

proc draw*(self: ScrollPane) {.slot.} =
  withDraw self:
    current.listens.events.incl evScroll
    connect(current, doScroll, self, ScrollPane.scroll)
    rectangle "scrollBody":
      ## max-content is important here
      ## todo: do the same for horiz?
      size 100'pp, 100'pp
      if self.settings.vertical:
        current.cxSize[drow] = cx"max-content"
      if self.settings.horizontal:
        current.cxSize[dcol] = cx"max-content"

      fill whiteColor.darken(0.2)
      current.offset = self.window.scrollby
      current.attrs.incl scrollPanel
      TemplateContents(self)

    if self.settings.vertical:
      rectangle "scrollbar-vertical":
        box self.bary.start.x, self.bary.start.y, self.bary.size.x, self.bary.size.y
        fill css"#0000ff" * 0.4
        cornerRadius 4'ui
    if self.settings.horizontal:
      rectangle "scrollbar-horizontal":
        box self.barx.start.x, self.barx.start.y, self.barx.size.x, self.barx.size.y
        fill css"#0000ff" * 0.4
        cornerRadius 4'ui

proc getWidgetParent*(self: ScrollPane): Figuro =
  # self.children[0] # "scrollBody"
  self

exportWidget(scroll, ScrollPane)
