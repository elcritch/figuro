import basics

export basics

var lastUId: int

type

  Node* = ref object
    uid*: NodeUID
    nodes*: seq[Node]
    nIndex*: int
    diffIndex*: int

    box*: Box
    orgBox*: Box
    screenBox*: Box
    offset*: Position
    totalOffset*: Position
    attrs*: set[Attributes]

    zlevel*: ZLevel
    rotation*: float32
    fill*: Color
    highlight*: Color
    transparency*: float32
    stroke*: Stroke
    cornerRadius*: (UICoord, UICoord, UICoord, UICoord)
    shadow*: Option[Shadow]

    image*: ImageStyle
    textStyle*: TextStyle

    textLayout*: seq[GlyphPosition]
    points*: seq[Position]

proc newUId*(): NodeUID =
  # Returns next numerical unique id.
  inc lastUId
  when defined(js) or defined(StringUID):
    $lastUId
  else:
    NodeUID(lastUId)

