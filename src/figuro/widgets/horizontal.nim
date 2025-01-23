import ../widget

type Horizontal* = ref object of Figuro

proc itemWidth*(node: Horizontal, cx: Constraint, gap = -1'ui) =
  node.gridAutoColumns cx
  if gap != -1'ui:
    node.columnGap gap

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  withWidget(self):
    with self:
      setGridRows 1'fr
      gridAutoFlow grColumn
      justifyItems CxCenter
      alignItems CxCenter
    WidgetContents()

# exportWidget(horizontal, Horizontal)
