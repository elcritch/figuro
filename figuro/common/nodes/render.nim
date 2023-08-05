import basics

export basics

type

  NodeIdx* = int

  Node* = object
    uid*: NodeID

    childCount*: int
    parent*: NodeID

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

iterator nodes*(nodes: var seq[Node], current: NodeIdx): int =
  let id = nodes[current].uid
  let cnt = nodes[current].childCount

  var idx = current
  while idx - current < cnt:
    if nodes[idx].parent == id:
      yield idx
    idx.inc()
