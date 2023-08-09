
import commons

type
  Button* = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool

template button*(blk: untyped) =
  # nodes.add Button()
  discard

method render*(self: Button) =
  # button widget!
  # onTheme 
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
    if self.isActive:
      fill "#00CC00"
    onHover:
      fill "#00FF00"
    onClick:
      fill "#00FFFF"
