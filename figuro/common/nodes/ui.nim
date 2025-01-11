import std/unicode
import std/monotimes
import std/hashes
import basics
import sigils
import ../../inputs
import ../../ui/basiccss
import cssgrid
import stack_strings
import sigils/weakrefs

export basics, sigils, inputs, cssgrid, stack_strings
export unicode, monotimes
export weakrefs

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

  Theme* = ref object
    font*: UiFont
    cssRules*: seq[CssBlock]

  AppFrame* = ref object of Agent
    frameRunner*: AgentProcTy[tuple[]]
    appTicker*: AgentProxyShared
    redrawNodes*: OrderedSet[Figuro]
    root*: Figuro
    uxInputList*: Chan[AppInputs]
    running*, focused*, minimized*, fullscreen*: bool

    windowSize*: Box ## Screen size in logical coordinates.
    windowRawSize*: Vec2    ## Screen coordinates
    theme*: Theme


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

    box*: Box
    screenBox*: Box
    offset*: Position
    totalOffset*: Position
    scroll*: Position

    attrs*: set[Attributes]
    userSetFields*: set[FieldSet]

    cxSize*: array[GridDir, Constraint]
    cxOffset*: array[GridDir, Constraint]

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

    preDraw*: proc (current: Figuro)
    postDraw*: proc (current: Figuro)
    contentsDraw*: proc (current, widget: Figuro)

    kind*: NodeKind
    shadow*: Option[Shadow]
    cornerRadius*: UICoord
    image*: ImageStyle
    textLayout*: GlyphArrangement
    points*: seq[Position]

  BasicFiguro* = ref object of Figuro

  StatefulFiguro*[T] = ref object of Figuro
    state*: T

  Property*[T] = ref object of Agent
    value*: T

proc `=destroy`*(obj: type(Figuro()[])) =
  ## destroy
  let objPtr = unsafeWeakRef(cast[Figuro](addr(obj)))
  for child in obj.children:
    assert objPtr == child.parent
    child.parent.pt = nil

proc children*(fig: WeakRef[Figuro]): seq[Figuro] =
  fig{}.children

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
  if fig.isNil: NodeID -1
  else: fig.uid

proc getId*(fig: WeakRef[Figuro]): NodeID =
  if fig.isNil: NodeID -1
  else: fig[].uid

proc doTick*(fig: Figuro, tickCount: int, now: MonoTime) {.signal.}

proc doDraw*(fig: Figuro) {.signal.}
proc doLoad*(fig: Figuro) {.signal.}
proc doHover*(fig: Figuro,
              kind: EventKind) {.signal.}
proc doClick*(fig: Figuro,
              kind: EventKind,
              keys: UiButtonView) {.signal.}
proc doKeyInput*(fig: Figuro, rune: Rune) {.signal.}
proc doKeyPress*(fig: Figuro,
                 pressed: UiButtonView,
                 down: UiButtonView) {.signal.}
proc doScroll*(fig: Figuro,
               wheelDelta: Position) {.signal.}
proc doDrag*(fig: Figuro,
             kind: EventKind,
             initial: Position,
             latest: Position) {.signal.}

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

proc keyPress*(fig: BasicFiguro,
              pressed: UiButtonView,
              down: UiButtonView) {.slot.} =
  discard

proc clicked*(self: BasicFiguro,
              kind: EventKind,
              buttons: UiButtonView) {.slot.} =
  discard

proc scroll*(fig: BasicFiguro,
             wheelDelta: Position) {.slot.} =
  discard

proc drag*(fig: BasicFiguro,
           kind: EventKind,
           initial: Position,
           latest: Position) {.slot.} =
  discard


proc doTickBubble*(fig: Figuro,
                   now: MonoTime) {.slot.} =
  emit fig.doTick(now)
proc doDrawBubble*(fig: Figuro) {.slot.} =
  emit fig.doDraw()
proc doLoadBubble*(fig: Figuro) {.slot.} =
  emit fig.doLoad()
proc doHoverBubble*(fig: Figuro,
                    kind: EventKind) {.slot.} =
  emit fig.doHover(kind)
proc doClickBubble*(fig: Figuro,
                    kind: EventKind,
                    buttonPress: UiButtonView) {.slot.} =
  emit fig.doClick(kind, buttonPress)
proc doDragBubble*(fig: Figuro,
                   kind: EventKind,
                   initial: Position,
                   latest: Position) {.slot.} =
  emit fig.doDrag(kind, initial, latest)


template connect*(
    a: Figuro,
    signal: typed,
    b: Figuro,
    slot: typed,
    acceptVoidSlot: static bool = false,
): void =
  ## template override
  when signalName(signal) == "doClick":
    a.listens.signals.incl {evClick, evClickOut}
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
  echo "  ".repeat(depth), "render: ", n.getId,
          # " p: ", n.parent[].getId,
          " name: ", $n.name,
          " zlvl: ", $n.zlevel
  for ci in n.children:
    printFiguros(ci, depth+1)

