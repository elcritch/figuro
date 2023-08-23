import std/[hashes, unicode]
import uimaths

export uimaths

type

  FontId* = Hash
  FontName* = string

  GlyphPosition* = object
    ## Represents a glyph position after typesetting.
    fontSize*: float32
    subPixelShift*: float32
    rect*: Rect       # Where to draw the image character.
    selectRect*: Rect # Were to draw or hit selection.
    rune*: Rune

  GlyphArrangement* = ref object
    lines*: seq[(int, int)]    ## The (start, stop) of the lines of text.
    spans*: seq[(int, int)]    ## The (start, stop) of the spans in the text.
    fonts*: seq[FontId]          ## The font for each span.
    runes*: seq[Rune]          ## The runes of the text.
    positions*: seq[Vec2]      ## The positions of the glyphs for each rune.
    selectionRects*: seq[Rect] ## The selection rects for each glyph.