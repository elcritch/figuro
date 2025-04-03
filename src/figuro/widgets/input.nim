import std/unicode
import ../widget
import ../ui/textboxes
import ../ui/events
import pkg/chronicles

export textboxes


type
  InputOptions* = enum
    NoErase
    NoSelection
    OnlyAllowDigits

  Input* = ref object of Figuro
    opts*: set[InputOptions]
    text*: TextBox
    color*: Color
    cursorTick: int
    cursorCnt: int
    skipOnInput*: HashSet[Rune]

  Cursor* = ref object of Figuro
  Selection* = ref object of Figuro

proc options*(self: Input, opt: set[InputOptions], state = true) =
  if state: self.opts.incl opt
  else: self.opts.excl opt

proc skipOnInput*(self: Input, runes: HashSet[Rune]) =
  ## skips the given runes and advances the cursor to the 
  ## next rune when a user inputs a key
  ## 
  ## useful for skipping "decorative" tokens like ':' in a time
  self.skipOnInput = runes
proc skipOnInput*(self: Input, msg: varargs[char]) =
  ## skips the given runes and advances the cursor to the 
  ## next rune when a user inputs a key
  ## 
  ## useful for skipping "decorative" tokens like ':' in a time
  self.skipOnInput = msg.toRunes().toHashSet()

proc isActive*(self: Input): bool =
  Active in self.userAttrs

proc disabled*(self: Input): bool =
  Disabled in self.userAttrs

proc `active=`*(self: Input, state: bool) =
  self.attributes({Active}, state)

proc `disabled`*(self: Input, state: bool) =
  self.attributes({Disabled}, state)

proc overwrite*(self: Input): bool =
  Overwrite in self.text.opts
proc overwrite*(self: Input, state: bool) =
  self.text.options({Overwrite}, state)

proc font*(self: Input, font: UiFont) =
  self.text.font = font

proc foreground*(node: Input, color: Color) =
  node.color = color

proc align*(self: Input, kind: FontVertical) =
  self.text.vAlign = kind

proc justify*(self: Input, kind: FontHorizontal) =
  self.text.hAlign = kind

proc textChanged*(self: Input, runes: seq[Rune]): bool =
  result = runes != self.text.runes()

proc textChanged*(self: Input, txt: string): bool =
  result = textChanged(self, txt.toRunes())

proc runes*(self: Input, runes: seq[Rune]) {.slot.} =
  if self.textChanged(runes):
    self.text.replaceText(runes)
    self.text.update(self.box)
    # refresh(self)

proc skipSelectedRune*(self: Input, skips: HashSet[Rune] = self.skipOnInput) =
  ## skips the given runes on input
  let cr = self.text.runeAtCursor()
  if cr in skips:
    self.text.cursorNext()
    self.text.updateSelection()

proc text*(self: Input, txt: string) {.slot.} =
  runes(self, txt.toRunes())

proc runes*(self: Input): seq[Rune] =
  self.text.runes()

proc text*(self: Input): string =
  $self.text.runes()

proc doKeyCommand*(self: Input, pressed: UiButtonView, down: UiButtonView) {.signal.}

proc doUpdateInput*(self: Input, rune: Rune) {.signal.}

proc tick*(self: Input, now: MonoTime, delta: Duration) {.slot.} =
  if self.isActive:
    self.cursorCnt.inc()
    self.cursorCnt = self.cursorCnt mod 33
    if self.cursorCnt == 0:
      self.cursorTick = (self.cursorTick + 1) mod 2
      refresh(self)

proc clicked*(self: Input, kind: EventKind, buttons: UiButtonView) {.slot.} =
  echo "clicked... ", self.isActive, " kind ", kind, " disabled ", self.disabled
  self.active = kind == Done and not self.disabled
  if self.isActive:
    self.listens.signals.incl {evKeyboardInput, evKeyPress}
    self.cursorTick = 1
  else:
    self.listens.signals.excl {evKeyboardInput, evKeyPress}
    self.cursorTick = 0
  refresh(self)

proc keyInput*(self: Input, rune: Rune) {.slot.} =
  when defined(debugEvents):
    echo "\nInput:keyInput: ", " rune: ", $rune, " :: ", self.text.selection
  emit self.doUpdateInput(rune)

proc updateInput*(self: Input, rune: Rune) {.slot.} =
  self.skipSelectedRune()
  self.text.insert(rune)
  self.text.update(self.box)
  refresh(self)

proc getKey(p: UiButtonView): UiButton =
  for x in p:
    if x.ord in KeyRange.low.ord .. KeyRange.high.ord:
      return x

proc keyCommand*(self: Input, pressed: UiButtonView, down: UiButtonView) {.slot.} =
  when defined(debugEvents):
    echo "\nInput:keyPress: ",
      " pressed: ", $pressed, " down: ", $down, " :: ", self.text.selection
  let multiSelect = NoSelection notin self.opts
  if down == KNone:
    var update = true
    case pressed.getKey
    of KeyBackspace, KeyDelete:
      if self.text.hasSelection() and NoErase notin self.opts:
        self.text.delete()
        self.text.update(self.box)
    of KeyLeft:
      self.text.cursorLeft()
    of KeyRight:
      self.text.cursorRight()
    of KeyHome:
      self.text.cursorStart()
    of KeyEnd:
      self.text.cursorEnd()
    of KeyUp:
      self.text.cursorUp()
    of KeyDown:
      self.text.cursorDown()
    of KeyEscape:
      self.clicked(Exit, {})
    of KeyEnter:
      self.keyInput Rune '\n'
    else:
      discard
  elif down == KMeta:
    case pressed.getKey
    of KeyA:
      self.text.cursorSelectAll()
    of KeyLeft:
      self.text.cursorStart()
    of KeyRight:
      self.text.cursorEnd()
    else:
      discard
  elif down == KShift:
    case pressed.getKey
    of KeyLeft:
      self.text.cursorLeft(growSelection = multiSelect)
    of KeyRight:
      self.text.cursorRight(growSelection = multiSelect)
    of KeyUp:
      self.text.cursorUp(growSelection = multiSelect)
    of KeyDown:
      self.text.cursorDown(growSelection = multiSelect)
    of KeyHome:
      self.text.cursorStart(growSelection = multiSelect)
    of KeyEnd:
      self.text.cursorEnd(growSelection = multiSelect)
    else:
      discard

  ## todo finish moving to 
  # elif down == KAlt:
  #   case pressed.getKey
  #   of KeyLeft:
  #     let idx = findPrevWord(self)
  #     self.selection = idx+1..idx+1
  #   of KeyRight:
  #     let idx = findNextWord(self)
  #     self.selection = idx..idx
  #   of KeyBackspace:
  #     if aa > 0:
  #       let idx = findPrevWord(self)
  #       self.runes.delete(idx+1..aa-1)
  #       self.selection = idx+1..idx+1
  #       self.updateLayout()
  #   else: discard

  self.cursorTick = 1
  # self.text.updateSelection()
  refresh(self)

proc keyPress*(self: Input, pressed: UiButtonView, down: UiButtonView) {.slot.} =
  when defined(debugEvents):
    echo "input: ",
      " key: ", pressed, " ", self.text.selection, " runes: ", self.text.runes, " dir: ", self.text.growing
  emit self.doKeyCommand(pressed, down)

# proc layoutResize*(self: Input, node: Figuro, resize: tuple[prev: Position, curr: Position]) {.slot.} =
#   self.text.update(self.box)
#   refresh(self)

proc initialize*(self: Input) {.slot.} =
  self.text = newTextBox(self.box, self.frame[].theme.font)
  # connect(self, doLayoutResize, self, layoutResize)

proc draw*(self: Cursor) {.slot.} =
  ## Cursor widget!
  withWidget(self):
    WidgetContents()

proc draw*(self: Selection) {.slot.} =
  ## Cursor widget!
  withWidget(self):
    WidgetContents()

proc draw*(self: Input) {.slot.} =
  ## Input widget!
  withWidget(self):
    if not connected(self, doKeyCommand, self, keyCommand):
      connect(self, doKeyCommand, self, Input.keyCommand)
    if not connected(self, doUpdateInput, self):
      connect(self, doUpdateInput, self, updateInput)

    Text.new "basicText":
      this.textLayout = self.text.layout
      WidgetContents()
      foreground this, self.color

    Cursor.new "input-cursor":
      with this:
        boxOf self.text.cursorRect
        fill blackColor
      this.fill.a = self.cursorTick.toFloat * 1.0
      this.attributes({Active}, self.cursorTick == 1)

    for i, selRect in self.text.selectionRects:
      capture i:
        Selection.new "selection":
          with this:
            boxOf self.text.selectionRects[i]
            fill css"#A0A0FF" * 0.4

    if self.text.box != self.box:
      self.text.update(self.box)

