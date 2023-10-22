import std/unicode

import commons
import utils

type
  TextBox* = object
    selection*: Slice[int]
    isGrowingLeft*: bool # Text editors store selection direction to control how keys behave
    selectionRects*: seq[Box]
    selHash: Hash
    layout*: GlyphArrangement

# proc runes(self: TextBox): var seq[Rune] = self.layout.runes

proc updateLayout*(self: var TextBox, theme: Theme, box: Box) =
  ## Update layout from runes.
  ## 
  ## This appends an extra character at the end to get the cursor
  ## position at the end, which depends on the next character.
  ## Otherwise, this character is ignored.
  let spans = {theme.font: $self.layout.runes,
               theme.font: "."}
  self.layout = internal.getTypeset(box, spans)
  self.layout.runes.setLen(self.layout.runes.len() - 1)

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

proc clamp*(self: TextBox, offset = 0, left = false): int =
  if left:
    clamp(self.selection.a + offset, 0, self.layout.runes.len)
  else:
    clamp(self.selection.b + offset, 0, self.layout.runes.len)

proc clampedLeft*(self: TextBox, offset = 0): int = self.clamp(left=true)
proc clampedRight*(self: TextBox, offset = 0): int = self.clamp(left=false)

proc deleteSelected*(self: TextBox): Slice[int] =
  self.clamp(left=true) .. clamp(self.selection.b - 1, 0, self.layout.runes.len())
