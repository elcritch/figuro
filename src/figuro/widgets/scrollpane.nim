import std/hashes
import pkg/chronicles
import ../widget

type
  ScrollPane* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    settings*: ScrollSettings
    window*: ScrollWindow
    barx*: ScrollBar
    bary*: ScrollBar
    dragStart*: Option[Position]

  ScrollSettings* = object
    size* = initSize(10'ui, 10.0'ui)
    horizontal*: bool = false
    vertical*: bool = true
    barLeft*: bool
    barTop*: bool

  ScrollWindow* = object
    scrollby*: Position
    viewSize*: Size
    contentSize*: Size
    contentViewRatio*: Position
    contentOverflow*: Position

  ScrollBar* = object
    size*: Size
    start*: Position

proc hash*(x: ScrollWindow): Hash =
  result = Hash(0)
  for f in x.fields(): result = result !& hash(f)
  result = !$result

proc calculateWindow*(scrollby: Position, viewBox, childBox: Box): ScrollWindow =
  let
    viewSize = viewBox.wh
    contentSize = childBox.wh
    contentViewRatio = (viewSize / contentSize).clamp(0.0'ui, 1.0'ui)
    contentOverflow = (contentSize - viewSize).clamp(0'ui, contentSize.w)

  result = ScrollWindow(
    viewSize: viewSize,
    contentSize: contentSize,
    contentViewRatio: contentViewRatio.toPos(),
    contentOverflow: contentOverflow.toPos(),
    scrollBy: scrollby,
  )
  info "calculateWindow:child ", childBoxWh = childBox.wh, viewBoxWh= viewBox.wh
  info "calculateWindow: ", viewSize= result.viewSize, contentSize= result.contentSize, contentViewRatio= result.contentViewRatio, contentOverflow= result.contentOverflow, scrollBy= result.scrollby

proc updateScroll*(window: var ScrollWindow, delta: Position, isAbsolute = false) =
  if isAbsolute:
    window.scrollby = delta
  else:
    window.scrollby -= delta
  window.scrollby = window.scrollby.clamp(0'ui, window.contentOverflow)

proc calculateBar*(
    settings: ScrollSettings, window: ScrollWindow, isY: bool
): ScrollBar =
  debug "calculateBar: ", settings = settings.repr
  debug "calculateBar: ", window = window.repr
  let dir = if isY: drow else: dcol
  let perp = if not isY: drow else: dcol

  let
    sizePercent = if window.contentOverFlow[dir] == 0'ui: 0'ui
                  else: clamp(window.scrollby[dir] / window.contentOverflow[dir], 0'ui, 1'ui)
    scrollBarSize = window.contentViewRatio.toSize() * window.viewSize
  debug "calculateBar:sizePercent: ", sizePercent = sizePercent, scrollby= window.scrollby, contentOverFlow= window.contentOverflow
  let
    barPerp =
      if settings.barLeft:
        0'ui
      else:
        window.viewSize.w - settings.size.h
    barDir = sizePercent * (window.viewSize[dir] - scrollBarSize[dir])
  debug "calculateBar:barY: ", barDir = barDir, sizePerY= sizePercent, viewSizeH= window.viewSize.h, scrollBarhH= scrollBarSize.h
  result = ScrollBar(
    size: initSize(settings.size[dir], scrollBarSize[dir]),
    start: initPosition(barPerp, barDir),
  )
  info "calculateBar: ", scrollBar = result

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  let child = self.children[0]
  var window = calculateWindow(self.window.scrollby, self.screenBox, child.screenBox)
  window.updateScroll(wheelDelta * 10'ui)
  let windowChanged = window.hash() != self.window.hash()
  trace "scroll: ", name = self.name, windowChanged = windowChanged
  if windowChanged:
    trace "scroll:window ", name = self.name, hash = self.window.hash(), 
      scrollby = self.window.scrollby.repr, viewSize = self.window.viewSize.repr, contentSize = self.window.contentSize.repr, contentOverflow = self.window.contentOverflow.repr, contentViewRatio = self.window.contentViewRatio.repr
    trace "scroll:window ", name = self.name, hash = window.hash(),
      scrollby = window.scrollby.repr, viewSize = window.viewSize.repr, contentSize = window.contentSize.repr, contentOverflow = window.contentOverflow.repr, contentViewRatio = window.contentViewRatio.repr
  if windowChanged:
    self.window = window
  let prevScrollBy = self.window.scrollby
  assert child.name == "scrollBody"
  # self.window.updateScroll(wheelDelta * 10'ui)
  if self.settings.vertical:
    self.bary = calculateBar(self.settings, self.window, isY = true)
  if self.settings.horizontal:
    self.barx = calculateBar(self.settings, self.window, isY = false)
  if windowChanged:
    refresh(self)

proc scrollBarDrag*(
    self: ScrollPane, kind: EventKind, initial: Position, cursor: Position
) {.slot.} =
  let child = self.children[0]
  assert child.name == "scrollBody"
  let delta = initial.positionDiff(cursor)
  if kind == Exit:
    self.dragStart = Position.none
  else:
    if self.dragStart.isNone:
      self.dragStart = some self.window.scrollby

    self.window = calculateWindow(self.window.scrollby, self.screenBox, child.screenBox)
    let offset = (self.dragStart.get() + delta / self.window.contentViewRatio)
    self.window.updateScroll(offset, isAbsolute = true)

    if self.settings.vertical:
      self.bary = calculateBar(self.settings, self.window, isY = true)
    if self.settings.horizontal:
      self.barx = calculateBar(self.settings, self.window, isY = false)
    refresh(self)

proc layoutResize*(self: ScrollPane, child: Figuro, resize: tuple[prev: Position, curr: Position]) {.slot.} =
  debug "LAYOUT RESIZE: ", self = self.name, child = child.name, node = self.children[0].name,
    prevW = resize.prev.x, prevH = resize.prev.y,
    currW = resize.curr.x, currH = resize.curr.y
  # self.children[0].box.w = resize.curr.x
  # self.children[0].box.h = resize.curr.y
  # scroll(self, initPosition(0, 0))
  # refresh(self)

proc draw*(self: ScrollPane) {.slot.} =
  withWidget(self):
    self.listens.events.incl evScroll
    connect(self, doScroll, self, ScrollPane.scroll)
    self.clipContent true
    trace "scroll:draw: ", name = self.name

    rectangle "scrollBody":
      ## max-content is important here
      ## todo: do the same for horiz?
      if self.settings.vertical:
        this.cxSize[drow] = cx"min-content"
      if self.settings.horizontal:
        this.cxSize[dcol] = cx"min-content"

      with this:
        fill whiteColor.darken(0.2)
      this.offset = self.window.scrollby
      this.attrs.incl scrollPanel
      WidgetContents()
      scroll(self, initPosition(0, 0))
      for child in this.children:
        # echo "CHILD: ", child.name
        connect(child, doLayoutResize, self, layoutResize)

    if self.settings.vertical:
      rectangle "scrollbar-vertical":
        with this:
          box self.bary.start.x, self.bary.start.y, self.bary.size.w, self.bary.size.h
          fill css"#0000ff" * 0.4
          cornerRadius 4'ui
          connect(doDrag, self, scrollBarDrag)
    if self.settings.horizontal:
      rectangle "scrollbar-horizontal":
        with this:
          box self.barx.start.x, self.barx.start.y, self.barx.size.w, self.barx.size.h
          fill css"#0000ff" * 0.4
          cornerRadius 4'ui

proc getWidgetParent*(self: ScrollPane): Figuro =
  self

