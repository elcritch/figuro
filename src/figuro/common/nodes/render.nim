import std/tables
export tables
import pkg/stack_strings
import basics
import hashes

export basics

type
  RenderList* = object
    nodes*: seq[Node]
    rootIds*: seq[NodeIdx]

  Renders* = ref object
    layers*: OrderedTable[ZLevel, RenderList]

  NodeIdx* = distinct int

  Node* = object
    uid*: NodeID
    name*: StackString[16]

    childCount*: int
    parent*: NodeID

    box*: Rect
    orgBox*: Rect
    screenBox*: Rect
    offset*: Vec2
    totalOffset*: Vec2
    scroll*: Vec2
    attrs*: set[Attributes]

    zlevel*: ZLevel
    rotation*: float32
    fill*: Color
    highlight*: Color
    transparency*: float32
    stroke*: Stroke

    case kind*: NodeKind
    of nkRectangle:
      shadow*: array[ShadowStyle, RenderShadow]
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

proc `$`*(id: NodeIdx): string =
  "NodeIdx(" & $(int(id)) & ")"

proc `+`*(a, b: NodeIdx): NodeIdx {.borrow.}
proc `<=`*(a, b: NodeIdx): bool {.borrow.}
proc `==`*(a, b: NodeIdx): bool {.borrow.}

proc `[]`*(r: Renders, lvl: ZLevel): RenderList =
  r.layers[lvl]

template pairs*(r: Renders): auto =
  r.layers.pairs()
template contains*(r: Renders, lvl: ZLevel): bool =
  r.layers.contains(lvl)

iterator childIndex*(nodes: seq[Node], current: NodeIdx): NodeIdx =
  let id = nodes[current.int].uid
  let childCnt = nodes[current.int].childCount
  # print "\nchildIndex: ", current,
  #           "childCnt: ", nodes[current.int].childCount,
  #           "id: ", id.int

  var idx = current.int
  var cnt = 0
  while cnt < childCnt:
    # print "childNodes: ", nodes[idx].uid,
    #         "#cnt:", nodes[idx].childCount,
    #         "idx:", idx.int,
    #         "myPnt:", nodes[idx.int].parent,
    #         "pnt:", id.int
    if nodes[idx.int].parent == id:
      cnt.inc()
      yield idx.NodeIdx
    idx.inc()
