import basics
import ../../meta
import ../../inputs

export basics, meta, inputs

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}


var lastUId {.runtimeVar.}: int = 0

type

  Figuro* = ref object of Agent
    uid*: NodeID
    children*: seq[Figuro]
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

    case kind*: NodeKind
    of nkRectangle:
      shadow*: Option[Shadow]
      cornerRadius*: UICoord
    of nkImage:
      image*: ImageStyle
    of nkText:
      textStyle*: TextStyle
      textLayout*: seq[GlyphPosition]
    of nkDrawable:
      points*: seq[Position]
    else:
      discard

  FiguroApp* = ref object of Figuro

  EventsCapture*[T] = object
    zlvl*: ZLevel
    flags*: T
    target*: Figuro

  MouseCapture* = EventsCapture[MouseEventFlags] 
  GestureCapture* = EventsCapture[GestureEventFlags] 

  CapturedEvents* = object
    mouse*: MouseCapture
    gesture*: GestureCapture


proc newUId*(): NodeID =
  # Returns next numerical unique id.
  inc lastUId
  when defined(js) or defined(StringUID):
    $lastUId
  else:
    NodeID(lastUId)

proc onTick*(tp: FiguroApp) {.signal.}
proc onDraw*(tp: FiguroApp) {.signal.}
proc onLoad*(tp: FiguroApp) {.signal.}
proc eventHover*(tp: FiguroApp) {.signal.}

proc tick*(fig: Figuro) {.slot.} =
  discard

proc draw*(fig: Figuro) {.slot.} =
  discard

proc load*(fig: Figuro) {.slot.} =
  discard

# proc tick*(tp: FiguroApp) {.slot.} =
#   emit tp.onTick()

# proc draw*(tp: FiguroApp) {.slot.} =
#   # echo "draw app"
#   emit tp.onDraw()
