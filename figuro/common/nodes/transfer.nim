
import ui as ui
import render as render
import ../../shared

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

proc convert*(renders: var OrderedTable[ZLevel, seq[Node]],
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

  renders.mgetOrPut(zlvl, @[]).add(render)
  for child in current.children:
    let chlvl = child.zlevel
    renders.convert(child, current.uid, chlvl)

type
  Renders* = ref object
    node*: NodeID
    name*: string
    children*: seq[Renders]

proc lispRepr*(nodes: seq[Node], idx = 0.NodeIdx): Renders =
  let n = nodes[idx.int]
  result = Renders(node: n.uid, name: $n.name)
  for ci in nodes.childIndex(idx):
    result.children.add lispRepr(nodes, ci)

proc printRenders*(nodes: seq[Node],
                    idx = 0.NodeIdx, depth = 1) =
  let n = nodes[idx.int]
  echo "  ".repeat(depth), "render: ", n.uid,
          " p: ", n.parent,
          " name: ", $n.name,
          " zlvl: ", $n.zlevel
  for ci in nodes.childIndex(idx):
    printRenders(nodes, ci, depth+1)

proc printRenders*(n: OrderedTable[ZLevel, seq[Node]]) =
  echo "\nprint renders: "
  for k, v in n.pairs:
    echo "K: ", k
    printRenders(v, 0.NodeIdx)

proc copyInto*(uis: Figuro): OrderedTable[ZLevel, seq[Node]] =
  result = initOrderedTable[ZLevel, seq[render.Node]]()
  result.convert(uis, -1.NodeID, 0.ZLevel)

  result.sort(proc(x, y: (ZLevel, seq[Node])): int = cmp(x[0],y[0]))
  # echo "nodes:len: ", result.len()
  # printRenders(result)
