import uinodes as ui
import render as render
import ../shared

type RenderTree* = ref object
  id*: int
  name*: string
  children*: seq[RenderTree]

func `[]`*(a: RenderTree, idx: int): RenderTree =
  if a.children.len() == 0:
    return RenderTree(name: "Missing")
  a.children[idx]

func `==`*(a, b: RenderTree): bool =
  if a.isNil and b.isNil:
    return true
  if a.isNil or b.isNil:
    return false
  `==`(a[], b[])

proc toTree*(nodes: seq[Node], idx = 0.NodeIdx, depth = 1): RenderTree =
  let n = nodes[idx.int]
  result = RenderTree(id: n.uid, name: $n.name)
  # echo "  ".repeat(depth), "toTree:idx: ", idx.int
  for ci in nodes.childIndex(idx):
    # echo "  ".repeat(depth), "toTree:cidx: ", ci.int
    result.children.add toTree(nodes, ci, depth + 1)

proc toTree*(list: RenderList): RenderTree =
  result = RenderTree(name: "pseudoRoot")
  for rootIdx in list.rootIds:
    # echo "toTree:rootIdx: ", rootIdx.int
    result.children.add toTree(list.nodes, rootIdx)

proc findRoot*(list: RenderList, node: Node): Node =
  result = node
  var cnt = 0
  # print "FIND ROOT: list: ", list
  var curr = result
  while result.parent != -1.NodeID and result.uid != result.parent:
    # echo "FIND ROOT: ", result.uid, " ", result.parent, " -> ", repr list.nodes.mapIt(it.uid.int)
    var curr = result
    for n in list.nodes:
      if n.uid == result.parent:
        result = n
        break

    if curr.uid == result.uid:
      return

    cnt.inc
    if cnt > 1_00:
      raise newException(IndexDefect, "error finding root")

proc add*(list: var RenderList, node: Node) =
  ## Adds a Node to the RenderList and possibly
  ## to the roots seq if it's a root node.
  ##
  ## New roots occur when nodes have different
  ## zlevels and end up in a the RenderList
  ## for that ZLevel without their logical parent. 
  ##
  # echo ""
  if list.rootIds.len() == 0:
    # echo "rootIds: len == 0"
    list.rootIds.add(list.nodes.len().NodeIdx)
  elif node.parent == -1:
    list.rootIds.add(list.nodes.len().NodeIdx)
  else:
    let lastRoot = list.nodes[list.rootIds[^1].int]
    # echo "rootIds:lastRoot: ", lastRoot.uid, " `", lastRoot.name,
    #         "` node: ", node.uid, " `", node.name, "` "
    # echo " nodeRoot: ", findRoot(list, node).uid
    let nr = findRoot(list, node)
    if nr.uid != lastRoot.uid and node.uid != list.nodes[^1].uid:
      # echo "rootIds:add: ", node.uid, " // ", node.parent, " ", node.name
      list.rootIds.add(list.nodes.len().NodeIdx)
  list.nodes.add(node)

proc toRenderNode*(current: Figuro): render.Node =
  result = Node(kind: current.kind)

  result.uid = current.uid
  result.name.setLen(0)
  discard result.name.tryAdd(current.name)

  result.box = current.box.scaled
  result.screenBox = current.screenBox.scaled
  result.offset = current.offset.scaled
  result.totalOffset = current.totalOffset.scaled
  result.scroll = current.scroll.scaled
  result.flags = current.flags

  result.zlevel = current.zlevel
  result.rotation = current.rotation
  result.fill = current.fill
  result.highlight = current.highlight
  result.stroke = current.stroke

  result.image = current.image.id

  case current.kind
  of nkRectangle:
    block:
      let orig = current.shadow[DropShadow]
      var shadow: RenderShadow
      shadow.blur = orig.blur.scaled
      shadow.x = orig.x.scaled
      shadow.y = orig.y.scaled
      shadow.color = orig.color
      result.shadow[DropShadow] = shadow
    block:
      let orig = current.shadow[InnerShadow]
      var shadow: RenderShadow
      shadow.blur = orig.blur.scaled
      shadow.x = orig.x.scaled
      shadow.y = orig.y.scaled
      shadow.color = orig.color
      result.shadow[InnerShadow] = shadow
    result.cornerRadius = current.cornerRadius.scaled
  # of nkImage:
  #   result.image = current.image
  of nkText:
    result.textLayout = current.textLayout
    # result.textLayout = GlyphArrangement()
    # for n, f1, f2 in fieldPairs(result.textLayout[], current.textLayout[]):
    #   f1 = f2
  of nkDrawable:
    result.points = current.points.mapIt(it.scaled)
  else:
    discard

proc convert*(
    renders: var Renders, current: Figuro, parent: NodeID, maxzlvl: ZLevel
) =
  # echo "convert:node: ", current.uid, " parent: ", parent
  var render = current.toRenderNode()
  render.parent = parent
  render.childCount = current.children.len()
  let zlvl = current.zlevel

  for child in current.children:
    let chlvl = child.zlevel
    if chlvl != zlvl or
      NfInactive in child.flags or
      NfDead in child.flags or
      Hidden in child.userAttrs:
      render.childCount.dec()

  renders.layers.mgetOrPut(zlvl, RenderList()).add(render)
  for child in current.children:
    let chlvl = child.zlevel
    if NfInactive notin child.flags and
        NfDead notin child.flags and
        Hidden notin child.userAttrs:
      renders.convert(child, current.uid, chlvl)

proc copyInto*(uis: Figuro): Renders =
  result = Renders()
  result.layers = initOrderedTable[ZLevel, RenderList]()
  result.convert(uis, -1.NodeID, 0.ZLevel)

  result.layers.sort(
    proc(x, y: auto): int =
      cmp(x[0], y[0])
  )
  # echo "nodes:len: ", result.len()
  # printRenders(result)
