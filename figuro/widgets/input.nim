
import commons
import ../ui/utils

type
  Input*[T] = ref object of Figuro
    isActive*: bool
    disabled*: bool
    text*: string

proc clicked*[T](self: Input,
                  kind: EventKind,
                  Inputs: UiInputView) {.slot.} =
  echo nd(), "Input:clicked: ", Inputs,
              " kind: ", kind, " :: ", self.getId

  if not self.isActive:
    refresh(self)
  self.isActive = true

proc draw*[T](self: Input) {.slot.} =
  ## Input widget!
  withDraw(self):
    
    clipContent true
    cornerRadius 10.0

    if self.disabled:
      fill "#F0F0F0"
    else:
      fill "#2B9FEA"
      onHover:
        fill current.fill.spin(15)
        # this changes the color on hover!

exportWidget(Input, Input)
