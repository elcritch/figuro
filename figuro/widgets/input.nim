import std/unicode

import commons
import ../ui/utils

type
  Input* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    text*: string

proc clicked*(self: Input,
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo nd(), "input:clicked: ", buttons,
              " kind: ", kind, " :: ", self.getId

  self.isActive = kind == Enter
  if self.isActive:
    self.listens.signals.incl {evKeyboardInput}
  else:
    self.listens.signals.excl {evKeyboardInput}
  refresh(self)

proc keyInput*(self: Input,
                rune: Rune) {.slot.} =
  echo nd(), "Input:rune: ", $rune, " :: ", self.getId

  if not self.isActive:
    refresh(self)
  self.isActive = true

proc draw*(self: Input) {.slot.} =
  ## Input widget!
  withDraw(self):
    
    clipContent true
    cornerRadius 10.0

    # text "text":
    #   box 10, 10, 400, 100
    #   fill blackColor
    #   setText({font: "hello world!\n"})

    if self.disabled:
      fill "#F0F0F0"
    else:
      fill "#2B9FEA"
      if self.isActive:
        fill current.fill.spin(15)
        # this changes the color on hover!

exportWidget(input, Input)
