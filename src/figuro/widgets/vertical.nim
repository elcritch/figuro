import ../widget

type Vertical* = ref object of Figuro

proc itemHeight*(current: Vertical, cx: Constraint, gap = -1'ui) =
  current.gridAutoRows cx
  if gap != -1'ui:
    current.rowGap gap

proc draw*(self: Vertical) {.slot.} =
  ## button widget!
  withWidget(self):
    with node:
      setGridCols 1'fr
      gridAutoFlow grRow
      justifyItems CxCenter
      alignItems CxCenter
    withOptional self:
      gridAutoRows 1'fr
    WidgetContents()

