
import commons
import ../ui/utils
import ../widget
export widget

type
  Horizontal* = ref object of Figuro

template itemWidth*(cx: Constraint) =
  when current isnot Horizontal:
    {.error: "height template must be used in a vertical widget".}
  gridAutoColumns cx

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  withDraw(self):
    setGridRows 1'fr
    gridAutoFlow grColumn
    justifyItems CxCenter
    alignItems CxCenter

exportWidget(horizontal, Horizontal)
