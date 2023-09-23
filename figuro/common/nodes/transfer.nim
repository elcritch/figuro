
import ui as ui
import render as render
import ../../shared

type
  RenderList* = object
    nodes*: seq[Node]
    rootIds*: seq[NodeIdx]
  RenderNodes* = OrderedTable[ZLevel, RenderList]

proc add*(list: var RenderList, node: Node) =
  ## Adds a Node to the RenderList and possibly
  ## to the roots seq if it's a root node.
  ##
  ## New roots occur when nodes have different
  ## zlevels and end up in a the RenderList
  ## for that ZLevel without their logical parent. 
  ##
  if list.rootIds.len() == 0:
    list.rootIds.add(list.nodes.len().NodeIdx)
  else:
    let lastRoot = list.nodes[list.rootIds[^1].int]
    if node.parent != lastRoot.uid and
        node.parent != list.nodes[^1].uid:
      list.rootIds.add(list.nodes.len().NodeIdx)
  list.nodes.add(node)

proc convert*(current: Figuro): render.Node =
  result = Node(kind: current.kind)

  result.uid = current.uid
  result.name = current.name

  result.box = current.box.scaled
  result.orgBox = current.orgBox.scaled
  result.screenBox = current.screenBox.scaled
  result.offset = current.offset.scaled
  result.totalOffset = current.totalOffset.scaled
  result.attrs = current.attrs

  result.zlevel = current.zlevel
  result.rotation = current.rotation
  result.fill = current.fill
  result.highlight = current.highlight
  result.transparency = current.transparency
  result.stroke = current.stroke

  case current.kind:
  of nkRectangle:
    if current.shadow.isSome:
      let orig = current.shadow.get()
      var shadow: RenderShadow
      shadow.kind = orig.kind
      shadow.blur = orig.blur.scaled
      shadow.x = orig.x.scaled
      shadow.y = orig.y.scaled
      shadow.color = orig.color
      result.shadow = some shadow
    result.cornerRadius = current.cornerRadius.scaled
  of nkImage:
    result.image = current.image
  of nkText:
    result.textLayout = current.textLayout
  of nkDrawable:
    result.points = current.points.mapIt(it.scaled)
  else:
    discard

proc convert*(renders: var RenderNodes,
              current: Figuro,
              parent: NodeID,
              maxzlvl: ZLevel
              ) =
  # echo "convert:node: ", current.uid, " parent: ", parent
  var render = current.convert()
  render.parent = parent
  render.childCount = current.children.len()
  let zlvl = current.zlevel

  for child in current.children:
    let chlvl = child.zlevel
    if chlvl != zlvl:
      render.childCount.dec()

  renders.mgetOrPut(zlvl, RenderList()).add(render)
  for child in current.children:
    let chlvl = child.zlevel
    renders.convert(child, current.uid, chlvl)

type
  RenderTree* = ref object
    name*: string
    children*: seq[RenderTree]

func `[]`*(a: RenderTree, idx: int): RenderTree =
  if a.children.len() == 0:
    return RenderTree(name: "Missing")
  a.children[idx]

func `==`*(a, b: RenderTree): bool =
  if a.isNil and b.isNil: return true
  if a.isNil or b.isNil: return false
  `==`(a[], b[])

proc toTree*(nodes: seq[Node],
              idx = 0.NodeIdx,
              depth = 1): RenderTree =
  let n = nodes[idx.int]
  result = RenderTree(name: $n.name)
  # echo "  ".repeat(depth), "toTree:idx: ", idx.int
  for ci in nodes.childIndex(idx):
    # echo "  ".repeat(depth), "toTree:cidx: ", ci.int
    result.children.add toTree(nodes, ci, depth+1)

proc toTree*(list: RenderList): RenderTree =
  result = RenderTree(name: "pseudoRoot")
  for rootIdx in list.rootIds:
    # echo "toTree:rootIdx: ", rootIdx.int
    result.children.add toTree(list.nodes, rootIdx)


proc copyInto*(uis: Figuro): RenderNodes =
  result = initOrderedTable[ZLevel, RenderList]()
  result.convert(uis, -1.NodeID, 0.ZLevel)

  result.sort(proc(x, y: auto): int = cmp(x[0],y[0]))
  # echo "nodes:len: ", result.len()
  # printRenders(result)
