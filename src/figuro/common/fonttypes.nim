import std/[hashes, unicode]
import uimaths

export uimaths

type
  TypefaceId* = Hash
  FontId* = Hash
  GlyphId* = Hash
  FontName* = string

  FontCase* = enum
    NormalCase
    UpperCase
    LowerCase
    TitleCase

  FontHorizontal* = enum
    Left
    Center
    Right

  FontVertical* = enum
    Top
    Middle
    Bottom

  GlyphFont* = object
    fontId*: FontId
    size*: float32 ## Font size in pixels.
    lineHeight*: float32 = -1.0
    descentAdj*: float32 = 0.0
      ## The line height in pixels or autoLineHeight for the font's default line height.

  UiFont* = object
    typefaceId*: TypefaceId
    size*: UiScalar = 12.0'ui ## Font size in pixels.
    lineHeightScale*: float32 = 0.9
    lineHeightOverride*: UiScalar = -1.0'ui
      ## The line height in pixels or autoLineHeight for the font's default line height.
    fontCase*: FontCase
    underline*: bool ## Apply an underline.
    strikethrough*: bool ## Apply a strikethrough.
    noKerningAdjustments*: bool ## Optionally disable kerning pair adjustments

  GlyphArrangement* = object
    contentHash*: Hash
    lines*: seq[Slice[int]] ## The (start, stop) of the lines of text.
    spans*: seq[Slice[int]] ## The (start, stop) of the spans in the text.
    fonts*: seq[GlyphFont] ## The font for each span.
    runes*: seq[Rune] ## The runes of the text.
    positions*: seq[Vec2] ## The positions of the glyphs for each rune.
    selectionRects*: seq[Rect] ## The selection rects for each glyph.
    maxSize*: UiSize
    minSize*: UiSize

  TextSpan* = object
    text*: string
    font*: UiFont

proc hash*(fnt: UiFont): Hash =
  var h = Hash(0)
  for n, f in fnt.fieldPairs():
    when n != "paints":
      h = h !& hash(f)
  result = !$h

proc getId*(font: UiFont): FontId =
  FontId font.hash()

proc getContentHash*(
    box: Box,
    uiSpans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
): Hash =
  var h = Hash(0)
  h = h !& hash(box)
  h = h !& hash(uiSpans)
  h = h !& hash(hAlign)
  h = h !& hash(vAlign)
  result = !$h
