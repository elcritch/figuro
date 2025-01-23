import std/unicode

import ../ui/textboxes

type Input* = ref object of Figuro
  isActive*: bool
  disabled*: bool
  text*: TextBox
  value: int
  cnt: int

proc doKeyCommand*(self: Input, pressed: UiButtonView, down: UiButtonView) {.signal.}

proc tick*(self: Input, now: MonoTime, delta: Duration) {.slot.} =
  if self.isActive:
    self.cnt.inc()
    self.cnt = self.cnt mod 33
    if self.cnt == 0:
      self.value = (self.value + 1) mod 2
      refresh(self)

proc clicked*(self: Input, kind: EventKind, buttons: UiButtonView) {.slot.} =
  self.isActive = kind == Enter
  if self.isActive:
    self.listens.signals.incl {evKeyboardInput, evKeyPress}
  else:
    self.listens.signals.excl {evKeyboardInput, evKeyPress}
    self.value = 0
  refresh(self)

proc keyInput*(self: Input, rune: Rune) {.slot.} =
  self.text.insert(rune)
  self.text.update()
  refresh(self)

proc getKey(p: UiButtonView): UiButton =
  for x in p:
    if x.ord in KeyRange.low.ord .. KeyRange.high.ord:
      return x

proc keyCommand*(self: Input, pressed: UiButtonView, down: UiButtonView) {.slot.} =
  when defined(debugEvents):
    echo "\nInput:keyPress: ",
      " pressed: ", $pressed, " down: ", $down, " :: ", self.selection
  if down == KNone:
    var update = true
    case pressed.getKey
    of KeyBackspace:
      if self.text.hasSelection():
        self.text.delete()
        self.text.update()
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
      update = false
    if update:
      self.text.updateSelection()
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
    self.text.updateSelection()
  elif down == KShift:
    case pressed.getKey
    of KeyLeft:
      self.text.cursorLeft(growSelection = true)
    of KeyRight:
      self.text.cursorRight(growSelection = true)
    of KeyUp:
      self.text.cursorUp(growSelection = true)
    of KeyDown:
      self.text.cursorDown(growSelection = true)
    of KeyHome:
      self.text.cursorStart(growSelection = true)
    of KeyEnd:
      self.text.cursorEnd(growSelection = true)
    else:
      discard
    self.text.updateSelection()

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

  self.value = 1
  # self.text.updateSelection()
  refresh(self)

proc keyPress*(self: Input, pressed: UiButtonView, down: UiButtonView) {.slot.} =
  echo "input: ",
    " key: ", pressed, " ", self.text.selection, " runes: ", self.text.runes, " dir: ",
    self.text.growing
  emit self.doKeyCommand(pressed, down)
  echo "post:input: ",
    " key: ", pressed, " ", self.text.selection, " runes: ", self.text.runes, " dir: ",
    self.text.growing

proc draw*(self: Input) {.slot.} =
  ## Input widget!
  connect(self, doKeyCommand, self, Input.keyCommand)

  if self.text.isNil:
    self.text = newTextBox(self.box, self.frame[].theme.font)

  with self:
    clipContent true
    cornerRadius 10.0

  var node = self
  text "text":
    with node:
      fill blackColor
    node.textLayout = self.text.layout
    rectangle "cursor":
      with node:
        boxOf self.text.cursorRect
        fill blackColor
      node.fill.a = self.value.toFloat * 1.0

    for i, selRect in self.text.selectionRects:
      capture i:
        Rectangle.new "selection":
          with node:
            boxOf self.text.selectionRects[i]
            fill css"#A0A0FF" * 0.4

  if self.disabled:
    fill node, whiteColor.darken(0.4)
  else:
    fill node, whiteColor.darken(0.2)
    if self.isActive:
      fill node, node.fill.lighten(0.15)
      # this changes the color on hover!

