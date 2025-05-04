import ../widget

type
  Horizontal* = ref object of Figuro
  HorizontalFilled* = ref object of Horizontal

template usingHorizontalLayout*() =
  with this:
    setGridRows 1'fr
    # gridAutoColumns 1'fr
    gridAutoFlow grColumn

proc contentWidth*(node: Figuro, cx: Constraint, gap = -1'ui) {.thisWrapper.} =
  node.gridAutoColumns cx
  if gap != -1'ui:
    node.gridColumnGap gap

template usingHorizontalLayout*(cx: Constraint) =
  usingHorizontalLayout()

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  withWidget(self):
      usingHorizontalLayout()
      WidgetContents()
