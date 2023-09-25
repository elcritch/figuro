import std/unicode

import commons
import ../ui/utils

type
  Input* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    selection*: Slice[int]
    isGrowingLeft*: bool # Text editors store selection direction to control how keys behave
    selectionRects*: seq[Box]
    selHash*: Hash
    layout*: GlyphArrangement
    textNode*: Figuro
    value: int
    cnt: int

proc runes(self: Input): var seq[Rune] = self.layout.runes

proc doKeyCommand*(self: Input,
                   pressed: UiButtonView,
                   down: UiButtonView) {.signal.}

proc tick*(self: Input) {.slot.} =
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

proc clampedLeft(self: Input, offset = 0): int = clamp(self.selection.a + offset, 0, self.runes.len)
proc clampedRight(self: Input, offset = 0): int = clamp(self.selection.b + offset, 0, self.runes.len)

proc deleteSelection(self: Input): Slice[int] = self.clampedLeft .. clamp(self.selection.b - 1, 0, self.runes.len)

template aa(): int = self.selection.a
template bb(): int = self.selection.b
template ll(): int = self.runes.len() - 1

proc updateSelectionBoxes(self: Input) =

  var sels: seq[Slice[int]]
  for sl in self.layout.lines:
    if aa in sl or bb in sl or (aa < sl.a and sl.b < bb):
      sels.add max(sl.a, aa)..min(sl.b, bb)
    else:
      sels.add sl.a..sl.a

  self.selectionRects.setLen(0)
  for sl in sels:
    let ra = self.layout.selectionRects[sl.a]
    let rb = self.layout.selectionRects[sl.b]
    var rs = ra
    rs.w = rb.x - ra.x
    rs.h = (rb.y + rb.h) - ra.y
    self.selectionRects.add rs.descaled()

proc updateLayout*(self: Input, text = seq[Rune].none) =
  let runes =
    if text.isSome: text.get()
    else: self.runes
  let spans = {self.theme.font: $runes, self.theme.font: "*"}
  self.layout = internal.getTypeset(self.box, spans)
  self.runes.setLen(ll())

proc findLine*(self: Input, down: bool, isGrowingSelection = false): int =
  result = -1
  for idx, sl in self.layout.lines:
    if isGrowingSelection:
      if (self.isGrowingLeft and self.selection.a in sl) or (not self.isGrowingLeft and self.selection.b in sl):
        return idx
    else:
      if down:
        if self.selection.b in sl:
          return idx
      elif self.selection.a in sl:
        return idx


proc findPrevWord*(self: Input): int =
  result = -1
  for i in countdown(max(0,aa-2), 0):
    if self.runes[i].isWhiteSpace():
      return i

proc findNextWord*(self: Input): int =
  result = self.runes.len()
  for i in countup(aa+1, self.runes.len()-1):
    if self.runes[i].isWhiteSpace():
      return i

proc keyInput*(self: Input,
               rune: Rune) {.slot.} =
  if self.selection.len > 1:
    self.runes.delete(self.deleteSelection())
  self.runes.insert(rune, self.clampedLeft())
  self.updateLayout()
  self.selection = self.selection.a + 1 .. self.selection.a + 1
  self.updateSelectionBoxes()
  refresh(self)

proc getKey(p: UiButtonView): UiButton =
  for x in p:
    if x.ord in KeyRange.low.ord .. KeyRange.high.ord:
      return x

proc lineOffset(self: Input, offset: int, isGrowingSelection = false): int =
  # This is likely much more complicated than required...
  let 
    presentLine = self.findLine(offset > 0, isGrowingSelection)
    nextLine = clamp(presentLine + offset, 0, self.layout.lines.high)
    lineStart = self.layout.lines[nextLine]
    lineDiff =
      if offset > 0: # Moving down the page
        if isGrowingSelection and self.isGrowingLeft:
          self.clampedLeft() - self.layout.lines[presentLine].a
        elif isGrowingSelection and not self.isGrowingLeft:
          self.clampedRight() - self.layout.lines[presentLine].a
        elif not isGrowingSelection:
          self.clampedRight() - self.layout.lines[presentLine].a
        else:
          raiseAssert("How do we get here?!")
      else: # Moving up the page
        if isGrowingSelection and self.isGrowingLeft:
          self.clampedLeft() - self.layout.lines[presentLine].a
        elif isGrowingSelection and not self.isGrowingLeft:
          self.clampedRight() - self.layout.lines[presentLine].a
        elif not isGrowingSelection:
          self.clampedLeft() - self.layout.lines[presentLine].a
        else:
          raiseAssert("How do we get here?!")
  if presentLine == 0 and offset < 0:
    0
  elif presentLine == self.layout.lines.high and offset > 0:
    self.layout.lines[^1].b
  elif offset < 0 or offset > 0:
    (lineStart.a + lineDiff).min(lineStart.b)
  else:
    raiseAssert("Offset cannot be 0, that's just the line.")


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
    if pressed == {KeyA}:
      self.selection = 0..ll+1

    elif pressed == {KeyLeft}:
      self.selection = 0..0
    elif pressed == {KeyRight}:
      self.selection = ll+1..ll+1

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
    if pressed == {KeyLeft}:
      let idx = findPrevWord(self)
      self.selection = idx+1..idx+1
    elif pressed == {KeyRight}:
      let idx = findNextWord(self)
      self.selection = idx..idx
    elif pressed == {KeyBackspace} and aa > 0:
      let idx = findPrevWord(self)
      self.runes.delete(idx+1..aa-1)
      self.selection = idx+1..idx+1
      self.updateLayout()

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
    connect(findRoot(self), doTick, self, Input.tick())

    text "text":
      box 10, 10, 400, 100
      fill blackColor
      self.textNode = current
      current.textLayout = self.layout

      rectangle "cursor":
        let sz = 0..self.layout.selectionRects.high()
        if self.selection.a in sz and self.selection.b in sz:
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
          box sr.descaled()
          fill blackColor
          current.fill.a = self.value.toFloat * 1.0

      for i, sl in self.selectionRects:
        rectangle "selection", captures(i):
          let fs = self.theme.font.size.scaled
          var rs = self.selectionRects[i]
          rs.y = rs.y - 0.1*fs
          box rs
          fill "#A0A0FF".parseHtmlColor 
          current.fill.a = 0.2

    if self.disabled:
      fill whiteColor.darken(0.4)
    else:
      fill whiteColor.darken(0.2)
      if self.isActive:
        fill current.fill.lighten(0.15)
        # this changes the color on hover!

exportWidget(input, Input)
