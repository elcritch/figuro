import std/unicode
import basics
import ../../meta
import ../../inputs
import cssgrid
import stack_strings

export basics, meta, inputs, cssgrid, stack_strings
export unicode

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

  Figuro* = ref object of Agent
    parent*: Figuro
    uid*: NodeID
    name*: StackString[16]
    children*: seq[Figuro]
    nIndex*: int
    diffIndex*: int

    box*: Box
    orgBox*: Box
    screenBox*: Box
    offset*: Position
    totalOffset*: Position
    scroll*: Position

    attrs*: set[Attributes]

    cxSize*: array[GridDir, Constraint]
    cxOffset*: array[GridDir, Constraint]

    events*: EventFlags
    listens*: ListenEvents

    theme*: Theme

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
    

proc new*[T: Figuro](tp: typedesc[T]): T =
  result = T()
  result.agentId = nextAgentId()
  result.uid = result.agentId

proc getName*(fig: Figuro): string =
  result = fig.name.toString()

proc getId*(fig: Figuro): NodeID =
  ## Get's the Figuro Node's ID
  ## or returns 0 if it's nil
  if fig.isNil: NodeID -1
  else: fig.uid


proc doTick*(fig: Figuro) {.signal.}
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

proc tick*(fig: Figuro) {.slot.} =
  discard

proc draw*(fig: Figuro) {.slot.} =
  discard

proc load*(fig: Figuro) {.slot.} =
  discard

proc keyInput*(fig: Figuro, rune: Rune) {.slot.} =
  discard

proc keyPress*(fig: Figuro,
               pressed: UiButtonView,
               down: UiButtonView) {.slot.} =
  discard

proc clicked*(self: Figuro,
              kind: EventKind,
              buttons: UiButtonView) {.slot.} =
  discard

proc scroll*(fig: Figuro,
             wheelDelta: Position) {.slot.} =
  discard

proc doTickBubble*(fig: Figuro) {.slot.} =
  emit fig.doTick()
proc doDrawBubble*(fig: Figuro) {.slot.} =
  emit fig.doDraw()
proc doLoadBubble*(fig: Figuro) {.slot.} =
  emit fig.doLoad()
proc doHoverBubble*(fig: Figuro, kind: EventKind) {.slot.} =
  emit fig.doHover(kind)
proc doClickBubble*(fig: Figuro, kind: EventKind, buttonPress: UiButtonView) {.slot.} =
  emit fig.doClick(kind, buttonPress)

template connect*(
    a: Figuro,
    signal: typed,
    b: Figuro,
    slot: typed
) =
  when signalName(signal) == "doClick":
    a.listens.signals.incl {evClick, evClickOut}
  elif signalName(signal) == "doHover":
    a.listens.signals.incl {evHover}
  signals.connect(a, signal, b, slot)

template bubble*(signal: typed, parent: typed) =
  connect(current, `signal`, parent, `signal Bubble`)

template bubble*(signal: typed) =
  connect(current, `signal`, current.parent, `signal Bubble`)

proc printFiguros*(n: Figuro, depth = 0) =
  echo "  ".repeat(depth), "render: ", n.getId,
          " p: ", n.parent.getId,
          " name: ", $n.name,
          " zlvl: ", $n.zlevel
  for ci in n.children:
    printFiguros(ci, depth+1)

