import std/unicode

import commons
import utils

type
  TextDirection* = enum
    left
    right

  TextBox* = object
    selection*: Slice[int]
    growing*: TextDirection # Text editors store selection direction to control how keys behave
    selectionRects*: seq[Box]
    selHash: Hash
    layout*: GlyphArrangement
    font*: UiFont
    box*: Box

proc runes*(self: TextBox): var seq[Rune] = self.runes()
proc toSlice[T](a: T): Slice[T] = a..a # Shortcut 

proc hasSelection*(self: TextBox): bool =
  self.selection != 0..0 and self.layout.runes.len() > 0

proc initTextBox*(box: Box, font: UiFont): TextBox =
  result = TextBox()
  result.box = box
  result.font = font

proc updateLayout*(self: var TextBox, box = self.box, font = self.font) =
  ## Update layout from runes.
  ## 
  ## This appends an extra character at the end to get the cursor
  ## position at the end, which depends on the next character.
  ## Otherwise, this character is ignored.
  self.box = box
  self.font = font
  let spans = {self.font: $self.runes(),
               self.font: "."}
  self.layout = internal.getTypeset(self.box, spans)
  self.runes().setLen(self.runes().len() - 1)

iterator slices(selection: Slice[int], lines: seq[Slice[int]]): Slice[int] =
  ## get the slices for each line given a `selection`
  for line in lines:
    if selection.a in line or
       selection.b in line or
       (selection.a < line.a and line.b < selection.b):
      # handle partial lines
      yield max(line.a, selection.a)..min(line.b, selection.b)
    else: # handle full lines
      yield line.a..line.a

proc updateSelectionBoxes*(self: var TextBox) =
  ## update selection boxes, each line has it's own selection box
  self.selectionRects.setLen(0)
  for sel in self.selection.slices(self.layout.lines):
    let lhs = self.layout.selectionRects[sel.a]
    let rhs = self.layout.selectionRects[sel.b]
    # rect starts on left hand side
    var rect = lhs
    # find the width and height of the rect
    rect.w = rhs.x - lhs.x
    rect.h = (rhs.y + rhs.h) - lhs.y
    self.selectionRects.add rect.descaled()

proc update*(self: var TextBox) =
  self.updateLayout()
  self.updateSelectionBoxes()

proc clamped*(self: TextBox, dir = right, offset = 0): int =
  case dir
  of left:
    clamp(self.selection.a + offset, 0, self.runes().len)
  of right:
    clamp(self.selection.b + offset, 0, self.runes().len)

proc findLine*(self: TextBox, down: bool, isGrowingSelection = false): int =
  result = -1
  let lhs = self.selection.a
  let rhs = self.selection.b
  for idx, line in self.layout.lines:
    if isGrowingSelection:
      if self.growing == left and lhs in line:
        return idx
      if self.growing == right and rhs in line:
        return idx
    else:
      if down:
        if rhs in line:
          return idx
      elif lhs in line:
        return idx

proc findPrevWord*(self: TextBox): int =
  result = -1
  for i in countdown(max(0,self.selection.a-2), 0):
    if self.runes()[i].isWhiteSpace():
      return i

proc findNextWord*(self: TextBox): int =
  result = self.runes().len()
  for i in countup(self.selection.a+1, self.runes().len()-1):
    if self.runes()[i].isWhiteSpace():
      return i

proc delete*(self: var TextBox) =
  if self.selection.len() > 1:
    let delSlice = self.clamped(left) .. self.clamped(right, offset = -1)
    self.runes().delete(delSlice)
    self.selection = self.clamped(left).toSlice()
  elif self.selection.len() == 1:
    self.runes.delete(self.clamped(left, offset = -1))
    self.selection = toSlice(self.clamped(left, offset = -1))

proc insert*(self: var TextBox, rune: Rune) =
  self.delete()
  self.runes.insert(rune, self.clamped(left))
  self.selection = toSlice(self.selection.a + 1)

proc cursorLeft*(self: var TextBox, growSelection = false) =
  if growSelection:
    if self.selection.len() == 1: self.growing = left
    case self.growing:
    of left:
      self.selection.a = self.clamped(left, offset = -1)
    of right:
      self.selection.b = self.clamped(right, offset = -1)
  else:
    self.selection = toSlice self.clamped(self.growing, offset = -1)

proc cursorRight*(self: var TextBox, growSelection = false) =
  if growSelection:
    if self.selection.len() > 1: self.growing = left
    case self.growing:
    of left:
      self.selection.a = self.clamped(left, offset = 1)
    of right:
      self.selection.b = self.clamped(right, offset = 1)
  else:
    self.selection = toSlice self.clamped(self.growing, offset = -1)

proc cursorDown*(self: var TextBox, growSelection = false) =
  ## Move cursor or selection down
  let
    presentLine = self.findLine(true, growSelection)
    startCurrLine = self.layout.lines[presentLine].a
    nextLine = clamp(presentLine + 1, 0, self.layout.lines.high)
    lineStart = self.layout.lines[nextLine]

  if presentLine == self.layout.lines.high:
    # if last line, goto end
    self.selection = toSlice(self.layout.lines[^1].b)
  else:
    let lineDiff = 
      if growSelection:
        self.clamped(dir=self.growing) - startCurrLine
      else:
        self.clamped(right) - startCurrLine
    self.selection = toSlice(min(lineStart.a + lineDiff, lineStart.b))
  # textBox.adjustScroll()

proc cursorUp*(self: var TextBox, growSelection = false) =
  ## Move cursor or selection up
  let
    presentLine = self.findLine(true, growSelection)
    startCurrLine = self.layout.lines[presentLine].a
    nextLine = clamp(presentLine + 1, 0, self.layout.lines.high)
    lineStart = self.layout.lines[nextLine]

  if presentLine == 0:
    # if first line, goto start
    self.selection = toSlice(0)
  else:
    let lineDiff = 
      if growSelection:
        self.clamped(dir=self.growing) - startCurrLine
      else:
        self.clamped(left) - startCurrLine
    self.selection = toSlice(min(lineStart.a + lineDiff, lineStart.b))
  # textBox.adjustScroll()


