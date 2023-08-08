
import commons

type
  Button* = ref object of Figuro
    label: string
    isActive: bool
    disabled: bool

method render*(self: Button) =
  # button widget!
  # onTheme 
  # clipContent true

  # if self.label.len() > 0:
  #   text "text":
  #     # boxSizeOf parent
  #     size csAuto(), csAuto()
  #     fill theme.text
  #     characters props.label

  if self.disabled:
    current.fill = "#FF0000".parseHtmlColor
    # useTheme atom"disabled"
  else:
    current.fill = "#00FF00".parseHtmlColor
    # if self.isActive:
    #   useTheme atom"active"
    # onHover:
    #   useTheme atom"hover"
    # onClick:
    #   useTheme atom"active"
    # dispatchMouseEvents()