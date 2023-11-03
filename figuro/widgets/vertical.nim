
import commons
import ../ui/utils
import ../widget
export widget

type
  Vertical* = ref object of Figuro

template itemHeight*(cx: Constraint, gap = -1'ui) =
  when current isnot Vertical:
    {.error: "height template must be used in a vertical widget".}
  gridAutoRows cx
  if gap != -1'ui:
    rowGap gap

proc draw*(self: Vertical) {.slot.} =
  ## button widget!
  withDraw(self):
    setGridCols 1'fr
    gridAutoFlow grRow
    justifyItems CxCenter
    alignItems CxStart
    optionals:
      gridAutoRows 1'fr

exportWidget(vertical, Vertical)
