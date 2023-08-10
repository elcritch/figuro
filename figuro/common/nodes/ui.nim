import basics
import ../../meta

export basics, meta

var lastUId: int = 0

type

  UiStatus* = enum
    onHover
    onClick

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
    status*: set[UiStatus]

    zlevel*: ZLevel
    rotation*: float32
    fill*: Color
    highlight*: Color
    transparency*: float32
    stroke*: Stroke

    case kind*: NodeKind
    of nkRectangle:
      shadow*: Option[Shadow]
      cornerRadius*: (UICoord, UICoord, UICoord, UICoord)
    of nkImage:
      image*: ImageStyle
    of nkText:
      textStyle*: TextStyle
      textLayout*: seq[GlyphPosition]
    of nkDrawable:
      points*: seq[Position]
    else:
      discard

proc newUId*(): NodeID =
  # Returns next numerical unique id.
  inc lastUId
  when defined(js) or defined(StringUID):
    $lastUId
  else:
    NodeID(lastUId)

proc tick*(fig: Figuro) {.slot.} =
  discard

proc render*(fig: Figuro) =
  discard
  echo "render: ", typeof fig

proc load*(fig: Figuro) {.slot.} =
  discard

proc onHover*(fig: Figuro) {.slot.} =
  fig.status.incl onHover