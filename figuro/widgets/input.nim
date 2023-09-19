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
    value: int
    cnt: int

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22'ui)
  smallFont = UiFont(typefaceId: typeface, size: 12'ui)

proc tick*(self: Input) {.slot.} =
  if self.isActive:
    # self.value = 0.004 * (1+app.tickCount).toFloat
    # self.value = clamp(self.value mod 1.0, 0, 1.0)
    self.cnt.inc()
    self.cnt = self.cnt mod 47
    if self.cnt == 0:
      self.value = (self.value + 1) mod 2
      refresh(self)

proc clicked*(self: Input,
              kind: EventKind,
              buttons: UiButtonView) {.slot.} =
  echo "input:clicked: ", buttons,
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
  echo "Input:keyPress: ", " pressed: ", $pressed, " down: ", $down, " :: ", self.getId
  if pressed == {KeyBackspace} and self.selection != -1 .. -1:
    self.text.delete(self.selection)
    self.selection = self.text.len() - 1 .. self.text.len() - 1
  refresh(self)

proc draw*(self: Input) {.slot.} =
  ## Input widget!
  withDraw(self):
    
    clipContent true
    cornerRadius 10.0
    connect(findRoot(self), doTick, self, Input.tick())

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
        let fs = font.size.scaled
        var sr = self.layout.selectionRects[self.selection.b]
        sr.x = sr.x + 1.0*sr.w + 0.5*fs
        sr.y = sr.y + 0.25*fs
        sr.w = 0.1*fs * 0.75
        box sr.descaled()
        # box 0, 0, font.size*0.04, font.size
        fill blackColor
        # echo "value: ", self.value
        current.fill.a = self.value.toFloat * 1.0

    if self.disabled:
      fill whiteColor.darken(0.4)
    else:
      fill whiteColor.darken(0.2)
      if self.isActive:
        fill current.fill.lighten(0.15)
        # this changes the color on hover!

exportWidget(input, Input)
