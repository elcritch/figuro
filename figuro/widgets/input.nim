import std/unicode

import commons
import ../ui/utils

type
  Input* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    text*: string

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22'ui)
  smallFont = UiFont(typefaceId: typeface, size: 12'ui)

proc clicked*(self: Input,
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo nd(), "input:clicked: ", buttons,
              " kind: ", kind, " :: ", self.getId

  self.isActive = kind == Enter
  if self.isActive:
    self.listens.signals.incl {evKeyboardInput, evKeyPress}
  else:
    self.listens.signals.excl {evKeyboardInput, evKeyPress}
  refresh(self)

proc keyInput*(self: Input,
                rune: Rune) {.slot.} =
  echo nd(), "Input:rune: ", $rune, " :: ", self.getId
  self.text.add($rune)
  refresh(self)

proc keyPress*(self: Input,
               pressed: UiButtonView,
               down: UiButtonView) {.slot.} =
  echo nd(), "Input:keyPress: ", " pressed: ", $pressed, " down: ", $down, " :: ", self.getId
  # self.text.add($keys)
  refresh(self)

proc draw*(self: Input) {.slot.} =
  ## Input widget!
  withDraw(self):
    
    clipContent true
    cornerRadius 10.0

    text "text":
      box 10, 10, 400, 100
      fill blackColor
      setText({font: self.text})

    if self.disabled:
      fill "#F0F0F0"
    else:
      fill "#2B9FEA"
      if self.isActive:
        fill current.fill.spin(15)
        # this changes the color on hover!

exportWidget(input, Input)
