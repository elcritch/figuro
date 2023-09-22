import std/unicode

import commons
import ../ui/utils

type
  Input* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    selection*: Slice[int]
    layout*: GlyphArrangement
    textNode*: Figuro
    value: int
    cnt: int

template aa(): int = self.selection.a
template bb(): int = self.selection.b
template ll(): int = self.layout.runes.len() - 1

proc updateLayout*(self: Input, text = seq[Rune].none) =
  let runes =
    if text.isSome: text.get()
    else: self.layout.runes
  let spans = {self.theme.font: $runes, self.theme.font: "*"}
  self.layout = internal.getTypeset(self.box, spans)
  self.layout.runes.setLen(ll())

proc findPrevWord*(self: Input): int =
  result = -1
  for i in countdown(max(0,aa-2), 0):
    if self.layout.runes[i].isWhiteSpace():
      return i

proc findNextWord*(self: Input): int =
  result = self.layout.runes.len()
  for i in countup(aa+1, self.layout.runes.len()-1):
    if self.layout.runes[i].isWhiteSpace():
      return i

proc tick*(self: Input) {.slot.} =
  if self.isActive:
    self.cnt.inc()
    self.cnt = self.cnt mod 47
    if self.cnt == 0:
      self.value = (self.value + 1) mod 2
      refresh(self)

proc clicked*(self: Input,
              kind: EventKind,
              buttons: UiButtonView) {.slot.} =
  self.isActive = kind == Enter
  if self.isActive:
    self.listens.signals.incl {evKeyboardInput, evKeyPress}
  else:
    self.listens.signals.excl {evKeyboardInput, evKeyPress}
    self.value = 0
  refresh(self)

proc keyInput*(self: Input,
               rune: Rune) {.slot.} =
  self.layout.runes.insert(rune, max(aa, 0))
  self.updateLayout()
  self.selection = aa+1 .. bb+1
  refresh(self)

proc keyPress*(self: Input,
               pressed: UiButtonView,
               down: UiButtonView) {.slot.} =
  echo "\nInput:keyPress: ",
            " pressed: ", $pressed,
            " down: ", $down, " :: ", self.selection
  if down == KNone:
    if pressed == {KeyBackspace} and self.selection.b > 0:
      self.selection = max(aa-1, 0)..max(bb-1, 0)
      self.layout.runes.delete(self.selection)
      self.updateLayout()
    elif pressed == {KeyLeft}:
      self.selection = max(aa-1, 0)..max(bb-1, 0)
    elif pressed == {KeyRight}:
      self.selection = min(aa+1, ll+1)..min(bb+1, ll+1)
    elif pressed == {KeyEscape}:
      self.clicked(Exit, {})
  elif down == KCadet:
    if pressed == {KeyA}:
      echo "select all"
  elif down == KControl:
    if pressed == {KeyLeft}:
      self.selection = 0..0
    elif pressed == {KeyRight}:
      self.selection = ll+1..ll+1
  elif down == KAlt:
    if pressed == {KeyLeft}:
      let idx = findPrevWord(self)
      self.selection = idx+1..idx+1
    elif pressed == {KeyRight}:
      let idx = findNextWord(self)
      self.selection = idx..idx
    elif pressed == {KeyBackspace}:
      let idx = findPrevWord(self)
      self.layout.runes.delete(idx+1..aa-1)
      self.selection = idx+1..idx+1
      self.updateLayout()
  refresh(self)

proc draw*(self: Input) {.slot.} =
  ## Input widget!
  if self.layout.isNil:
    self.layout = GlyphArrangement()

  withDraw(self):

    clipContent true
    cornerRadius 10.0
    connect(findRoot(self), doTick, self, Input.tick())

    text "text":
      box 10, 10, 400, 100
      fill blackColor
      self.textNode = current
      current.textLayout = self.layout

      rectangle "cursor":
        let sz = 0..self.layout.selectionRects.high()
        if self.selection.a in sz and self.selection.b in sz: 
          let fs = self.theme.font.size.scaled
          var sr = self.layout.selectionRects[self.selection.b]
          ## this is gross but works for now
          let width = max(0.08*fs, 2.0)
          sr.x = sr.x - width/2.0
          sr.y = sr.y - 0.04*fs
          sr.w = width
          sr.h = 0.9*fs
          box sr.descaled()
          fill blackColor
          current.fill.a = self.value.toFloat * 1.0

    if self.disabled:
      fill whiteColor.darken(0.4)
    else:
      fill whiteColor.darken(0.2)
      if self.isActive:
        fill current.fill.lighten(0.15)
        # this changes the color on hover!

exportWidget(input, Input)
