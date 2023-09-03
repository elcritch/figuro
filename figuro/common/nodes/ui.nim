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

  EventsCapture*[T] = object
    zlvl*: ZLevel
    flags*: T
    target*: Figuro

  MouseCapture* = EventsCapture[MouseEventFlags] 
  GestureCapture* = EventsCapture[GestureEventFlags] 

  CapturedEvents* = object
    mouse*: MouseCapture
    gesture*: GestureCapture

proc getName*(fig: Figuro): string =
  result = fig.name.toString()

proc getId*(fig: Figuro): NodeID =
  ## Get's the Figuro Node's ID
  ## or returns 0 if it's nil
  if fig.isNil: NodeID -1
  else: fig.uid

proc onTick*(tp: Figuro) {.signal.}
proc onDraw*(tp: Figuro) {.signal.}
proc onLoad*(tp: Figuro) {.signal.}
proc onHover*(tp: Figuro, kind: EventKind) {.signal.}
proc onClick*(tp: Figuro, kind: EventKind, buttonPress: UiButtonView) {.signal.}

proc tick*(fig: Figuro) {.slot.} =
  discard

proc draw*(fig: Figuro) {.slot.} =
  discard

proc load*(fig: Figuro) {.slot.} =
  discard

proc clearDraw*(fig: Figuro) {.slot.} =
  fig.attrs.incl postDrawReady

proc handlePostDraw*(fig: Figuro) {.slot.} =
  if fig.postDraw != nil:
    fig.postDraw(fig)
