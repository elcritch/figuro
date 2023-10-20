
import commons
import ../ui/utils
import ../widget
export widget

type
  Vertical* = ref object of Figuro

template itemHeight*(cx: Constraint) =
  when current isnot Vertical:
    {.error: "height template must be used in a vertical widget".}
  gridAutoRows cx

proc draw*(self: Vertical) {.slot.} =
  ## button widget!
  withDraw(self):
    setGridCols 1'fr
    # setGridRows 90'ux
    # gridAutoRows 1'fr
    gridAutoFlow grRow
    justifyItems CxCenter
    alignItems CxStart
    # TemplateContents(self)

exportWidget(vertical, Vertical)
