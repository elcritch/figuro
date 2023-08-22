
import commons

type
  Button* = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool

proc hover*(self: Button, kind: EventKind) {.slot.} =
  # self.fill = parseHtmlColor "#9BDFFA"
  # echo "button hover!"
  echo "child hovered: ", kind
  discard

proc draw*(self: Button) {.slot.} =
  ## button widget!
  current = self
  
  clipContent true
  echo "draw:button: ", self.uid, " :: ", self.events.mouse

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
    onHover:
      # echo "hover!"
      echo "draw:button:onHover: ", self.uid
      fill "#2B9FEA".parseHtmlColor.lighten(0.3)
    onClick:
      echo "click! ", self.uid
    # onClick:
    #   fill "#00FFFF"

template button*(id: string, blk: untyped) =
  preNode(nkRectangle, Button, id)
  connect(current, onHover, current, Button.hover)
  `blk`
  postNode()
