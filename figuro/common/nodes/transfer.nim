
import ui as ui
import render as render
import ../../shared

proc convert*(current: Figuro): render.Node =
  result = Node(kind: current.kind)

  result.uid = current.uid

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
  let zlvl = max(current.zlevel, maxzlvl)

  renders.mgetOrPut(zlvl, @[]).add(move render)
  for child in current.children:
    let chlvl = max(child.zlevel, zlvl)
    if chlvl != zlvl:
      echo "child move: ", $render.uid, " -> ",
            $child.uid, " zlvl: ", $zlvl, " / ", $chlvl,
            " parent: ", $current.uid
      render.childCount.dec()
    renders.convert(child, current.uid, zlvl)

proc copyInto*(uiNodes: Figuro): OrderedTable[ZLevel, seq[Node]] =
  result = initOrderedTable[ZLevel, seq[render.Node]]()
  result.convert(uiNodes, -1.NodeID, 0.ZLevel)
  echo "nodes:len: ", result.len()
