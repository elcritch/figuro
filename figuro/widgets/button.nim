
import commons

type
  Button* = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool

proc hover*(self: Button) {.slot.} =
  self.fill = parseHtmlColor "#9BDFFA"
  echo "button hover!"
  self.fill = "#2B9FEA".parseHtmlColor.lighten(0.2)

proc draw*(self: Button) {.slot.} =
  ## button widget!
  
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
    onHover:
      # fill "#2B9FEA".parseHtmlColor.lighten(0.2)
      discard
    # onClick:
    #   fill "#00FFFF"

template button*(id: string, blk: untyped) =
  preNode(nkRectangle, Button, id)
  connect(current, eventHover, current, Button.hover)
  `blk`
  postNode()
