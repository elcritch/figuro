
import commons
import ../ui/utils
import ../widget
export widget

type
  Vertical* = ref object of Figuro

proc draw*(self: Vertical) {.slot.} =
  ## button widget!
  withDraw(self):
    setGridCols 1'fr
    # setGridRows 90'ux
    gridAutoRows 90'ux
    gridAutoFlow grRow
    justifyItems CxCenter
    alignItems CxStart
    TemplateContents(self)

exportWidget(vertical, Vertical)
