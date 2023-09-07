import basics
import ../../meta
import ../../inputs
import cssgrid
import stack_strings

export basics, meta, inputs, cssgrid, stack_strings

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}


type

  InputEvents* = object
    mouse*: MouseEventFlags
    keyboard*: KeyboardEventFlags

  ListenEvents* = object
    mouse*: MouseEventFlags
    mouseSignals*: MouseEventFlags

  Figuro* = ref object of Agent
    parent*: Figuro
    name*: StackString[16]
    uid*: NodeID
    children*: seq[Figuro]
    # parent*: Figuro
    nIndex*: int
    diffIndex*: int

    box*: Box
    orgBox*: Box
    screenBox*: Box
    offset*: Position
    totalOffset*: Position
    attrs*: set[Attributes]

    cxSize*: array[GridDir, Constraint]
    cxOffset*: array[GridDir, Constraint]

    events*: InputEvents
    listens*: ListenEvents

    zlevel*: ZLevel
    rotation*: float32
    fill*: Color
    highlight*: Color
    transparency*: float32
    stroke*: Stroke

    gridTemplate*: GridTemplate
    gridItem*: GridItem

    postDraw*: proc (current: Figuro)

    kind*: NodeKind
    shadow*: Option[Shadow]
    cornerRadius*: UICoord
    image*: ImageStyle
    textLayout*: GlyphArrangement
    points*: seq[Position]

    # case kind*: NodeKind
    # of nkRectangle:
    #   shadow*: Option[Shadow]
    #   cornerRadius*: UICoord
    # of nkImage:
    #   image*: ImageStyle
    # of nkText:
    #   textLayout*: GlyphArrangement
    # of nkDrawable:
    #   points*: seq[Position]
    # else:
    #   discard


proc getName*(fig: Figuro): string =
  result = fig.name.toString()

proc getId*(fig: Figuro): NodeID =
  ## Get's the Figuro Node's ID
  ## or returns 0 if it's nil
  if fig.isNil: NodeID -1
  else: fig.uid

proc onTick*(fig: Figuro) {.signal.}
proc onDraw*(fig: Figuro) {.signal.}
proc onLoad*(fig: Figuro) {.signal.}
proc onHover*(fig: Figuro, kind: EventKind) {.signal.}
proc onClick*(fig: Figuro, kind: EventKind, buttonPress: UiButtonView) {.signal.}

proc tick*(fig: Figuro) {.slot.} =
  discard

proc draw*(fig: Figuro) {.slot.} =
  discard

proc load*(fig: Figuro) {.slot.} =
  discard

proc clearDraw*(fig: Figuro) {.slot.} =
  fig.attrs.incl postDrawReady
  fig.diffIndex = 0

proc handlePostDraw*(fig: Figuro) {.slot.} =
  if fig.postDraw != nil:
    fig.postDraw(fig)


proc onTickBubble*(fig: Figuro) {.slot.} =
  emit fig.onTick()
proc onDrawBubble*(fig: Figuro) {.slot.} =
  emit fig.onDraw()
proc onLoadBubble*(fig: Figuro) {.slot.} =
  emit fig.onLoad()
proc onHoverBubble*(fig: Figuro, kind: EventKind) {.slot.} =
  emit fig.onHover(kind)
proc onClickBubble*(fig: Figuro, kind: EventKind, buttonPress: UiButtonView) {.slot.} =
  echo "CLICK BUBBLE"
  emit fig.onClick(kind, buttonPress)

template connect*(
    a: Figuro,
    signal: typed,
    b: Figuro,
    slot: typed
) =
  when signalName(signal) == "onClick":
    a.listens.mouseSignals.incl {evClick, evClickOut}
  elif signalName(signal) == "onHover":
    a.listens.mouseSignals.incl {evHover}
  signals.connect(a, signal, b, slot)

template bubble*(signal: typed, parent: typed) =
  connect(current, `signal`, parent, `signal Bubble`)

template bubble*(signal: typed) =
  connect(current, `signal`, current.parent, `signal Bubble`)

