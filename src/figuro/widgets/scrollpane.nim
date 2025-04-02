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
    scrollBy*: Position
    dragStart*: Option[Position]
    scrollBody*: Rectangle

  ScrollSettings* = object
    size* = initSize(10'ui, 10.0'ui)
    horizontal*: bool = false
    vertical*: bool = true
    barLeft*: bool
    barTop*: bool

  ScrollWindow* = object
    viewSize*: Size
    contentSize*: Size
    contentViewRatio*: Position
    contentOverflow*: Position

  ScrollBar* = object
    size*: Size
    sizePercent*: UiScalar
    offsetAmount*: UiScalar

proc hash*(x: ScrollWindow): Hash =
  result = Hash(0)
  for f in x.fields(): result = result !& hash(f)
  result = !$result

proc calculateWindow*(viewBox, childBox: Box): ScrollWindow =
  let
    viewSize = viewBox.wh
    contentSize = childBox.wh
    contentViewRatio = (viewSize / contentSize).clamp(0.0'ui, 1.0'ui)
    contentOverflow = (contentSize - viewSize).clamp(0'ui, contentSize)

  result = ScrollWindow(
    viewSize: viewSize,
    contentSize: contentSize,
    contentViewRatio: contentViewRatio.toPos(),
    contentOverflow: contentOverflow.toPos(),
  )
  # debug "calculateWindow:", viewSize= result.viewSize, contentSize= result.contentSize, contentViewRatio= result.contentViewRatio, contentOverflow= result.contentOverflow

proc updateScroll*(scrollBy: var Position, delta: Position, contentOverflow: Position, isAbsolute = false) =
  if isAbsolute:
    scrollBy = delta
  else:
    scrollBy -= delta
  scrollBy = scrollBy.clamp(0'ui, contentOverflow)

proc calculateBar*(
    settings: ScrollSettings, scrollBy: Position, window: ScrollWindow, dir: GridDir
): ScrollBar =
  let
    sizePercent = if window.contentOverFlow[dir] == 0'ui: 0'ui
                  else: clamp(scrollBy[dir] / window.contentOverflow[dir], 0'ui, 1'ui)
    scrollBarSize = window.contentViewRatio.toSize() * window.viewSize
    barDir = sizePercent * window.viewSize[dir] * (1.0'ui - window.contentViewRatio[dir])

  # debug "calculateBar:barY: ", barDir= barDir, sizePer= sizePercent, viewSize= window.viewSize[dir], scrollBarh= scrollBarSize[dir]
  result = ScrollBar(
    size: initSize(settings.size[dir], scrollBarSize[dir]),
    sizePercent: sizePercent,
    offsetAmount: barDir,
  )
  # debug "calculateBar: ", scrollBar = result

proc scroll*(self: ScrollPane, wheelDelta: Position, force: bool) =
  let child = self.findChild("scrollBody", Rectangle)
  var window = calculateWindow(self.screenBox, child.screenBox)
  let prevScrollBy = self.scrollBy
  self.scrollBy.updateScroll(wheelDelta * 20'ui, window.contentOverflow)
  let scrollChanged = prevScrollBy != self.scrollBy
  # debug "scroll: ", name = self.name, scrollChanged = scrollChanged
  if scrollChanged or force:
    trace "scroll:window ", name = self.name, hash = self.window.hash(), 
      scrollby = self.window.scrollby.repr, viewSize = self.window.viewSize.repr,
      contentSize = self.window.contentSize.repr,
      contentOverflow = self.window.contentOverflow.repr,
      contentViewRatio = self.window.contentViewRatio.repr
    trace "scroll:window ", name = self.name, hash = window.hash(),
      scrollby = window.scrollby.repr, viewSize = window.viewSize.repr,
      contentSize = window.contentSize.repr,
      contentOverflow = window.contentOverflow.repr,
      contentViewRatio = window.contentViewRatio.repr

  if scrollChanged or force:
    self.window = window
  assert child.name == "scrollBody"
  if self.settings.vertical:
    self.bary = calculateBar(self.settings, self.scrollBy, self.window, drow)
  if self.settings.horizontal:
    self.barx = calculateBar(self.settings, self.scrollBy, self.window, dcol)
  if scrollChanged or force:
    refresh(self)

proc scroll*(self: ScrollPane, wheelDelta: Position) {.slot.} =
  scroll(self, wheelDelta, force = false)

proc scrollBarDrag*(
    self: ScrollPane,
    kind: EventKind,
    initial: Position,
    cursor: Position,
    overlaps: bool,
    selected: Figuro
) {.slot.} =
  trace "scrollBarDrag: ", name = self.name, kind = kind, initial = initial, cursor = cursor, overlaps = overlaps, selected = selected != self
  case kind:
  of Exit:
    self.dragStart = Position.none
  of Init:
    self.dragStart = some self.scrollBy
  of Done:
    if self.dragStart.isSome():
      let delta = initial.positionDiff(cursor)
      self.window = calculateWindow(self.screenBox, self.scrollBody.screenBox)
      let offset = (self.dragStart.get() + delta / self.window.contentViewRatio)
      self.scrollBy.updateScroll(offset, self.window.contentOverflow, isAbsolute = true)

    if self.settings.vertical:
      self.bary = calculateBar(self.settings, self.scrollBy, self.window, drow)
    if self.settings.horizontal:
      self.barx = calculateBar(self.settings, self.scrollBy, self.window, dcol)
    refresh(self)

proc layoutResize*(self: ScrollPane, node: Figuro) {.slot.} =
  if self.children.len() == 0: return
  let scrollBody = self.children[0]
  # debug "LAYOUT RESIZE: ", self = self.name, node = node.name, scrollPaneBox = self.box, nodeBox = node.box, scrollBodyBox = scrollBody.box
  scroll(self, initPosition(0, 0), force = true)

proc draw*(self: ScrollPane) {.slot.} =
  withWidget(self):
    self.listens.events.incl evScroll
    uinodes.connect(self, doScroll, self, ScrollPane.scroll)
    uinodes.connect(self, doLayoutResize, self, ScrollPane.layoutResize)
    clipContent true
    this.cxMin = [0'ux, 0'ux]

    Rectangle.new "scrollBody":
      ## min-content is important here
      ## todo: do the same for horiz?
      self.scrollBody = this
      if self.settings.vertical:
        this.cxSize[drow] = cx"min-content"
      if self.settings.horizontal:
        this.cxSize[dcol] = cx"min-content"

      fill whiteColor.darken(0.2)
      this.offset = self.scrollBy
      this.flags.incl NfScrollPanel
      WidgetContents()
      scroll(self, initPosition(0, 0))
      for child in this.children:
        # echo "CHILD: ", child.name
        connect(child, doLayoutResize, self, layoutResize)

    if self.settings.vertical:
      Rectangle.new "scrollbar-vertical":
        with this:
          offset 100'pp - ux(self.settings.size.w), self.bary.offsetAmount
          size self.settings.size.w, csPerc(100.0'ui*self.window.contentViewRatio[drow])
          fill css"#0000ff" * 0.4
          cornerRadius 4'ui
        uinodes.connect(this, doDrag, self, scrollBarDrag)

    if self.settings.horizontal:
      Rectangle.new "scrollbar-horizontal":
        with this:
          offset self.barx.offsetAmount, 100'pp - ux(self.settings.size.h)
          size csPerc(100.0'ui*self.window.contentViewRatio[dcol]), self.settings.size.h
          fill css"#0000ff" * 0.4
          cornerRadius 4'ui
        uinodes.connect(this, doDrag, self, scrollBarDrag)


