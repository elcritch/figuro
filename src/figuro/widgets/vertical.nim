import pkg/chronicles
import ../widget

type
  Vertical* = ref object of Figuro

template usingVerticalLayout*() =
  with this:
    setGridCols 1'fr
    # gridAutoRows 1'fr
    gridAutoFlow grRow

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
