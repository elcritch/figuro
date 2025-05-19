import std/unicode

import ../commons
import chronicles

type
  Orient* = enum
    Left
    Right
    Up
    Down
    Beginning
    TheEnd
    NextWord
    PreviousWord


  TextOptions* = enum
    Overwrite
    Rtl # this needs more work

  TextBox* = object
    selectionRange*: Slice[int]
    opts*: set[TextOptions]
    cursorPos*: int = 0
    anchor: int = 0 # The anchor is the location a selection starts from.
    selectionExists = false
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

proc `selection`*(self: var TextBox): Slice[int] =
  self.selectionRange
proc `selection`*(self: TextBox): Slice[int] =
  self.selectionRange

proc hasSelection*(self: TextBox): bool =
  return self.selectionExists

proc selected*(self: TextBox): seq[Rune] =
  for i in self.selectionRange.a ..< self.selectionRange.b:
    result.add self.layout.runes[i]

# A common problem that comes up is dealing with the difference between
# possible cursor positions and valid rune indices.
#
# For a text of length N there are N+1 possible cursor positions
# (from 0 at the beginning to N at the end).
# For a text of length N, valid rune indices are 0 to N-1.
#
# So when you use a select-all function you get a slice of 0-N,
# but when you try to delete that you might get an error because
# no rune exists at N.

proc clamped*(self: TextBox, dir: Orient = Right, offset = 0, inclusive=true): int =
  ## The main goal of `clamped` is to return an integer value (an index)
  ## that is "clamped" or restricted to be within the valid bounds of
  ## the text runes (characters) in the `TextBox`.
  ## This helps prevent errors that might arise from trying to
  ## access an index outside the actual text length
  ## (e.g., when moving the cursor or defining a selection).
  let endj = if inclusive: 0 else: 1
  let ln = self.layout.runes.len() - endj
  case dir
  of Left:
    result = clamp(self.selectionRange.a + offset, 0, ln)
  of Right:
    result = clamp(self.selectionRange.b + offset, 0, ln)
  else: discard

proc runeAtCursor*(self: TextBox): Rune =
  if self.runes().len() == 0:
    return Rune(0)
  result = self.layout.runes[self.clamped(Left, 0, inclusive=false)]

proc findLine*(self: TextBox, down: bool, select: bool = false): int =
  ## Finds the index of the line in self.layout.lines that contains the
  ## relevant cursor/selection point.
  ## - `down`: Indicates the direction of intended cursor movement (true for down, false for up).
  ##           Used when `select` is false to determine which end of selection to check.
  ## - `select`: True if the selection is currently being grown (e.g., Shift + Arrow).
  ##             Defaults to false.

  result = -1 # Default to -1 if no line is found

  # If layout.lines is empty, we can't find a line.
  # This can happen if the textbox is empty and updateLayout hasn't run or produced lines.
  # However, updateLayout typically ensures at least one line definition for an empty box due to the temp char.
  if self.layout.lines.len == 0:
    return -1

  var charPosToFind: int
  if select:
    charPosToFind = self.cursorPos
  else:
    if down:
      charPosToFind = self.selectionRange.b
    else:
      charPosToFind = self.selectionRange.a

  let clampedCharPos = clamp(charPosToFind, 0, self.runes().len())

  for idx, lineSlice in self.layout.lines:
    # Standard case: character position is within the rune indices of the line.
    if clampedCharPos >= lineSlice.a and clampedCharPos <= lineSlice.b:
      return idx

    # Edge case: Cursor is at the very end of the text (position `runes.len()`),
    # which is 1 past the last character index (`runes.len() - 1`).
    # This position is considered to be on the last line if the text is not empty
    # and the last line indeed ends at the last character.
    if idx == self.layout.lines.high and      # It's the last line
       clampedCharPos == self.runes().len() and # Position is at the end of all runes
       self.runes().len() > 0 and              # And there are runes (text is not empty)
       lineSlice.b == self.runes().len() - 1:  # Last line ends at the last rune index
      return idx

  return result

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
  # Start from the character before the current position
  var i = self.cursorPos - 1
  # If we're already at a boundary, move back until we're not
  while i > 0 and self.runes()[i].isWordBoundary():
    dec(i)
  # Now find the start of the current word
  while i > 0 and not self.runes()[i-1].isWordBoundary():
    dec(i)
  return i  # Return position before the word start

proc findNextWord*(self: TextBox): int =
  result = self.runes().len()
  # Start from the current position
  var i = self.cursorPos
  if self.runes().len() == 0 or i >= self.runes().len():
    trace "findNextWord:resturn:early: "
    return result
  trace "findNextWord: ", i= i, runes= $self.runes()[i], rlen= self.runes().len(), isWordBoundary= self.runes()[i].isWordBoundary()
  # Skip current word
  while i < self.runes().len() and not self.runes()[i].isWordBoundary():
    inc(i)
  # Skip word boundaries
  while i < self.runes().len() and self.runes()[i].isWordBoundary():
    inc(i)
  return i

# --- Selection ---

proc updateSelection*(self: var TextBox) =
  ## update selection boxes, each line has it's own selection box
  self.selectionRects.setLen(0)
  for sel in self.selectionRange.slices(self.layout.lines):
    let lhs = self.layout.selectionRects[sel.a]
    let rhs = self.layout.selectionRects[sel.b]
    # rect starts on Left hand side
    var rect = lhs
    # find the width and height of the rect
    rect.w = rhs.x - lhs.x
    rect.h = (rhs.y + rhs.h) - lhs.y
    self.selectionRects.add rect.descaled()

proc growSelection*(self: var TextBox) =
  self.selectionRange.a = min(self.cursorPos, self.anchor)
  self.selectionRange.b = max(self.cursorPos, self.anchor)
  if not self.selectionExists: self.selectionExists = true
  self.updateSelection()

proc clearSelection*(self: var TextBox) =
  self.anchor = self.cursorPos
  self.selectionRange.a = self.cursorPos
  self.selectionRange.b = self.cursorPos
  if self.selectionExists:
    self.selectionExists = false
    self.updateSelection()

# --- Cursor ---

proc updateCursor*(self: var TextBox) =
  # echo "updateCursor:sel: ", self.selectionRange
  # echo "updateCursor:selRect: ", self.selectionRects
  # print "updateCursor:layout: ", self.layout
  if self.layout.selectionRects.len() == 0:
    return

  var cursor: Rect
  cursor = self.layout.selectionRects[self.cursorPos]

  ## this is gross but works for now
  let fontSize = self.font.size.scaled()
  cursor.w = max(0.08 * fontSize, 3.0)
  self.cursorRect = cursor.descaled()

proc placeCursor*(self: var TextBox, pos: int, select = false) =
  # Places the keyboard cursor at the specified position.
  # Clears the selection and brings the anchor along unless
  # clearSelection is set to false.
  self.cursorPos = clamp(pos, 0, self.runes().len())
  self.updateCursor()
  if select: self.growSelection()
  else: self.clearSelection()

proc shiftCursorDown*(self: var TextBox, select = false): int =
  ## Move cursor or selection down one line.
  ## - `select`: If true, extends the selection downwards.
  ##             If false, moves the cursor and clears any existing selection.

  let presentLineIdx = self.findLine(down = true, select = select)

  # If findLine returns -1 (e.g., empty layout), do nothing.
  if presentLineIdx == -1:
    return

  # Get the start rune index of the current line.
  let currentLineStartIdx = self.layout.lines[presentLineIdx].a

  # Handle the edge case: If already on the last line.
  if presentLineIdx == self.layout.lines.high:
    return self.runes().len()

  # Handle moving from any line other than the last line.
  else:
    # Calculate the index of the line below the current one.
    let nextLineIdx = clamp(presentLineIdx + 1, 0, self.layout.lines.high)
    # Get the rune index range (Slice) of the line below.
    let nextLineSlice = self.layout.lines[nextLineIdx]

    # Calculate the horizontal offset (difference in rune indices)
    # from the start of the current line to the cursor's Right edge.
    let horizontalOffset = self.clamped(Right) - currentLineStartIdx

    # Calculate the target rune index on the next line.
    # Add the horizontal offset to the start of the next line.
    # Ensure the target index doesn't go beyond the end index of the next line.
    return min(nextLineSlice.a + horizontalOffset, nextLineSlice.b)

proc shiftCursorUp*(self: var TextBox, select = false): int =
  ## Move cursor or selection up one line.
  ## - `select`: If true, extends the selection upwards.
  ##             If false, moves the cursor and clears any existing selection.

  let presentLineIdx = self.findLine(down = false, select = select)
  if presentLineIdx == -1:
    return

  let currentLineStartIdx = self.layout.lines[presentLineIdx].a
  if presentLineIdx == 0:
    return 0
  else:
    let previousLineIdx = clamp(presentLineIdx - 1, 0, self.layout.lines.high)
    let previousLineSlice = self.layout.lines[previousLineIdx]
    let horizontalOffset = self.clamped(Left) - currentLineStartIdx
    return min(previousLineSlice.a + horizontalOffset, previousLineSlice.b)

proc shiftCursor*(self: var TextBox,
                  orientation: Orient,
                  select = false) =
  ## Shifts the keyboard cursor based on an orientation.
  ## Options include: Right, Left, Up, Down,
  ## Beginning, TheEnd, PreviousWord, NextWord.
  ## Clears the selection and brings the anchor along unless
  ## select is set to true.
  let pos: int = case orientation
    of Right: self.cursorPos + 1
    of Left: self.cursorPos - 1
    of NextWord: self.findNextWord()
    of PreviousWord: self.findPrevWord()
    of Beginning: 0
    of TheEnd: self.runes().len()
    of Up: self.shiftCursorUp(select)
    of Down: self.shiftCursorDown(select)
  self.cursorPos = clamp(pos, 0, self.runes().len())
  self.updateCursor()
  if select: self.growSelection()
  else: self.clearSelection()

proc setCursor*(self: var TextBox) =
  self.updateCursor()

proc `selection=`*(self: var TextBox, sel: Slice[int]) =
  if sel.a == sel.b:
    self.cursorPos = sel.a
    self.clearSelection()
  else:
    self.selectionRange = sel
    self.anchor = sel.a
    self.cursorPos = sel.b
    self.updateCursor()
    if not self.selectionExists: self.selectionExists = true
    self.updateSelection()

proc selectAll*(self: var TextBox) =
  self.anchor = 0
  self.cursorPos = self.runes.len
  self.selection = 0 .. self.runes.len

proc update*(self: var TextBox, box: Box, font = self.font) =
  self.box = box
  self.font = font
  self.updateLayout()
  self.updateSelection()

proc deleteSelected*(self: var TextBox) =
  # Deletes a selection range.
  let delSlice = self.clamped(Left) .. self.clamped(Right, offset = -1)
  let cursorOnLeft = self.cursorPos == self.selectionRange.a
  if not cursorOnLeft: self.placeCursor(self.selectionRange.a)
  if self.runes().len() != 0:
    self.runes().delete(delSlice)
    self.clearSelection()

proc delete*(self: var TextBox, orientation: Orient) =
  # Deletes a rune in the specified direction from the cursor.
  # Shifts the cursor in cases where that is expected.
  # Deletes a selection range if one exists.
  if self.selectionExists:
    self.deleteSelected()
    return
  case orientation
    of Left:
      if self.cursorPos != 0:
        self.runes().delete(self.cursorPos - 1)
        self.shiftCursor(Left)
    of Right:
      if self.cursorPos != self.runes().len():
        self.runes().delete(self.cursorPos)
    of PreviousWord:
      let idx = clamp(self.findPrevWord(), 0, self.runes().len())
      self.runes.delete((idx) ..< self.cursorPos)
      self.placeCursor(idx)
    else: discard

proc insert*(self: var TextBox,
            rune: Rune,
            overWrite = false,
            rangeLimit = 0) =
  ## Inserts a rune at the current cursor position.
  ## overWrite: If set to true, then replace the rune in front of cursorPos.
  ## rangeLimit: If set to a number larger than 0,
  ## then this function will not insert a rune once there are that many runes.
  if self.selectionExists:
    self.deleteSelected()

  # 1. no overWrite, no rangeLimit
  if not overWrite and rangeLimit == 0:
    self.runes.insert(rune, self.cursorPos)
  # 2. no overWrite, yes rangeLimit
  elif not overWrite and rangeLimit > 0:
    if rangeLimit > self.runes.len:
     self.runes.insert(rune, self.cursorPos)
  # 3. yes overWrite, no rangeLimit
  elif overWrite and rangeLimit == 0:
    if self.cursorPos < self.runes.len():
      self.runes[self.cursorPos] = rune
    else:
      self.runes.insert(rune, self.cursorPos)
  # 4. yes overWrite, yes rangeLimit
  elif overWrite and rangeLimit > 0:
    if self.cursorPos <= rangeLimit - 1:
      if self.cursorPos < self.runes.len():
        self.runes[self.cursorPos] = rune
      else:
        self.runes.insert(rune, self.cursorPos)

  self.updateLayout()
  self.shiftCursor(Right)

proc insert*(self: var TextBox,
            runes: seq[Rune],
            overWrite = false) =

  if self.selectionExists:
    self.deleteSelected()

  if overWrite:
    for i in 0..<runes.len():
      if self.cursorPos < self.runes.len():
        self.runes[self.cursorPos] = runes[i]
        inc(self.cursorPos)
  else:
    self.runes.insert(runes, self.cursorPos)
    self.cursorPos = self.cursorPos + runes.len()

  self.placeCursor(self.cursorPos)
  self.updateLayout()


proc replaceText*(self: var TextBox, runes: seq[Rune]) =
  var selection = self.selectionRange
  self.layout.runes = runes
  selection.b = self.clamped(Right)
  if self.selectionRange.len() == 1:
    selection.a = selection.b - self.selectionRange.len() + 1
  selection.a = self.clamped(Left)
  self.selectionRange = selection

proc cursorNext*(self: var TextBox) =
  if Rtl notin self.opts:
    self.shiftCursor(Right)
  else:
    self.shiftCursor(Left)
