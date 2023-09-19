import std/unicode

import commons
import ../ui/utils

type
  Input* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    selection*: Slice[int]
    text*: string
    layout*: GlyphArrangement

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
  # echo nd(), "Input:rune: ", $rune, " :: ", self.getId
  self.selection = self.text.len() .. self.text.len()
  self.text.add($rune)
  refresh(self)

proc keyPress*(self: Input,
               pressed: UiButtonView,
               down: UiButtonView) {.slot.} =
  echo nd(), "Input:keyPress: ", " pressed: ", $pressed, " down: ", $down, " :: ", self.getId
  if pressed == {KeyBackspace} and self.selection != -1 .. -1:
    self.text.delete(self.selection)
    self.selection = self.text.len() - 1 .. self.text.len() - 1
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
      self.layout = current.textLayout

      rectangle "cursor":
        # echo "cursor: ", self.selection
        # echo "cursor: ", current.parent.textLayout.repr
        let sz = 0..self.layout.selectionRects.high()
        if self.selection.a in sz and self.selection.b in sz: 
          var sr = self.layout.selectionRects[self.selection.b]
          sr.x = sr.x + sr.w
          sr.y = sr.y - 0.25 * font.size.scaled
          sr.w = 0.1 * font.size.scaled * 0.7
          box sr.descaled()
          # box 0, 0, font.size*0.04, font.size
          fill blackColor

    if self.disabled:
      fill "#F0F0F0"
    else:
      fill "#2B9FEA"
      if self.isActive:
        fill current.fill.spin(15)
        # this changes the color on hover!

exportWidget(input, Input)
