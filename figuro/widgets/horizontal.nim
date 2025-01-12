import commons
import ../ui/utils
import ../widget
export widget

type Horizontal* = ref object of Figuro

proc itemWidth*(node: Horizontal, cx: Constraint, gap = -1'ui) =
  node.gridAutoColumns cx
  if gap != -1'ui:
    node.columnGap gap

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  with self:
    setGridRows 1'fr
    gridAutoFlow grColumn
    justifyItems CxCenter
    alignItems CxCenter

exportWidget(horizontal, Horizontal)
