import ../widget

type Horizontal* = ref object of Figuro

template usingHorizontalLayout*() =
  with node:
    setGridRows 1'fr
    gridAutoFlow grColumn
    justifyItems CxCenter
    alignItems CxCenter

proc contentWidth*(node: Figuro, cx: Constraint, gap = -1'ui) =
  node.gridAutoColumns cx
  if gap != -1'ui:
    node.columnGap gap

template usingHorizontalLayout*(cx: Constraint, gap = -1'ui) =
  usingHorizontalLayout()
  contentWidth(node, cs, gap)

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  withWidget(self):
    usingHorizontalLayout()
    WidgetContents()

# exportWidget(horizontal, Horizontal)
