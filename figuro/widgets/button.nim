
import commons

type
  Button*[T] = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool
    data: T
  

template button*[T](id: string, blk: untyped) =
  preNode(nkRectangle, Button[T], atom(id))
  `blk`
  postNode()

proc render*[T](self: Button) =
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
    fill "#2B9FEA"
    onHover:
      fill "#00FF00"
    # onClick:
    #   fill "#00FFFF"
