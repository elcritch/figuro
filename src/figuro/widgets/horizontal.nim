import pkg/chronicles
import ../widget

type
  Horizontal* = ref object of Figuro
  HorizontalFilled* = ref object of Horizontal

template usingHorizontalLayout*(justify = CxCenter, align = CxCenter) =
  with this:
    setGridRows 1'fr
    gridAutoFlow grColumn
    justifyItems justify
    alignItems align

proc contentWidth*(node: Figuro, cx: Constraint, gap = -1'ui) {.thisWrapper.} =
  node.gridAutoColumns cx
  if gap != -1'ui:
    node.gridColumnGap gap

template usingHorizontalLayout*(cx: Constraint, gap = -1'ui) =
  usingHorizontalLayout()
  contentWidth(this, cx, gap)

proc draw*(self: Horizontal) {.slot.} =
  ## button widget!
  withWidget(self):
    Rectangle.new "bg":
      usingHorizontalLayout()
      WidgetContents()

proc draw*(self: HorizontalFilled) {.slot.} =
  withWidget(self):
    Rectangle.new "bg":
      usingHorizontalLayout(CxStretch, CxStretch)
      WidgetContents()
