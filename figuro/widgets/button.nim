
import commons

type
  Button* = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool

proc hover*(self: Button) {.slot.} =
  echo "hover"
  self.fill = parseHtmlColor "#9BDFFA"

proc myDraw*(self: Button) {.slot.} =
  ## button widget!
  
  echo "button!"
  clipContent true

  # if self.label.len() > 0:
  #   text "text":
  #     # boxSizeOf parent
  #     size csAuto(), csAuto()
  #     fill theme.text
  #     characters props.label

  if self.disabled:
    fill "#F0F0F0"
  else:
    fill "#2B9FEA"
    echo "button: current.fill: ", current.uid, " :: ", current.fill
    # onHover:
    #   fill "#00FF00"
    # onClick:
    #   fill "#00FFFF"

template button*(id: string, blk: untyped) =
  preNode(nkRectangle, Button, id)
  `blk`
  parent.connect(onDraw, current, myDraw)
  echo "button: current.fill: ", current.uid, " :: ", current.fill
  postNode()
