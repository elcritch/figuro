import basics

export basics

type

  NodeIdx* = int

  Node* = object
    uid*: NodeID

    childCount*: int
    parent*: NodeID

    box*: Rect
    orgBox*: Rect
    screenBox*: Rect
    offset*: Vec2
    totalOffset*: Vec2
    attrs*: set[Attributes]

    zlevel*: ZLevel
    rotation*: float32
    fill*: Color
    highlight*: Color
    transparency*: float32
    stroke*: Stroke

    case kind*: NodeKind
    of nkRectangle:
      shadow*: Option[RenderShadow]
      cornerRadius*: float32
    of nkImage:
      image*: ImageStyle
    of nkText:
      textLayout*: seq[GlyphPosition]
    of nkDrawable:
      points*: seq[Vec2]
    else:
      discard

proc childIndex*(nodes: var seq[Node], current: NodeIdx): seq[NodeIdx] =
  let id = nodes[current].uid
  let cnt = nodes[current].childCount

  var
    idx = current + 1
  while result.len() < cnt:
    # echo "childNodes: ", idx, " parent: ", id
    if nodes[idx].parent == id:
      result.add idx
    idx.inc()


