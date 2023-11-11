
import commons
import ../ui/utils
import ../widget
export widget

type
  Vertical* = ref object of Figuro

proc itemHeight*(current: Vertical, cx: Constraint, gap = -1'ui) =
  current.gridAutoRows cx
  if gap != -1'ui:
    current.rowGap gap

proc draw*(self: Vertical) {.slot.} =
  ## button widget!
  nodes(self):
    with current:
      setGridCols 1'fr
      gridAutoFlow grRow
      justifyItems CxCenter
      alignItems CxStart
    optionally:
      gridAutoRows 1'fr

exportWidget(vertical, Vertical)
