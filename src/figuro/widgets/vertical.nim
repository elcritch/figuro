import ../widget

type Vertical* = ref object of Figuro

template usingVerticalLayout*() =
  with node:
    setGridCols 1'fr
    gridAutoFlow grRow
    justifyItems CxCenter
    alignItems CxCenter
  withOptional self:
    gridAutoRows 1'fr

proc contentHeight*(current: Vertical, cx: Constraint, gap = -1'ui) =
  current.gridAutoRows cx
  if gap != -1'ui:
    current.rowGap gap

template usingVerticalLayout*(cx: Constraint, gap = -1'ui) =
  usingVerticalLayout()
  contentHeight(node, cs, gap)

proc draw*(self: Vertical) {.slot.} =
  ## button widget!
  withWidget(self):
    WidgetContents()

