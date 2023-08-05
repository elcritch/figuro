import basics

export basics

var lastUId: int

type

  NodeKind* = enum
    ## Different types of nodes.
    nkRoot
    nkFrame
    nkText
    nkRectangle
    nkDrawable
    nkScrollBar
    nkImage

  Attributes* = enum
    clipContent
    disableRender
    scrollpane

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

    case kind*: NodeKind
    of nkImage:
      image*: ImageStyle
    of nkText:
      textStyle*: TextStyle
      when not defined(js):
        textLayout*: seq[GlyphPosition]
      else:
        element*: Element
        textElement*: Element
        cache*: Node
    of nkDrawable:
      points*: seq[Position]
    else:
      discard

proc newUId*(): NodeUID =
  # Returns next numerical unique id.
  inc lastUId
  when defined(js) or defined(StringUID):
    $lastUId
  else:
    NodeUID(lastUId)

