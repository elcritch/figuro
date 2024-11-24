
import commons
import ../widget
export widget

type
  Rectangle* = ref object of Figuro

proc draw*(self: Rectangle) {.slot.} =
  ## button widget!
  discard

exportWidget(basicRectangles, Rectangle)
