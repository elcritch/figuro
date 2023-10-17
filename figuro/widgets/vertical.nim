
import commons
import ../ui/utils

type
  Vertical* = ref object of Figuro

proc draw*[T](self: Vertical) {.slot.} =
  ## button widget!
  withDraw(self):
    setGridCols 1'fr
    setGridRows 60'ux
    gridAutoRows 60'ux
    gridAutoFlow grRow
    justifyItems CxCenter
    alignItems CxStart
    TemplateContents(self)

exportWidget(vertical, Vertical)
