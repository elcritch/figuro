import sequtils, typography, unicode, vmath, bumpy
import std/re

#[
It's hard to implement a text. A text box has many complex features one does not think about
because it is so natural. Here is a small list of the most important ones:

* Typing at location of cursor
* Cursor going left and right
* Backspace and delete
* Cursor going up and down must take into account font and line wrap
* Clicking should select a character edge. Closet edge wins.
* Click and drag should select text, selected text will be between text cursor and select cursor
* Any insert when typing or copy pasting and have selected text, it should get removed and then do normal action
* Copy text should set it to system clipboard
* Cut text should copy and remove selected text
* Paste text should paste at current text cursor, if there is selection it needs to be removed
* Clicking before text should select first character
* Clicking at the end of text should select last character
* Click at the end of the end of the line should select character before the new line
* Click at the end of the start of the line should select character first character and not the newline
* Double click should select current word and space (TODO: stops non world characters, TODO: and enter into word selection mode)
* Double click again should select current paragraph
* Double click again should select everything
* TODO: Selecting during world selection mode should select whole words.
* Text area needs to be able to have margins that can be clicked
* There should be a scroll bar and a scroll window
* Scroll window should stay with the text cursor
* Backspace and delete with selected text remove selected text and don't perform their normal action
]#

type TextBox*[T] = ref object
  cursor*: int      # The typing cursor.
  selector*: int    # The selection cursor.
  item*: T # Item holding the runes we are typing.
  width*: float32       # Width of text box in px.
  height*: float32      # Height of text box in px.
  adjustTopTextFactor*: float32      # Adjust top of text down for visual balance
  cursorFactors*: (float32, float32)      # cursor to font ratio
  vAlign*: VAlignMode
  hAling*: HAlignMode
  scrollable*: bool
  wasScrolled*: bool
  editable*: bool
  scroll*: Vec2     # Scroll position.
  font*: Font
  mousePos*: Vec2
  hasChange*: bool

  multiline*: bool  # Single line only (good for input fields).
  wordWrap*: bool   # Should the lines wrap or not.
  pattern*: Regex   # pattern for input chars

  glyphs: seq[GlyphPosition]
  savedX: float

  boundsMin: Vec2
  boundsMax: Vec2

proc clamp[T](v, a, b: int): int =
  max(a, min(b, v))

proc init*[T](
  tx: var TextBox[T],
  font: Font,
  width: float32,
  height: float32,
  item: T,
  hAlign = Left,
  vAlign = Top,
  multiline = true,
  worldWrap = true,
  scrollable = true,
  editable = true,
  pattern: Regex = nil,
  cursorFactors = (0.10'f32, 0.68'f32)
) =
  ## Creates new empty text box.
  tx.item = item
  tx.font = font
  tx.width = width
  tx.height = height
  tx.hAling = hAlign
  tx.vAlign = vAlign
  tx.multiline = multiline
  tx.wordWrap = worldWrap
  tx.scrollable = scrollable
  tx.editable = editable
  tx.cursorFactors = cursorFactors 
  tx.pattern = pattern 

proc newTextBox*[T](
  font: Font,
  width: float32,
  height: float32,
  item: T,
  hAlign = Left,
  vAlign = Top,
  multiline = true,
  worldWrap = true,
  scrollable = true,
  editable = true,
  pattern: Regex = nil,
  cursorFactors = (0.10'f32, 0.68'f32)
): TextBox[T] =
  ## Creates new empty text box.
  result = TextBox[T]()
  result.init(
    font, width, height, item,
    hAlign, vAlign, multiline, worldWrap,
    scrollable, editable, pattern, cursorFactors,
  )

proc cursorWidth *[T](textBox: TextBox[T]): float32 =
  result = max(textBox.font.size * textBox.cursorFactors[0], 2)

template runes*[T](textBox: TextBox[T]): seq[Rune] =
  ## Converts internal runes to string.
  textBox.item.toRunes()

proc text*[T](textBox: TextBox[T]): seq[Rune] =
  ## Converts internal runes to string.
  textBox.runes

proc `text=`*[T](textBox: TextBox[T], text: string) =
  ## Converts string to internal runes.
  textBox.item.text = toRunes(text)
  textBox.cursor = min(textBox.cursor, textBox.item.text.len())
  textBox.hasChange = true

proc multilineCheck[T](textBox: TextBox[T]) =
  ## Makes sure there are not new lines in a single line text box.
  if not textBox.multiline:
    textBox.runes.keepIf(proc (r: Rune): bool = r != Rune(10))

proc size*[T](textBox: TextBox[T]): Vec2 =
  ## Returns with and height as a Vec2.
  vec2(float textBox.width, float textBox.height)

proc selection*[T](textBox: TextBox[T]): HSlice[int, int] =
  ## Returns current selection from.
  result.a = min(textBox.cursor, textBox.selector)
  result.b = max(textBox.cursor, textBox.selector)

import strformat

proc layout*[T](textBox: TextBox[T]): seq[GlyphPosition] =
  assert not textBox.font.isNil
  if textBox.glyphs.len == 0:
    textBox.multilineCheck()
    textBox.glyphs = textBox.font.typeset(
      textBox.runes,
      pos = vec2(0, textBox.font.size * textBox.adjustTopTextFactor),
      size = textBox.size,
      textBox.hAling,
      textBox.vAlign,
      clip = false,
      boundsMin = textBox.boundsMin,
      boundsMax = textBox.boundsMax
    )
  return textBox.glyphs

proc innerHeight*[T](textBox: TextBox[T]): float32 =
  ## Rectangle where selection cursor should be drawn.
  let layout = textBox.layout()
  if layout.len > 0:
    let lastPos = layout[^1].selectRect
    return lastPos.y + lastPos.h
  else:
    return textBox.font.lineHeight

proc locationRect*[T](textBox: TextBox[T], loc: int): Rect =
  ## Rectangle where cursor should be drawn.
  let layout = textBox.layout()
  if layout.len > 0:
    if loc >= layout.len:
      let g = layout[^1]
      # if last char is a new line go to next line.
      if g.character == "\n":
        result.x = 0
        result.y = g.selectRect.y + textBox.font.lineHeight
      else:
        result = g.selectRect
        result.x += g.selectRect.w
    else:
      let g = layout[loc]
      result = g.selectRect
  result.w = textBox.cursorWidth
  # result.h = min(textBox.font.size, textBox.font.lineHeight)
  let cusorHFactor = textBox.cursorFactors[1]
  result.h = textBox.font.lineHeight * cusorHFactor
  result.y += (textBox.font.lineHeight - result.h) / 2

proc cursorRect*[T](textBox: TextBox[T]): Rect =
  ## Rectangle where cursor should be drawn.
  textBox.locationRect(textBox.cursor)

proc cursorPos*[T](textBox: TextBox[T]): Vec2 =
  ## Position where cursor should be drawn.
  textBox.cursorRect.xy

proc selectorRect*[T](textBox: TextBox[T]): Rect =
  ## Rectangle where selection cursor should be drawn.
  textBox.locationRect(textBox.selector)

proc selectorPos*[T](textBox: TextBox[T]): Vec2 =
  ## Position where selection cursor should be drawn.
  textBox.cursorRect.xy

proc selectionRegions*[T](textBox: TextBox[T]): seq[Rect] =
  ## Selection regions to draw selection of text.
  let sel = textBox.selection
  textBox.layout.getSelection(sel.a, sel.b)

proc removedSelection*[T](textBox: TextBox[T]): bool =
  ## Removes selected runes if they are selected.
  ## Returns true if anything was removed.
  let sel = textBox.selection
  if sel.a != sel.b:
    textBox.runes.delete(sel.a, sel.b - 1)
    textBox.glyphs.setLen(0)
    textBox.cursor = sel.a
    textBox.selector = textBox.cursor
    textBox.hasChange = true
    return true
  return false

proc removeSelection[T](textBox: TextBox[T]) =
  ## Removes selected runes if they are selected.
  discard textBox.removedSelection()

proc adjustScroll*[T](textBox: TextBox[T]) =
  ## Adjust scroll to make sure cursor is in the window.
  if textBox.scrollable and not textBox.wasScrolled:
    let
      r = textBox.cursorRect
    # is pos.y inside the window?
    if r.y < textBox.scroll.y:
      textBox.scroll.y = r.y
    if r.y + r.h > textBox.scroll.y + float textBox.height:
      textBox.scroll.y = r.y + r.h - float textBox.height
    # is pos.x inside the window?
    if r.x < textBox.scroll.x:
      textBox.scroll.x = r.x
    if r.x + r.w > textBox.scroll.x + float textBox.width:
      textBox.scroll.x = r.x + r.w - float textBox.width

proc typeCharacter*[T](textBox: TextBox[T], rune: Rune) =
  ## Add a character to the text box.
  if not textBox.editable:
    return

  textBox.removeSelection()

  # don't add new lines in a single line box.
  if not textBox.multiline and rune == Rune(10):
    return

  # only match pattern
  let pattern = textBox.pattern
  if not pattern.isNil and not match($rune, pattern):
    return

  if textBox.cursor == textBox.runes.len:
    textBox.runes.add(rune)
  else:
    textBox.runes.insert(rune, textBox.cursor)

  inc textBox.cursor
  textBox.selector = textBox.cursor
  textBox.glyphs.setLen(0)
  textBox.adjustScroll()
  textBox.hasChange = true

proc typeCharacter*[T](textBox: TextBox[T], letter: char) =
  ## Add a character to the text box.
  textBox.typeCharacter(Rune(letter))

proc typeCharacters*[T](textBox: TextBox[T], s: string) =
  ## Add a character to the text box.
  if not textBox.editable:
    return
  textBox.removeSelection()
  for rune in runes(s):
    textBox.runes.insert(rune, textBox.cursor)
    inc textBox.cursor
  textBox.selector = textBox.cursor
  textBox.glyphs.setLen(0)
  textBox.adjustScroll()
  textBox.hasChange = true

proc copy*[T](textBox: TextBox[T]): string =
  ## Returns the text that was copied.
  let sel = textBox.selection
  if sel.a != sel.b:
    return $textBox.runes[sel.a ..< sel.b]

proc paste*[T](textBox: TextBox[T], s: string) =
  ## Pastes a string.
  if not textBox.editable:
    return
  textBox.typeCharacters(s)
  textBox.savedX = textBox.cursorPos.x

proc cut*[T](textBox: TextBox[T]): string =
  ## Returns the text that was cut.
  result = textBox.copy()
  if not textBox.editable:
    return
  textBox.removeSelection()
  textBox.savedX = textBox.cursorPos.x

proc setCursor*[T](textBox: TextBox[T], loc: int) =
  textBox.cursor = clamp(loc, 0, textBox.runes.len + 1)
  textBox.selector = textBox.cursor

proc backspace*[T](textBox: TextBox[T], shift = false) =
  ## Backspace command.
  if not textBox.editable:
    return
  if textBox.removedSelection(): return
  if textBox.cursor > 0:
    textBox.runes.delete(textBox.cursor - 1)
    textBox.glyphs.setLen(0)
    textBox.adjustScroll()
    dec textBox.cursor
    textBox.selector = textBox.cursor
    textBox.hasChange = true

proc delete*[T](textBox: TextBox[T], shift = false) =
  ## Delete command.
  if not textBox.editable:
    return
  if textBox.removedSelection(): return
  if textBox.cursor < textBox.runes.len:
    textBox.runes.delete(textBox.cursor)
    textBox.glyphs.setLen(0)
    textBox.adjustScroll()
    textBox.hasChange = true

proc backspaceWord*[T](textBox: TextBox[T], shift = false) =
  ## Backspace word command. (Usually ctr + backspace).
  if not textBox.editable:
    return
  if textBox.removedSelection(): return
  if textBox.cursor > 0:
    while textBox.cursor > 0 and
      not textBox.runes[textBox.cursor - 1].isWhiteSpace():
      textBox.runes.delete(textBox.cursor - 1)
      dec textBox.cursor
    textBox.glyphs.setLen(0)
    textBox.adjustScroll()
    textBox.selector = textBox.cursor
    textBox.hasChange = true

proc deleteWord*[T](textBox: TextBox[T], shift = false) =
  ## Delete word command. (Usually ctr + delete).
  if not textBox.editable:
    return
  if textBox.removedSelection(): return
  if textBox.cursor < textBox.runes.len:
    while textBox.cursor < textBox.runes.len and
      not textBox.runes[textBox.cursor].isWhiteSpace():
      textBox.runes.delete(textBox.cursor)
    textBox.glyphs.setLen(0)
    textBox.adjustScroll()
    textBox.hasChange = true

proc left*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor left.
  if textBox.cursor > 0:
    dec textBox.cursor
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
    textBox.savedX = textBox.cursorPos.x

proc right*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor right.
  if textBox.cursor < textBox.runes.len:
    inc textBox.cursor
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
    textBox.savedX = textBox.cursorPos.x

proc down*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor down.
  if textBox.layout.len == 0:
    return
  let pos = textBox.layout.pickGlyphAt(
    vec2(textBox.savedX,
         1.5 * textBox.cursorPos.y + textBox.font.lineHeight))
  if pos.character != "":
    textBox.cursor = pos.count
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
  elif textBox.cursorPos.y == textBox.layout[^1].selectRect.y:
    # Are we on the last line? Then jump to start location last.
    textBox.cursor = textBox.runes.len
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor

proc up*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor up.
  if textBox.layout.len == 0:
    return
  let pos = textBox.layout.pickGlyphAt(
    vec2(textBox.savedX, textBox.cursorPos.y - textBox.font.lineHeight * 0.5))
  if pos.character != "":
    textBox.cursor = pos.count
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
  elif textBox.cursorPos.y == textBox.layout[0].selectRect.y:
    # Are we on the first line? Then jump to start location 0.
    textBox.cursor = 0
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor

proc leftWord*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor left by a word (Usually ctr + left).
  if textBox.cursor > 0:
    dec textBox.cursor
  while textBox.cursor > 0 and
    not textBox.runes[textBox.cursor - 1].isWhiteSpace():
    dec textBox.cursor
  textBox.adjustScroll()
  if not shift:
    textBox.selector = textBox.cursor
  textBox.savedX = textBox.cursorPos.x

proc rightWord*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor right by a word (Usually ctr + right).
  if textBox.cursor < textBox.runes.len:
    inc textBox.cursor
  while textBox.cursor < textBox.runes.len and
    not textBox.runes[textBox.cursor].isWhiteSpace():
    inc textBox.cursor
  textBox.adjustScroll()
  if not shift:
    textBox.selector = textBox.cursor
  textBox.savedX = textBox.cursorPos.x

proc currRune[T](textBox: TextBox[T], offset: int): Rune =
  result = textBox.runes()[textBox.cursor - offset]

proc currRuneAt[T](textBox: TextBox[T], index: int): Rune =
  result = textBox.runes()[index]

proc startOfLine*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor left by a word.
  while textBox.cursor > 0 and textBox.currRune(-1) != Rune(10):
    dec textBox.cursor
  textBox.adjustScroll()
  if not shift:
    textBox.selector = textBox.cursor
  textBox.savedX = textBox.cursorPos.x

proc endOfLine*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor right by a word.
  while textBox.cursor < textBox.runes.len and
          textBox.currRune(0) != Rune(10):
    inc textBox.cursor
  textBox.adjustScroll()
  if not shift:
    textBox.selector = textBox.cursor
  textBox.savedX = textBox.cursorPos.x

proc pageUp*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor up by half a text box height.
  if textBox.layout.len == 0:
    return
  let
    pos = vec2(textBox.savedX, textBox.cursorPos.y - float(textBox.height) * 0.5)
    g = textBox.layout.pickGlyphAt(pos)
  if g.character != "":
    textBox.cursor = g.count
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
  elif pos.y <= textBox.layout[0].selectRect.y:
    # Above the first line? Then jump to start location 0.
    textBox.cursor = 0
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor

proc pageDown*[T](textBox: TextBox[T], shift = false) =
  ## Move cursor down up by half a text box height.
  if textBox.layout.len == 0:
    return
  let
    pos = vec2(textBox.savedX, textBox.cursorPos.y + float(textBox.height) * 0.5)
    g = textBox.layout.pickGlyphAt(pos)
  if g.character != "":
    textBox.cursor = g.count
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
  elif pos.y > textBox.layout[^1].selectRect.y:
    # Bellow the last line? Then jump to start location last.
    textBox.cursor = textBox.runes.len
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor

import strformat

proc mouseAction*[T](
  textBox: TextBox[T],
  mousePos: Vec2,
  click = true,
  shift = false
) =
  ## Click on this with a mouse.
  textBox.wasScrolled = false
  textBox.mousePos = mousePos + textBox.scroll
  # Pick where to place the cursor.
  let pos = textBox.layout.pickGlyphAt(textBox.mousePos)
  if pos.character != "":
    textBox.cursor = pos.count
    textBox.savedX = textBox.mousePos.x
    if pos.character != "\n":
      # Select to the right or left of the character based on what is closer.
      let pickOffset = textBox.mousePos - pos.selectRect.xy
      if pickOffset.x > pos.selectRect.w / 2 and
          textBox.cursor == textBox.runes.len - 1:
        inc textBox.cursor
  else:
    # If above the text select first character.
    if textBox.mousePos.y < 0:
      textBox.cursor = 0
    # If below text select last character + 1.
    if textBox.mousePos.y > float textBox.innerHeight:
      textBox.cursor = textBox.glyphs.len
  textBox.savedX = textBox.mousePos.x
  textBox.adjustScroll()

  if not shift and click:
    textBox.selector = textBox.cursor

proc selectWord*[T](textBox: TextBox[T], mousePos: Vec2, extraSpace = true) =
  ## Select word under the cursor (double click).
  textBox.mouseAction(mousePos, click = true)
  while textBox.cursor > 0 and
    not textBox.runes[textBox.cursor - 1].isWhiteSpace():
    dec textBox.cursor
  while textBox.selector < textBox.runes.len and
    not textBox.runes[textBox.selector].isWhiteSpace():
    inc textBox.selector
  if extraSpace:
    # Select extra space to the right if its there.
    if textBox.selector < textBox.runes.len and
      textBox.runes[textBox.selector] == Rune(32):
      inc textBox.selector

proc selectParagraph*[T](textBox: TextBox[T], mousePos: Vec2) =
  ## Select paragraph under the cursor (triple click).
  textBox.mouseAction(mousePos, click = true)
  while textBox.cursor > 0 and
          textBox.currRune(-1)  != Rune(10):
    dec textBox.cursor
  while textBox.selector < textBox.runes.len and
          textBox.currRuneAt(textBox.selector) != Rune(10):
    inc textBox.selector

proc selectAll*[T](textBox: TextBox[T]) =
  ## Select all text (quad click).
  textBox.cursor = 0
  textBox.selector = textBox.runes.len

proc resize*[T](textBox: TextBox[T], size: Vec2) =
  ## Resize text box.
  textBox.width = size.x
  textBox.height = size.y
  textBox.glyphs.setLen(0)
  textBox.adjustScroll()

proc scrollBy*[T](textBox: TextBox[T], amount: float) =
  ## Scroll text box with a scroll wheel.
  textBox.wasScrolled = true
  textBox.scroll.y += amount
  # Make sure it does not scroll off the top.
  textBox.scroll.y = max(0, textBox.scroll.y)
  # Or the bottom.
  textBox.scroll.y = min(
    textBox.innerHeight - textBox.height,
    textBox.scroll.y
  )
  # Check if there is not enough text to scroll.
  if textBox.innerHeight < textBox.height:
    textBox.scroll.y = 0