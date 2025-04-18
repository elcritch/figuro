import std/unicode

import ../commons
import utils
import chronicles

type
  TextDirection* = enum
    left
    right

  TextOptions* = enum
    Overwrite
    Rtl # this needs more work

  TextBox* = object
    selectionImpl*: Slice[int]
    opts*: set[TextOptions]
    growing*: TextDirection
      # Text editors store selection direction to control how keys behave
    selectionRects*: seq[Box]
    cursorRect*: Box
    selHash: Hash
    layout*: GlyphArrangement
    font*: UiFont
    box*: Box
    hAlign*: FontHorizontal = Left
    vAlign*: FontVertical = Top

proc options*(self: var TextBox, opt: set[TextOptions], state = true) =
  if state: self.opts.incl opt
  else: self.opts.excl opt

proc runes*(self: var TextBox): var seq[Rune] =
  self.layout.runes

proc runes*(self: TextBox): seq[Rune] =
  self.layout.runes

proc toSlice[T](a: T): Slice[T] =
  a .. a # Shortcut 

proc selWith*(self: TextBox, a = self.selectionImpl.a, b = self.selectionImpl.b): Slice[int] =
  result.a = a
  result.b = b

proc `selection`*(self: var TextBox): Slice[int] =
  self.selectionImpl
proc `selection`*(self: TextBox): Slice[int] =
  self.selectionImpl

proc hasSelection*(self: TextBox): bool =
  self.selection != 0 .. 0 and self.layout.runes.len() > 0

proc selected*(self: TextBox): seq[Rune] =
  for i in self.selection.a ..< self.selection.b:
    result.add self.layout.runes[i]

proc clamped*(self: TextBox, dir = right, offset = 0, inclusive=true): int =
  let endj = if inclusive: 0 else: 1
  let ln = self.layout.runes.len() - endj
  case dir
  of left:
    result = clamp(self.selection.a + offset, 0, ln)
  of right:
    result = clamp(self.selection.b + offset, 0, ln)

proc runeAtCursor*(self: TextBox): Rune =
  result = self.layout.runes[self.clamped(left, 0, inclusive=false)]

proc newTextBox*(box: Box, font: UiFont): TextBox =
  result = TextBox()
  result.box = box
  result.font = font
  result.layout = GlyphArrangement()

proc updateLayout*(self: var TextBox) =
  ## Update layout from runes.
  ## 
  ## This appends an extra character at the end to get the cursor
  ## position at the end, which depends on the next character.
  ## Otherwise, this character is ignored.
  let spans = {self.font: $self.runes(), self.font: " "}
  self.layout = getTypeset(self.box, spans, self.hAlign, self.vAlign)
  self.runes().setLen(self.runes().len() - 1)

iterator slices(selection: Slice[int], lines: seq[Slice[int]]): Slice[int] =
  ## get the slices for each line given a `selection`
  for line in lines:
    if selection.a in line or selection.b in line or
        (selection.a < line.a and line.b < selection.b):
      # handle partial lines
      yield max(line.a, selection.a) .. min(line.b, selection.b)
    else: # handle full lines
      yield line.a .. line.a

proc updateCursor(self: var TextBox) =
  # echo "updateCursor:sel: ", self.selectionImpl
  # echo "updateCursor:selRect: ", self.selectionRects
  # print "updateCursor:layout: ", self.layout
  if self.layout.selectionRects.len() == 0:
    return

  var cursor: Rect
  case self.growing
  of left:
    cursor = self.layout.selectionRects[self.selection.a]
  of right:
    cursor = self.layout.selectionRects[self.selection.b]

  ## this is gross but works for now
  let fontSize = self.font.size.scaled()
  cursor.w = max(0.08 * fontSize, 3.0)
  self.cursorRect = cursor.descaled()

proc updateSelection*(self: var TextBox) =
  ## update selection boxes, each line has it's own selection box
  self.selectionRects.setLen(0)
  self.selectionImpl = self.clamped(left) .. self.clamped(right)
  for sel in self.selectionImpl.slices(self.layout.lines):
    let lhs = self.layout.selectionRects[sel.a]
    let rhs = self.layout.selectionRects[sel.b]
    # rect starts on left hand side
    var rect = lhs
    # find the width and height of the rect
    rect.w = rhs.x - lhs.x
    rect.h = (rhs.y + rhs.h) - lhs.y
    self.selectionRects.add rect.descaled()
  self.updateCursor()

proc `selection=`*(self: var TextBox, sel: Slice[int]) =
  self.selectionImpl = sel
  self.updateSelection()

proc update*(self: var TextBox, box: Box, font = self.font) =
  self.box = box
  self.font = font
  self.updateLayout()
  self.updateSelection()

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

var wordBoundaryChars* = toHashSet[Rune]([
  Rune('.'), Rune(','), Rune(':'), Rune(';'), 
  Rune('!'), Rune('?'), Rune('('), Rune(')'),
  Rune('['), Rune(']'), Rune('{'), Rune('}'),
  Rune('"'), Rune('\''), Rune('`'), Rune('-'),
  Rune('/'), Rune('\\'), Rune('@'), Rune('#')
])

proc isWordBoundary(r: Rune): bool =
  ## Checks if a rune is a word boundary character (whitespace or punctuation)
  return r.isWhiteSpace() or r in wordBoundaryChars

proc findPrevWord*(self: TextBox): int =
  result = -1
  if self.runes().len() == 0 or self.selection.a <= 0:
    return result
    
  # Start from the character before the current position
  var i = max(0, self.selection.a - 1)
  
  # If we're already at a boundary, move back until we're not
  while i > 0 and self.runes()[i].isWordBoundary():
    dec(i)
    
  # Now find the start of the current word
  while i > 0 and not self.runes()[i-1].isWordBoundary():
    dec(i)
    
  return i - 1  # Return position before the word start

proc findNextWord*(self: TextBox): int =
  result = self.runes().len()

  # Start from the current position
  var i = self.selection.a + 1

  if self.runes().len() == 0 or i >= self.runes().len():
    warn "findNextWord:resturn:early: "
    return result
    
  warn "findNextWord: ", i= i, runes= $self.runes()[i], rlen= self.runes().len(), isWordBoundary= self.runes()[i].isWordBoundary()

  # Skip current word
  while i < self.runes().len() and not self.runes()[i].isWordBoundary():
    inc(i)
    
  # Skip word boundaries
  while i < self.runes().len() and self.runes()[i].isWordBoundary():
    inc(i)
    
  if i == self.runes().len():
    return i
  else:
    return i - 1

proc delete*(self: var TextBox) =
  if self.selection.len() > 1:
    let delSlice = self.clamped(left) .. self.clamped(right, offset = -1)
    if self.runes().len() > 1:
      self.runes().delete(delSlice)
    self.selection = self.clamped(left).toSlice()
  elif self.selection.len() == 1:
    if self.runes().len() >= 1:
      self.layout.runes.delete(self.clamped(left, offset = -1))
    self.selection = toSlice(self.clamped(left, offset = -1))

proc insert*(self: var TextBox, rune: Rune) =
  if self.selection.len() > 1:
    self.delete()

  if Overwrite in self.opts:
    let idx = self.clamped(left)
    if idx < self.runes.len():
      self.runes[idx] = rune
  else:
    self.runes.insert(rune, self.clamped(left))
    self.updateLayout()
    self.selection = toSlice(self.selection.a + 1)

proc insert*(self: var TextBox, runes: seq[Rune]) =
  let manySelected = self.selection.len() > 1
  if manySelected:
    self.delete()

  if Overwrite in self.opts and not manySelected:
    for i in 0..<runes.len():
      let idx = self.clamped(left) + i
      if idx < self.runes.len():
        self.runes[idx] = runes[i]
  else:
    self.runes.insert(runes, self.clamped(left))
    self.updateLayout()
    self.selection = toSlice(self.selection.a + runes.len())

proc replaceText*(self: var TextBox, runes: seq[Rune]) =
  var selection = self.selection
  self.layout.runes = runes
  selection.b = self.clamped(right)
  if self.selection.len() == 1:
    selection.a = selection.b - self.selection.len() + 1
  selection.a = self.clamped(left)
  self.selection = selection

proc cursorStart*(self: var TextBox, growSelection = false) =
  if growSelection:
    self.growing = left
    self.selection = self.selWith(a=0)
  else:
    self.selection = 0 .. 0

proc cursorEnd*(self: var TextBox, growSelection = false) =
  if growSelection:
    self.selection = self.selWith(b=self.runes.len)
    self.growing = right
  else:
    self.selection = toSlice self.runes.len()

proc cursorLeft*(self: var TextBox, growSelection = false) =
  if growSelection:
    if self.selection.len() == 1:
      self.growing = left
    case self.growing
    of left:
      self.selection = self.selWith(a= self.clamped(left, offset = -1))
    of right:
      self.selection = self.selWith(b= self.clamped(right, offset = -1))
  else:
    self.selection = toSlice self.clamped(self.growing, offset = -1)

proc cursorRight*(self: var TextBox, growSelection = false) =
  if growSelection:
    if self.selection.len() == 1:
      self.growing = right

    case self.growing
    of left:
      self.selection = self.selWith(a= self.clamped(left, offset = 1))
    of right:
      self.selection = self.selWith(b= self.clamped(right, offset = 1))
  else:
    # if self.selection.len != 1 and growing == right:
    self.selection = toSlice self.clamped(self.growing, offset = 1)

proc cursorNext*(self: var TextBox, growSelection = false) =
  if Rtl notin self.opts:
    self.cursorRight(growSelection)
  else:
    self.cursorLeft(growSelection)

proc cursorDown*(self: var TextBox, growSelection = false) =
  ## Move cursor or selection down
  let
    presentLine = self.findLine(true, growSelection)
    startCurrLine = self.layout.lines[presentLine].a
    nextLine = clamp(presentLine + 1, 0, self.layout.lines.high)
    lineStart = self.layout.lines[nextLine]

  # echo "cursorDown: ", " start: ", startCurrLine, " nextLine: ", nextLine, " lineStart: ", lineStart
  if presentLine == self.layout.lines.high:
    # if last line, goto end
    let b = self.layout.lines[^1].b
    if growSelection:
      self.selection = self.selWith(b= b)
    else:
      self.selection = toSlice(b)
  else:
    let
      lineDiff = self.clamped(right) - startCurrLine
      sel = min(lineStart.a + lineDiff, lineStart.b)
    if growSelection:
      self.selection = self.selWith(b= sel)
    else:
      self.selection = toSlice(sel)
  # textBox.adjustScroll()

proc cursorUp*(self: var TextBox, growSelection = false) =
  ## Move cursor or selection up
  let
    presentLine = self.findLine(true, growSelection)
    startCurrLine = self.layout.lines[presentLine].a
    nextLine = clamp(presentLine - 1, 0, self.layout.lines.high)
    lineStart = self.layout.lines[nextLine]

  # echo "cursorUp: ", " present: ", presentLine, " start: ", startCurrLine, " nextLine: ", nextLine, " lineStart: ", lineStart
  if presentLine == 0:
    # if first line, goto start
    if growSelection:
      self.selection = self.selWith(a= 0)
    else:
      self.selection = toSlice(0)
  else:
    let lineDiff = self.clamped(left) - startCurrLine
    let sel = min(lineStart.a + lineDiff, lineStart.b)
    # echo "lineDiff:alt: ", startCurrLine - self.clamped(left), " sel: ", lineStart.a + lineDiff
    # echo "lineDiff: ", lineDiff, " sel: ", lineStart.a, " b: ", lineStart.b
    if growSelection:
      self.selection = self.selWith(a= sel)
    else:
      self.selection = toSlice(sel)
  # textBox.adjustScroll()

proc cursorSelectAll*(self: var TextBox) =
  self.selection = 0 .. self.runes.len

proc cursorWordLeft*(self: var TextBox, growSelection = false) =
  let idx = findPrevWord(self)
  if growSelection:
    self.selection = self.selWith(a= idx + 1)
  else:
    self.selection = toSlice(idx + 1)

proc cursorWordRight*(self: var TextBox, growSelection = false) =
  let idx = findNextWord(self)
  if growSelection:
    self.selection = self.selWith(b= idx)
  else:
    self.selection = toSlice(idx)
