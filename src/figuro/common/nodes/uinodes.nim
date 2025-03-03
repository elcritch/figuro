import std/unicode
import std/monotimes
import std/hashes
import pkg/stack_strings
import pkg/sigils/weakrefs
import pkg/sigils
import pkg/cssgrid

import basics
import basiccss
import ../inputs

export unicode, monotimes
export cssgrid, stack_strings, weakrefs
export basics, inputs, basiccss

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

type
  InputEvents* = object
    events*: EventFlags

  ListenEvents* = object
    events*: EventFlags
    signals*: EventFlags

  Theme* = object
    font*: UiFont
    css*: CssTheme

  AppFrame* = ref object of Agent
    frameRunner*: AgentProcTy[tuple[]]
    proxies*: seq[AgentProxyShared]
    redrawNodes*: OrderedSet[Figuro]
    root*: Figuro
    uxInputList*: Chan[AppInputs]
    rendInputList*: Chan[RenderCommands]
    running*, focused*, minimized*, fullscreen*: bool

    windowTitle*: string
    windowSize*: Box ## Screen size in logical coordinates.
    windowRawSize*: Vec2 ## Screen coordinates
    theme*: Theme
    windowStyle*: FrameStyle

    configFile*: string

  Figuro* = ref object of Agent
    frame*: WeakRef[AppFrame]
    parent*: WeakRef[Figuro]
    uid*: NodeID
    name*: string
    widgetName*: string
    widgetClasses*: seq[string]
    children*: seq[Figuro]
    nIndex*: int
    diffIndex*: int

    box*, bpad*: Box
    bmin*, bmax*: Size
    screenBox*: Box
    offset*: Position
    totalOffset*: Position
    scroll*: Position
    prevSize*: Position

    attrs*: set[Attributes]
    userSetFields*: set[FieldSet]

    cxSize*: array[GridDir, Constraint] = [csAuto(), csNone()]
    cxOffset*: array[GridDir, Constraint] = [csAuto(), csAuto()]
    cxPadSize*: array[GridDir, Constraint] = [csAuto(), csAuto()]
    cxPadOffset*: array[GridDir, Constraint] = [csAuto(), csAuto()]
    cxMin*: array[GridDir, Constraint] = [csNone(), csNone()]
    cxMax*: array[GridDir, Constraint] = [csNone(), csNone()]

    events*: EventFlags
    listens*: ListenEvents

    zlevel*: ZLevel
    rotation*: float32
    fill*: Color
    highlight*: Color
    transparency*: float32
    stroke*: Stroke

    gridTemplate*: GridTemplate
    gridItem*: GridItem

    preDraw*: proc(current: Figuro)
    postDraw*: proc(current: Figuro)
    contents*: seq[FiguroContent]
    # contentsDraw*: proc(current, widget: Figuro)
    # contentProcs*: seq[proc(parent: Figuro)]

    kind*: NodeKind
    shadow*: array[ShadowStyle, Shadow]
    cornerRadius*: UiScalar
    image*: ImageStyle
    textLayout*: GlyphArrangement
    points*: seq[Position]

  FiguroContent* = object
    name*: string
    childInit*: proc(parent: Figuro, name: string, preDraw: proc(current: Figuro) {.closure.}) {.nimcall.}
    childPreDraw*: proc(current: Figuro) {.closure.}

  BasicFiguro* = ref object of Figuro

  StatefulFiguro*[T] = ref object of Figuro
    state*: T

  Property*[T] = ref object of Agent
    value*: T

  Rectangle* = ref object of BasicFiguro

  Text* = ref object of BasicFiguro
    hAlign*: FontHorizontal = Left
    vAlign*: FontVertical = Top
    font*: UiFont
    color*: Color = parseHtmlColor("black")

# proc changed*(f: Figuro): Hash =
#   var h = Hash(0)
#   h = h !& hash tp.filePath
#   result = !$h

proc children*(fig: WeakRef[Figuro]): seq[Figuro] =
  fig[].children

proc hash*(a: AppFrame): Hash =
  a.root.hash()

var lastNodeUID {.runtimeVar.} = 0

proc nextFiguroId*(): NodeID =
  lastNodeUID.inc()
  result = lastNodeUID

proc newFiguro*[T: Figuro](tp: typedesc[T]): T =
  result = T()
  result.uid = nextFiguroId()

proc getName*(fig: Figuro): string =
  result = $fig.name

proc getId*(fig: Figuro): NodeID =
  ## Get's the Figuro Node's ID
  ## or returns 0 if it's nil
  if fig.isNil:
    NodeID -1
  else:
    fig.uid

proc getId*(fig: WeakRef[Figuro]): NodeID =
  if fig.isNil:
    NodeID -1
  else:
    fig[].uid

proc doTick*(fig: Figuro, now: MonoTime, delta: Duration) {.signal.}

proc doInitialize*(fig: Figuro) {.signal.}
  ## called before draw when a node is first created or reset
proc doDraw*(fig: Figuro) {.signal.}
  ## draws node
proc doLayoutResize*(fig: Figuro, node: Figuro, resize: tuple[prev: Position, curr: Position]) {.signal.}
  ## called after layout size changes
proc doLoad*(fig: Figuro) {.signal.}
proc doHover*(fig: Figuro, kind: EventKind) {.signal.}
proc doMouseClick*(fig: Figuro, kind: EventKind, keys: UiButtonView) {.signal.}
proc doKeyInput*(fig: Figuro, rune: Rune) {.signal.}
proc doKeyPress*(fig: Figuro, pressed: UiButtonView, down: UiButtonView) {.signal.}
proc doScroll*(fig: Figuro, wheelDelta: Position) {.signal.}
proc doDrag*(
  fig: Figuro, kind: EventKind, initial: Position, latest: Position
) {.signal.}

proc doUpdate*[T](agent: Agent, value: T) {.signal.}
proc doChanged*(agent: Agent) {.signal.}

## Standard slots that will be called for any widgets
## 
## These are empty for BasicFiguro (e.g. non-widgets)
proc tick*(fig: BasicFiguro) {.slot.} =
  discard

proc draw*(fig: BasicFiguro) {.slot.} =
  discard

proc keyInput*(fig: BasicFiguro, rune: Rune) {.slot.} =
  discard

proc keyPress*(fig: BasicFiguro, pressed: UiButtonView, down: UiButtonView) {.slot.} =
  discard

proc clicked*(self: BasicFiguro, kind: EventKind, buttons: UiButtonView) {.slot.} =
  discard

proc scroll*(fig: BasicFiguro, wheelDelta: Position) {.slot.} =
  discard

proc drag*(
    fig: BasicFiguro, kind: EventKind, initial: Position, latest: Position
) {.slot.} =
  discard

proc doTickBubble*(fig: Figuro, now: MonoTime, period: Duration) {.slot.} =
  emit fig.doTick(now, period)

proc doDrawBubble*(fig: Figuro) {.slot.} =
  emit fig.doDraw()

proc doLoadBubble*(fig: Figuro) {.slot.} =
  emit fig.doLoad()

proc doHoverBubble*(fig: Figuro, kind: EventKind) {.slot.} =
  emit fig.doHover(kind)

proc doClickBubble*(fig: Figuro, kind: EventKind, buttonPress: UiButtonView) {.slot.} =
  emit fig.doMouseClick(kind, buttonPress)

proc doDragBubble*(
    fig: Figuro, kind: EventKind, initial: Position, latest: Position
) {.slot.} =
  emit fig.doDrag(kind, initial, latest)

template connect*(
    a: Figuro,
    signal: typed,
    b: Figuro,
    slot: typed,
    acceptVoidSlot: static bool = false,
): void =
  ## template override
  when signalName(signal) == "doMouseClick":
    a.listens.signals.incl {evClickInit, evClickDone, evPress, evRelease}
  elif signalName(signal) == "doHover":
    a.listens.signals.incl {evHover}
  elif signalName(signal) == "doDrag":
    a.listens.signals.incl {evDrag, evDragEnd}
  signals.connect(a, signal, b, slot, acceptVoidSlot)

template bubble*(signal: typed, parent: typed) =
  connect(node, `signal`, parent, `signal Bubble`)

template bubble*(signal: typed) =
  connect(node, `signal`, node.parent[], `signal Bubble`)

proc printFiguros*(n: Figuro, depth = 0) =
  echo "  ".repeat(depth),
    "render: ",
    n.getId,
    # " p: ", n.parent[].getId,
    " name: ",
    $n.name,
    " zlvl: ",
    $n.zlevel
  for ci in n.children:
    printFiguros(ci, depth + 1)

proc refresh*(node: Figuro) {.slot.} =
  ## Request that the node and it's children be redrawn
  # echo "refresh: ", node.name, " :: ", getStackTrace()
  if node == nil:
    return
  # app.requestedFrame.inc
  assert not node.frame.isNil
  node.frame[].redrawNodes.incl(node)
  when defined(figuroDebugRefresh):
    echo "REFRESH: ", getStackTrace()
