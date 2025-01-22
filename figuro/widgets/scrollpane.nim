import commons
import std/hashes

import chronicles

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

proc hash*(x: ScrollWindow): Hash =
  result = Hash(0)
  for f in x.fields(): result = result !& hash(f)
  result = !$result

proc calculateWindow*(scrollby: Position, viewBox, childBox: Box): ScrollWindow =
  let
    viewSize = viewBox.wh
    contentSize = childBox.wh
    contentViewRatio = (viewSize / contentSize).clamp(0.0'ui, 1.0'ui)
    contentOverflow = (contentSize - viewSize).clamp(0'ui, contentSize.y)

  result = ScrollWindow(
    viewSize: viewSize,
    contentSize: contentSize,
    contentViewRatio: contentViewRatio,
    contentOverflow: contentOverflow,
    scrollBy: scrollby,
  )
  trace "calculateWindow: ", window = result.repr

proc updateScroll*(window: var ScrollWindow, delta: Position, isAbsolute = false) =
  if isAbsolute:
    window.scrollby = delta
  else:
    window.scrollby -= delta
  window.scrollby = window.scrollby.clamp(0'ui, window.contentOverflow)

proc calculateBar*(
    settings: ScrollSettings, window: ScrollWindow, isY: bool
): ScrollBar =
  trace "calculateBar: ", settings = settings.repr, window = window.repr
  let
    sizePercent = clamp(window.scrollby / window.contentOverflow, 0'ui, 1'ui)
    scrollBarSize = window.contentViewRatio * window.viewSize
  if isY:
    let
      barX =
        if settings.barLeft:
          0'ui
        else:
          window.viewSize.x - settings.size.y
      barY = sizePercent.y * (window.viewSize.y - scrollBarSize.y)
    ScrollBar(
      size: initPosition(settings.size.y, scrollBarSize.y),
      start: initPosition(barX, barY),
    )
  else:
    let
      barX = sizePercent.x * (window.viewSize.x - scrollBarSize.x)
      barY =
        if settings.barTop:
          0'ui
        else:
          window.viewSize.y - settings.size.x
    ScrollBar(
      size: initPosition(scrollBarSize.x, settings.size.x),
      start: initPosition(barX, barY),
    )

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  let child = self.children[0]
  var window = calculateWindow(self.window.scrollby, self.screenBox, child.screenBox)
  window.updateScroll(wheelDelta * 10'ui)
  let windowChanged = window.hash() != self.window.hash()
  debug "scroll: ", name = self.name, windowChanged = windowChanged
  if windowChanged:
    debug "scroll:window ", name = self.name, hash = self.window.hash(), 
      scrollby = self.window.scrollby.repr, viewSize = self.window.viewSize.repr, contentSize = self.window.contentSize.repr, contentOverflow = self.window.contentOverflow.repr, contentViewRatio = self.window.contentViewRatio.repr
    debug "scroll:window ", name = self.name, hash = window.hash(),
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

proc draw*(self: ScrollPane) {.slot.} =
  withWidget(self):
    self.listens.events.incl evScroll
    connect(self, doScroll, self, ScrollPane.scroll)
    self.clipContent true
    debug "scroll:draw: ", name = self.name

    rectangle "scrollBody":
      ## max-content is important here
      ## todo: do the same for horiz?
      size node, 100'pp, 100'pp
      if self.settings.vertical:
        node.cxSize[drow] = cx"max-content"
      if self.settings.horizontal:
        node.cxSize[dcol] = cx"max-content"

      with node:
        fill whiteColor.darken(0.2)
      node.offset = self.window.scrollby
      node.attrs.incl scrollPanel
      WidgetContents()
      scroll(self, initPosition(0, 0))

    if self.settings.vertical:
      rectangle "scrollbar-vertical":
        with node:
          box self.bary.start.x, self.bary.start.y, self.bary.size.x, self.bary.size.y
          fill css"#0000ff" * 0.4
          cornerRadius 4'ui
          connect(doDrag, self, scrollBarDrag)
    if self.settings.horizontal:
      rectangle "scrollbar-horizontal":
        with node:
          box self.barx.start.x, self.barx.start.y, self.barx.size.x, self.barx.size.y
          fill css"#0000ff" * 0.4
          cornerRadius 4'ui

proc getWidgetParent*(self: ScrollPane): Figuro =
  self

