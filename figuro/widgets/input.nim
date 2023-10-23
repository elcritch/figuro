import std/unicode

import commons
import ../ui/utils
import ../ui/textutils

type
  Input* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    text*: TextBox
    value: int
    cnt: int

proc doKeyCommand*(self: Input,
                   pressed: UiButtonView,
                   down: UiButtonView) {.signal.}

proc tick*(self: Input, tick: int, now: MonoTime) {.slot.} =
  if self.isActive:
    self.cnt.inc()
    self.cnt = self.cnt mod 33
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

proc sameSlice[T](a: T): Slice[T] = a..a # Shortcut 

proc keyInput*(self: Input,
               rune: Rune) {.slot.} =
  self.text.insert(rune)
  refresh(self)

proc getKey(p: UiButtonView): UiButton =
  for x in p:
    if x.ord in KeyRange.low.ord .. KeyRange.high.ord:
      return x

proc keyCommand*(self: Input,
                 pressed: UiButtonView,
                 down: UiButtonView) {.slot.} =
  when defined(debugEvents):
    echo "\nInput:keyPress: ",
            " pressed: ", $pressed,
            " down: ", $down, " :: ", self.selection
  if down == KNone:
    case pressed.getKey
    of KeyBackspace:
      if self.runes.len != 0 and self.selection != 0..0:
        if self.selection.a >= self.runes.len:
          discard self.runes.pop()
          self.selection = sameSlice(self.clampedLeft(-1))
        elif self.selection.len == 1:
          self.runes.delete(self.clampedLeft(-1))
          self.selection = sameSlice(self.clampedLeft(-1))
        else:
          self.runes.delete(self.deleteSelection())
          self.selection = sameSlice(self.clampedLeft())
        self.updateLayout()
    of KeyLeft:
      if self.selection.len != 1 and not self.isGrowingLeft:
        self.selection = sameSlice self.clampedRight(-1)
      else:
        self.selection = sameSlice self.clampedLeft(-1)
    of KeyRight:
      if self.selection.len != 1 and not self.isGrowingLeft:
        self.selection = sameSlice self.clampedRight(1)
      else:
        self.selection = sameSlice self.clampedLeft(1)
    of KeyHome:
      self.selection = 0..0
    of KeyEnd:
      self.selection = sameSlice self.runes.len
    of KeyUp:
      if self.selection.len != 1:
        self.selection = sameSlice self.lineOffset(-1, isGrowingSelection = true)
      else:
        self.selection = sameSlice self.lineOffset(-1)
    of KeyDown:
      if self.selection.len != 1:
        self.selection = sameSlice self.lineOffset(1, isGrowingSelection = true)
      else:
        self.selection = sameSlice self.lineOffset(1)
    of KeyEscape:
      self.clicked(Exit, {})
    of KeyEnter:
      self.keyInput Rune '\n'

    else: discard

  elif down == KMeta:
    case pressed.getKey
    of KeyA:
      self.selection = 0..self.runes.len
    of KeyLeft:
      self.selection = 0..0
    of KeyRight:
      self.selection = ll+1..ll+1
    else: discard

  elif down == KShift:
    case pressed.getKey
    of KeyLeft:
      self.isGrowingLeft = self.isGrowingLeft or self.selection.len == 1 # Perhaps we just always move b and then resolve the slice later
      if self.isGrowingLeft:
        self.selection.a = self.clampedLeft(-1)
      else:
        self.selection.b = self.clampedRight(-1)
    of KeyRight:
      self.isGrowingLeft = self.isGrowingLeft and self.selection.len > 1
      if self.isGrowingLeft:
        self.selection.a = self.clampedLeft(1)
      else:
        self.selection.b = self.clampedRight(1)
    of KeyUp:
      self.isGrowingLeft = self.isGrowingLeft or self.selection.len == 1
      if self.isGrowingLeft:
        self.selection.a = self.lineOffset(-1, isGrowingSelection = true)
      else:
        self.selection.b = self.lineOffset(-1, isGrowingSelection = true)
    of KeyDown:
      self.isGrowingLeft = self.isGrowingLeft and self.selection.len > 1
      if self.isGrowingLeft:
        self.selection.a = self.lineOffset(1, isGrowingSelection = true)
      else:
        self.selection.b = self.lineOffset(1, isGrowingSelection = true)
    of KeyHome:
      self.selection.a = 0
      self.isGrowingLeft = true
    of KeyEnd:
      self.selection.b = self.runes.len
      self.isGrowingLeft = false
    else: discard

  elif down == KAlt:
    case pressed.getKey
    of KeyLeft:
      let idx = findPrevWord(self)
      self.selection = idx+1..idx+1
    of KeyRight:
      let idx = findNextWord(self)
      self.selection = idx..idx
    of KeyBackspace:
      if aa > 0:
        let idx = findPrevWord(self)
        self.runes.delete(idx+1..aa-1)
        self.selection = idx+1..idx+1
        self.updateLayout()
    else: discard

  self.value = 1
  self.selection = self.clampedLeft() .. self.clampedRight()

  if self.selHash != self.selection.hash():
    self.updateSelectionBoxes()
  refresh(self)

proc keyPress*(self: Input,
               pressed: UiButtonView,
               down: UiButtonView) {.slot.} =
  emit self.doKeyCommand(pressed, down)

proc draw*(self: Input) {.slot.} =
  ## Input widget!
  if self.layout.isNil:
    self.layout = GlyphArrangement()
  
  connect(self, doKeyCommand, self, Input.keyCommand)
  let fs = self.theme.font.size.scaled

  withDraw(self):

    clipContent true
    cornerRadius 10.0

    text "text":
      box 10'ux, 10'ux, 400'ux, 100'ux
      fill blackColor
      current.textLayout = self.layout

      rectangle "cursor":
        let sz = 0..self.layout.selectionRects.high()
        var sr =
          if self.isGrowingLeft:
            self.layout.selectionRects[self.selection.a]
          else:
            self.layout.selectionRects[self.selection.b]
        ## this is gross but works for now
        let width = max(0.08*fs, 2.0)
        sr.x = sr.x - width/2.0
        sr.y = sr.y - 0.04*fs
        sr.w = width
        sr.h = 0.9*fs
        boxOf sr.descaled()
        fill blackColor
        current.fill.a = self.value.toFloat * 1.0

      for i, sl in self.selectionRects:
        rectangle "selection", captures(i):
          let fs = self.theme.font.size.scaled
          var rs = self.selectionRects[i]
          rs.y = rs.y - 0.1*fs
          boxOf rs
          fill "#A0A0FF".parseHtmlColor 
          current.fill.a = 0.4

    if self.disabled:
      fill whiteColor.darken(0.4)
    else:
      fill whiteColor.darken(0.2)
      if self.isActive:
        fill current.fill.lighten(0.15)
        # this changes the color on hover!

exportWidget(input, Input)
