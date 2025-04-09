import ../widget

type Vertical* = ref object of Figuro

template usingVerticalLayout*(justify = CxCenter, align = CxCenter) =
  with this:
    setGridCols 1'fr
    gridAutoFlow grRow
    justifyItems justify
    alignItems align

proc contentHeight*(current: Figuro, cx: Constraint, gap = -1'ui) {.thisWrapper.} =
  current.gridAutoRows cx
  if gap != -1'ui:
    current.gridRowGap gap

template usingVerticalLayout*(cx: Constraint, gap = -1'ui) =
  usingVerticalLayout()
  contentHeight(this, cx, gap)

proc draw*(self: Vertical) {.slot.} =
  ## button widget!
  withWidget(self):
    usingVerticalLayout()
    WidgetContents()

type VerticalFilled* = ref object of Figuro

proc draw*(self: VerticalFilled) {.slot.} =
  withWidget(self):
    usingVerticalLayout(CxStretch, CxStretch)
    WidgetContents()