import std/[hashes, unicode, sequtils]
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

  GlyphFont* = object
    typefaceId*: TypefaceId
    size*: float32              ## Font size in pixels.
    lineHeight*: float32 = -1.0 ## The line height in pixels or autoLineHeight for the font's default line height.
    fontCase*: FontCase
    underline*: bool            ## Apply an underline.
    strikethrough*: bool        ## Apply a strikethrough.
    noKerningAdjustments*: bool ## Optionally disable kerning pair adjustments

  GlyphArrangement* = ref object
    contentHash*: Hash
    lines*: seq[(int, int)]    ## The (start, stop) of the lines of text.
    spans*: seq[(int, int)]    ## The (start, stop) of the spans in the text.
    fonts*: seq[FontId]          ## The font for each span.
    runes*: seq[Rune]          ## The runes of the text.
    positions*: seq[Vec2]      ## The positions of the glyphs for each rune.
    selectionRects*: seq[Rect] ## The selection rects for each glyph.

  TextSpan* = object
    text*: string
    font*: FontId

proc newFont*(typeface: TypefaceId): GlyphFont {.raises: [].} =
  result = GlyphFont()
  result.typefaceId = typeface
  result.size = 12
  result.lineHeight = -1.0
