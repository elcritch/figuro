import std/unicode

import commons
import ../ui/utils

type
  Input* = ref object of Figuro
    isActive*: bool
    disabled*: bool
    selection*: Slice[int]
    selectionRects*: seq[Box]
    selHash*: Hash
    layout*: GlyphArrangement
    textNode*: Figuro
    value: int
    cnt: int

proc doKeyCommand*(self: Input,
                   pressed: UiButtonView,
                   down: UiButtonView) {.signal.}

template aa(): int = self.selection.a
template bb(): int = self.selection.b
template ll(): int = self.layout.runes.len() - 1

proc updateSelectionBoxes*(self: Input) =
  let fs = self.theme.font.size.scaled

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
    rs.y = rs.y - 0.1*fs
    rs.w = rb.x - ra.x
    rs.h = (rb.y + rb.h) - ra.y
    self.selectionRects.add rs.descaled()
    # echo "self.selectionRects: ", rs.descaled()

proc updateLayout*(self: Input, text = seq[Rune].none) =
  let runes =
    if text.isSome: text.get()
    else: self.layout.runes
  let spans = {self.theme.font: $runes, self.theme.font: "*"}
  self.layout = internal.getTypeset(self.box, spans)
  self.layout.runes.setLen(ll())
  self.updateSelectionBoxes()

proc findPrevWord*(self: Input): int =
  result = -1
  for i in countdown(max(0,aa-2), 0):
    echo "findPrevWord: ", i
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

proc keyInput*(self: Input,
               rune: Rune) {.slot.} =
  self.layout.runes.insert(rune, max(aa, 0))
  self.updateLayout()
  self.selection = bb+1 .. bb+1
  refresh(self)

proc keyCommand*(self: Input,
                 pressed: UiButtonView,
                 down: UiButtonView) {.slot.} =
  when defined(debugEvents):
    echo "\nInput:keyPress: ",
            " pressed: ", $pressed,
            " down: ", $down, " :: ", self.selection
  if down == KNone:
    if pressed == {KeyBackspace} and self.selection.b > 0:
      let selection = max(aa-1, 0)..max(bb-1, 0)
      self.layout.runes.delete(selection)
      self.updateLayout()
      self.selection = max(aa-1, 0)..max(aa-1, 0)
    elif pressed == {KeyLeft}:
      self.selection = max(aa-1, 0)..max(aa-1, 0)
    elif pressed == {KeyRight}:
      self.selection = min(bb+1, ll+1)..min(bb+1, ll+1)
    elif pressed == {KeyEscape}:
      self.clicked(Exit, {})
    elif pressed == {KeyEnter}:
      self.layout.runes.add Rune '\n'
      self.updateLayout()
      self.updateSelectionBoxes()
      self.selection = aa+1 .. bb+1
  elif down == KCadet:
    if pressed == {KeyA}:
      self.selection = 0..ll+1
      self.updateSelectionBoxes()
  elif down == KControl:
    if pressed == {KeyLeft}:
      self.selection = 0..0
    elif pressed == {KeyRight}:
      self.selection = ll+1..ll+1
  elif down == KShift:
    if pressed == {KeyLeft}:
      self.selection = max(aa-1, 0)..bb
    elif pressed == {KeyRight}:
      self.selection = aa..min(bb+1, ll+1)
  elif down == KAlt:
    if pressed == {KeyLeft}:
      let idx = findPrevWord(self)
      self.selection = idx+1..idx+1
    elif pressed == {KeyRight}:
      let idx = findNextWord(self)
      self.selection = idx..idx
    elif pressed == {KeyBackspace} and aa > 0:
      let idx = findPrevWord(self)
      self.layout.runes.delete(idx+1..aa-1)
      self.selection = idx+1..idx+1
      self.updateLayout()
  self.value = 1
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

      echo ""
      rectangle "cursor":
        let sz = 0..self.layout.selectionRects.high()
        if self.selection.a in sz and self.selection.b in sz: 
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
          echo "cursor ", app.frameCount

      for sl in self.selectionRects:
        rectangle "selection", captures(sl):
          box sl
          fill blackColor * 0.1
          echo "selection ", app.frameCount
          # fill "#0000CC".parseHtmlColor * 0.2

    if self.disabled:
      fill whiteColor.darken(0.4)
    else:
      fill whiteColor.darken(0.2)
      if self.isActive:
        fill current.fill.lighten(0.15)
        # this changes the color on hover!

exportWidget(input, Input)
