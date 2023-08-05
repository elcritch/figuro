
import ui as ui
import render as render

proc convert*(current: ui.Node): render.Node =
  result = render.Node(kind: current.kind)

  result.uid = current.uid

  result.box = current.box
  result.orgBox = current.orgBox
  result.screenBox = current.screenBox
  result.offset = current.offset
  result.totalOffset = current.totalOffset
  result.attrs = current.attrs

  result.zlevel = current.zlevel
  result.rotation = current.rotation
  result.fill = current.fill
  result.highlight = current.highlight
  result.transparency = current.transparency
  result.stroke = current.stroke

  case current.kind:
  of nkRectangle:
    result.shadow = current.shadow
    result.cornerRadius = current.cornerRadius 
  of nkImage:
    result.image = current.image
  of nkText:
    result.textStyle = current.textStyle
    result.textLayout = current.textLayout
  of nkDrawable:
    result.points = current.points
  else:
    discard

proc convert*(renders: var seq[render.Node], current: ui.Node, parent: NodeID) =
  # echo "convert:node: ", current.uid, " parent: ", parent
  var render = current.convert()
  render.parent = parent
  render.childCount = current.nodes.len()

  renders.add(move render)
  for child in current.nodes:
    renders.convert(child, current.uid)

proc copyInto*(uiNodes: ui.Node): seq[render.Node] =
  result = newSeq[render.Node]()
  convert(result, uiNodes, -1.NodeID)
  # echo "nodes:len: ", result.len()
