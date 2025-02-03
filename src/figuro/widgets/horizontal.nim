import ../widget

type Horizontal* = ref object of Figuro

template usingHorizontalLayout*() =
  with node:
    setGridRows 1'fr
    gridAutoFlow grColumn
    justifyItems CxCenter
    alignItems CxCenter

template usingHorizontalLayout*(cx: Constraint, gap = -1'ui) =
  usingHorizontalLayout()
  node.gridAutoColumns cx
  if gap != -1'ui:
    node.columnGap gap

proc itemWidth*(node: Figuro, cx: Constraint, gap = -1'ui) =
  node.gridAutoColumns cx
  if gap != -1'ui:
    node.columnGap gap

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  withWidget(self):
    usingHorizontalLayout()
    WidgetContents()

# exportWidget(horizontal, Horizontal)
