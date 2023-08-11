
import commons

type
  Button* = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool

template button*(id: string, blk: untyped) =
  preNode(nkRectangle, Button, atom(id))
  `blk`
  postNode()

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
    fill "#FF0000"
  else:
    fill "#2B9FEA"
    onHover:
      fill "#00FF00"
    # onClick:
    #   fill "#00FFFF"
