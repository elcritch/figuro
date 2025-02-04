import ../widget

type Horizontal* = ref object of Figuro

template usingHorizontalLayout*() =
  with this:
    setGridRows 1'fr
    gridAutoFlow grColumn
    justifyItems CxCenter
    alignItems CxCenter

proc contentWidth*(node: Figuro, cx: Constraint, gap = -1'ui) =
  node.gridAutoColumns cx
  if gap != -1'ui:
    node.gridColumnGap gap

template usingHorizontalLayout*(cx: Constraint, gap = -1'ui) =
  usingHorizontalLayout()
  contentWidth(this, cx, gap)

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  withWidget(self):
    usingHorizontalLayout()
    WidgetContents()

# exportWidget(horizontal, Horizontal)
