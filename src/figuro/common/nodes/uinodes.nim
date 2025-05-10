import std/unicode
import std/monotimes
import std/hashes
import std/tables

import pkg/stack_strings
import pkg/sigils/weakrefs
import pkg/sigils
import pkg/cssgrid

import basics
import cssparser
import ../inputs
import ../rchannels

export unicode, monotimes
export cssgrid, stack_strings, weakrefs
export basics, inputs

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
    cssValues*: CssValues
    css*: seq[tuple[path: string, theme: CssTheme]]

  AppFrame* = ref object of Agent
    frameRunner*: AgentProcTy[tuple[]]
    proxies*: seq[AgentProxyShared]
    redrawNodes*: OrderedSet[Figuro]
    redrawLayout*: OrderedSet[Figuro]
    root*: Figuro
    uxInputList*: RChan[AppInputs]
    rendInputList*: RChan[RenderCommands]
    windowInfo*: WindowInfo
    windowTitle*: string
    windowStyle*: FrameStyle
    theme*: Theme
    configFile*: string
    saveWindowState*: bool
    clipboards*: RChan[ClipboardContents]

  Figuro* = ref object of Agent
    frame*: WeakRef[AppFrame]
    parent*: WeakRef[Figuro]
    uid*: NodeID
    name*: Atom
    widgetName*: Atom
    widgetClasses*: seq[Atom]
    children*: seq[Figuro]
    nIndex*: int
    diffIndex*: int
    lhash*: Hash

    box*, bpad*: Box
    bmin*, bmax*: Size
    screenBox*: Box
    offset*: Position
    totalOffset*: Position
    scroll*: Position
    prevSize*: Position

    flags*: set[NodeFlags]
    fieldSet*: set[FieldSetAttrs]
    userAttrs*: set[Attributes]

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
    cornerRadius*: array[DirectionCorners, UiScalar]
    image*: ImageStyle
    textLayout*: GlyphArrangement
    points*: seq[Position]

  FiguroContent* = object
    name*: Atom
    childInit*: proc(parent: Figuro, name: Atom, preDraw: proc(current: Figuro) {.closure.}) {.nimcall.}
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

  Blank* = ref object of BasicFiguro
  GridChild* = ref object of BasicFiguro

# proc changed*(f: Figuro): Hash =
#   var h = Hash(0)
#   h = h !& hash tp.filePath
#   result = !$h

proc getParent*(node: Figuro): Figuro =
  node.parent[]

proc getFrameBox*(node: Figuro): Box =
  if node.frame[].isNil:
    uiBox(0,0,0,0)
  else:
    node.frame[].windowInfo.box

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

proc getSkipLayout*(fig: Figuro): bool =
  NfSkipLayout in fig.flags or
  NfInactive in fig.flags or
  Hidden in fig.userAttrs

proc doTick*(fig: Figuro, now: MonoTime, delta: Duration) {.signal.}

proc doInitialize*(fig: Figuro) {.signal.}
  ## called before draw when a node is first created or reset
proc doDraw*(fig: Figuro) {.signal.}
  ## draws node
proc doLayoutResize*(fig: Figuro, node: Figuro) {.signal.}
  ## called after layout size changes
proc doLoad*(fig: Figuro) {.signal.}
proc doHover*(fig: Figuro, kind: EventKind) {.signal.}
proc doMouseClick*(fig: Figuro, kind: EventKind, buttons: set[UiMouse]) {.signal.}
proc doSingleClick*(fig: Figuro) {.signal.}
proc doDoubleClick*(fig: Figuro) {.signal.}
proc doTripleClick*(fig: Figuro) {.signal.}
proc doRightClick*(fig: Figuro) {.signal.}

proc doKeyInput*(fig: Figuro, rune: Rune) {.signal.}
proc doKeyPress*(fig: Figuro, pressed: set[UiKey], down: set[UiKey]) {.signal.}
proc doScroll*(fig: Figuro, wheelDelta: Position) {.signal.}
proc doDrag*(
  fig: Figuro, kind: EventKind,
  initial: Position,
  latest: Position,
  overlaps: bool,
  source: Figuro,
) {.signal.}
proc doDragDrop*(
  fig: Figuro, kind: EventKind,
  initial: Position,
  latest: Position,
  overlaps: bool,
  source: Figuro,
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

proc keyPress*(fig: BasicFiguro, pressed: set[UiKey], down: set[UiKey]) {.slot.} =
  discard

proc clicked*(self: BasicFiguro, kind: EventKind, buttons: set[UiMouse]) {.slot.} =
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

proc doMouseClickBubble*(fig: Figuro, kind: EventKind, buttonPress: set[UiMouse]) {.slot.} =
  emit fig.doMouseClick(kind, buttonPress)

proc doDragBubble*(
    fig: Figuro,
    kind: EventKind,
    initial: Position,
    latest: Position,
    overlaps: bool,
    source: Figuro,
) {.slot.} =
  emit fig.doDrag(kind, initial, latest, overlaps, source)

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
  elif signalName(signal) == "doSingleClick":
    a.listens.signals.incl {evClickInit, evClickDone, evPress, evRelease}
  elif signalName(signal) == "doDoubleClick":
    a.listens.signals.incl {evClickInit, evClickDone, evPress, evRelease}
  elif signalName(signal) == "doTripleClick":
    a.listens.signals.incl {evClickInit, evClickDone, evPress, evRelease}
  elif signalName(signal) == "doRightClick":
    a.listens.signals.incl {evClickInit, evClickDone, evPress, evRelease}
  elif signalName(signal) == "doHover":
    a.listens.signals.incl {evHover}
  elif signalName(signal) == "doDrag":
    a.listens.signals.incl {evDrag}
  elif signalName(signal) == "doDragDrop":
    a.listens.signals.incl {evDragEnd}
  signals.connect(a, signal, b, slot, acceptVoidSlot)

template bubble*(signal: typed, parent: typed) =
  connect(this, `signal`, parent, `signal Bubble`)

template bubble*(signal: typed) =
  connect(this, `signal`, this.parent[], `signal Bubble`)

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

proc refreshLayout*(node: Figuro) {.slot.} =
  ## Request that the node and it's children be redrawn
  # echo "refresh: ", node.name, " :: ", getStackTrace()
  if node == nil:
    return
  # app.requestedFrame.inc
  assert not node.frame.isNil
  node.frame[].redrawLayout.incl(node)

## User facing attributes
## 
## These are used to set the state of the node
## and are used by the CSS engine to determine
## the state of the node.
## 
## Also for general use by the widget author.

proc setUserAttr*(fig: Figuro, attr: Attributes | set[Attributes], state: bool) =
  if state:
    fig.userAttrs.incl attr
  else:
    fig.userAttrs.excl attr

proc setNodeAttr*(fig: Figuro, attr: NodeFlags | set[NodeFlags], state: bool) =
  if state:
    fig.flags.incl attr
  else:
    fig.flags.excl attr

proc contains*(fig: Figuro, attr: Attributes): bool =
  attr in fig.userAttrs
