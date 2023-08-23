
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
    result.textLayout
    # result.textStyle = current.textStyle
    # result.textLayout = current.textLayout
    discard
  of nkDrawable:
    result.points = current.points.mapIt(it.scaled)
  else:
    discard

proc convert*(renders: var seq[render.Node], current: Figuro, parent: NodeID) =
  # echo "convert:node: ", current.uid, " parent: ", parent
  var render = current.convert()
  render.parent = parent
  render.childCount = current.children.len()

  renders.add(move render)
  for child in current.children:
    renders.convert(child, current.uid)

proc copyInto*(uiNodes: Figuro): seq[render.Node] =
  result = newSeq[render.Node]()
  convert(result, uiNodes, -1.NodeID)
  # echo "nodes:len: ", result.len()
