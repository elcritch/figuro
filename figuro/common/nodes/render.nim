import basics

export basics

type

  NodeIdx* = distinct int

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
      textLayout*: GlyphArrangement
    of nkDrawable:
      points*: seq[Vec2]
    else:
      discard

import pretty

proc `$`*(id: NodeIdx): string = "NodeIdx(" & $id & ")"
proc `+`*(a, b: NodeIdx): NodeIdx {.borrow.}

import std/sequtils

proc childIndex*(nodes: seq[Node], current: NodeIdx): seq[NodeIdx] =
  print "\nchildIndex: ", current, "childCnt: ", nodes[current.int].childCount, " nodes: ", nodes.mapIt(it.uid)
  let id = nodes[current.int].uid
  let cnt = nodes[current.int].childCount

  var idx = current.int + 1
  while result.len() < cnt:
    print "childNodes: ", current, "(" & $nodes[idx].childCount & ")", idx, "parent:", id
    if nodes[idx.int].parent == id:
      result.add idx.NodeIdx
    idx.inc()


