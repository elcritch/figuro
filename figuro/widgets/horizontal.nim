
import commons
import ../ui/utils
import ../widget
export widget

type
  Horizontal* = ref object of Figuro

template itemWidth*(cx: Constraint, gap = -1'ui) =
  when current isnot Horizontal:
    {.error: "height template must be used in a vertical widget".}
  gridAutoColumns cx
  if gap != -1'ui:
    columnGap gap

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  withDraw(self):
    setGridRows 1'fr
    gridAutoFlow grColumn
    justifyItems CxCenter
    alignItems CxCenter

exportWidget(horizontal, Horizontal)
