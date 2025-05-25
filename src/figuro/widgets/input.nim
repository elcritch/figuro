import std/unicode
import ../widget
import ../ui/textboxes
import ../ui/text
import ../ui/events
import pkg/chronicles

export text
export textboxes

type
  InputOptions* {.pure.} = enum
    NoErase
    NoSelection
    OnlyAllowDigits
    OverwriteMode

  Input* = ref object of Figuro
    opts*: set[InputOptions]
    text*: TextBox
    color*: Color
    cursorTick: int
    cursorCnt: int
    skipOnInput*: HashSet[Rune]
    rangeLimit*: int = 0

  Cursor* = ref object of Figuro
  Selection* = ref object of Figuro

proc setOptions*(self: Input, opt: set[InputOptions], state = true) {.thisWrapper.} =
  if state: self.opts.incl opt
  else: self.opts.excl opt

proc skipOnInput*(self: Input, runes: HashSet[Rune]) =
  ## skips the given runes and advances the cursor to the
  ## next rune when a user inputs a key
  ##
  ## useful for skipping "decorative" tokens like ':' in a time
  self.skipOnInput = runes
proc skipOnInput*(self: Input, msg: varargs[char]) {.thisWrapper.} =
  ## skips the given runes and advances the cursor to the
  ## next rune when a user inputs a key
  ##
  ## useful for skipping "decorative" tokens like ':' in a time
  self.skipOnInput = msg.toRunes().toHashSet()

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

proc setText*(self: Input, txt: string) {.slot.} =
  runes(self, txt.toRunes())
  refresh(self)

proc runes*(self: Input): seq[Rune] =
  self.text.runes()

proc getText*(self: Input): string =
  $self.text.runes()

proc doKeyCommand*(self: Input, pressed: set[UiKey], down: set[UiKey]) {.signal.}

proc doUpdateInput*(self: Input, rune: Rune) {.signal.}

proc tick*(self: Input, now: MonoTime, delta: Duration) {.slot.} =
  if self.active():
    self.cursorCnt.inc()
    self.cursorCnt = self.cursorCnt mod 33
    if self.cursorCnt == 0:
      self.cursorTick = (self.cursorTick + 1) mod 2
      refresh(self)

proc activate*(self: Input, kind: EventKind = Done) {.slot.} =
  self.active(kind == Done and not self.disabled)
  if self.active():
    self.listens.signals.incl {evKeyboardInput, evKeyPress}
    self.cursorTick = 1
  else:
    self.listens.signals.excl {evKeyboardInput, evKeyPress}
    self.cursorTick = 0
  refresh(self)

proc clicked*(self: Input, kind: EventKind, buttons: set[UiMouse]) {.slot.} =
  self.activate(kind)

proc keyInput*(self: Input, rune: Rune) {.slot.} =
  when defined(debugEvents):
    echo "\nInput:keyInput: ", " rune: ", $rune, " :: ", self.text.selection
  emit self.doUpdateInput(rune)

proc updateInput*(self: Input, rune: Rune) {.slot.} =
  self.skipSelectedRune()
  if OverwriteMode in self.opts:
    self.text.insert(rune, overWrite = true, self.rangeLimit)
  else:
    self.text.insert(rune, overWrite = false, self.rangeLimit)
  self.text.update(self.box)
  refresh(self)

proc getKey(p: set[UiKey]): UiKey =
  for x in p:
    return x

proc keyCommand*(self: Input, pressed: set[UiKey], down: set[UiKey]) {.slot.} =
  when defined(debugEvents):
    debug "input:keyCommand:",
      key= pressed,
      down= down,
      sel= self.text.selection,
      runes= self.text.runes,
      runesLen= self.text.runes.len,
      dir= self.text.growing,
      downAlt = down.matches({KAlt}),
      downShift = down.matches({KShift}),
      downAltShift = down.matches({KAlt, KShift})

  # let multiSelect = NoSelection notin self.opts
  if down.matches({KNone}):
    var update = true
    case pressed.getKey()
    of KeyBackspace:
      if NoErase notin self.opts:
        self.text.delete(Left)
        self.text.update(self.box)
    of KeyDelete:
      if NoErase notin self.opts:
        self.text.delete(Right)
        self.text.update(self.box)
    of KeyLeft:
      self.text.shiftCursor(Left)
    of KeyRight:
      self.text.shiftCursor(Right)
    of KeyHome:
      self.text.shiftCursor(Beginning)
    of KeyEnd:
      self.text.shiftCursor(TheEnd)
    of KeyUp:
      self.text.shiftCursor(Up)
    of KeyDown:
      self.text.shiftCursor(Down)
    of KeyEscape:
      self.clicked(Exit, {})
    of KeyEnter:
      self.keyInput Rune '\n'
    else:
      discard
  elif down.matches({KMeta}):
    case pressed.getKey
    of KeyA:
      self.text.selectAll()
    of KeyLeft:
      self.text.shiftCursor(PreviousWord)
    of KeyRight:
      self.text.shiftCursor(NextWord)
    of KeyC:
      if self.text.hasSelection():
        echo "copying... ", self.text.selected()
        let selectedText = $self.text.selected()
        self.frame[].clipboardSet(selectedText)
    of KeyV:
      let pasteText = self.frame[].clipboard()
      match pasteText:
        ClipboardStr(str):
          if str.len > 0:
            self.text.insert(str.toRunes())
            self.text.update(self.box)
        _:
          discard
    of KeyX:
      if self.text.hasSelection() and NoErase notin self.opts:
        let selectedText = $self.text.selected()
        self.frame[].clipboardSet(selectedText)
        # self.text.delete()
        self.text.update(self.box)
    # of KeyP:
    #   self.text.insert("hola ".toRunes())
    else:
      discard
  elif down.matches({KShift}):
    case pressed.getKey
    of KeyLeft:
      self.text.shiftCursor(Left, select = true)
    of KeyRight:
      self.text.shiftCursor(Right, select = true)
    of KeyUp:
      self.text.shiftCursor(Up, select = true)
    of KeyDown:
      self.text.shiftCursor(Down, select = true)
    of KeyHome:
      self.text.shiftCursor(Beginning, select = true)
    of KeyEnd:
      self.text.shiftCursor(TheEnd, select = true)
    else:
      discard
  elif down.matches({KAlt}):
    case pressed.getKey
    of KeyBackspace:
      # Delete the word to the left of the cursor
      # If there's a selection, just delete it
      if self.text.cursorPos == 0: return
      if self.text.hasSelection() and NoErase notin self.opts:
        self.text.deleteSelected()
      # Otherwise delete to word boundary
      elif NoErase notin self.opts:
        self.text.delete(PreviousWord)
    else:
      discard
  elif down.matches({KAlt, KShift}):
    case pressed.getKey
    of KeyBackspace:
      # Delete the word to the left of the cursor
      # If there's a selection, just delete it
      if self.text.cursorPos == 0: return
      if self.text.hasSelection() and NoErase notin self.opts:
        self.text.deleteSelected()
      # Otherwise delete to word boundary
      elif NoErase notin self.opts:
        self.text.delete(PreviousWord)
        self.text.update(self.box)
    else:
      discard
  elif down.matches({KMeta, KShift}):
    case pressed.getKey
      of KeyLeft:
        self.text.shiftCursor(PreviousWord, select = true)
      of KeyRight:
        self.text.shiftCursor(NextWord, select = true)
      else:
        discard

  self.cursorTick = 1
  # self.text.updateSelection()
  refresh(self)

proc keyPress*(self: Input, pressed: set[UiKey], down: set[UiKey]) {.slot.} =
  when defined(debugEvents):
    notice "input:keyPress:",
      key= pressed,
      sel= self.text.selection,
      runes= self.text.runes,
      dir= self.text.growing
  emit self.doKeyCommand(pressed, down)

proc layoutResize*(self: Input, node: Figuro) {.slot.} =
  ## Update text layout and cursor position when the Input widget's box changes
  self.text.update(self.box)
  self.text.updateCursor()
  refresh(self)

proc initialize*(self: Input) {.slot.} =
  self.text = newTextBox(self.box, self.frame[].theme.font)
  connect(self.frame[].root, doTick, self, tick)
  connect(self, doLayoutResize, self, layoutResize)
  connect(self, doKeyCommand, self, Input.keyCommand)
  connect(self, doUpdateInput, self, updateInput)

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

    Text.new "basicText":
      this.textLayout = self.text.layout
      WidgetContents()
      foreground this, self.color


    Cursor.new "input-cursor":
      this.boxOf(self.text.cursorRect)
      fill blackColor
      this.fill.a = self.cursorTick.toFloat * 1.0
      this.setUserAttr({Active}, self.cursorTick == 1)

    for i, selRect in self.text.selectionRects:
      capture i:
        Selection.new "selection":
          with this:
            boxOf self.text.selectionRects[i]
            fill css"#A0A0FF" * 0.4
