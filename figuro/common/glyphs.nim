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
    fontId*: FontId
    size*: float32              ## Font size in pixels.
    lineHeight*: float32 = -1.0 ## The line height in pixels or autoLineHeight for the font's default line height.

  UiFont* = object
    typefaceId*: TypefaceId
    size*: UICoord              ## Font size in pixels.
    lineHeight*: UICoord = -1.0'ui ## The line height in pixels or autoLineHeight for the font's default line height.
    fontCase*: FontCase
    underline*: bool            ## Apply an underline.
    strikethrough*: bool        ## Apply a strikethrough.
    noKerningAdjustments*: bool ## Optionally disable kerning pair adjustments

  GlyphArrangement* = ref object
    contentHash*: Hash
    lines*: seq[(int, int)]    ## The (start, stop) of the lines of text.
    spans*: seq[(int, int)]    ## The (start, stop) of the spans in the text.
    fonts*: seq[GlyphFont]          ## The font for each span.
    runes*: seq[Rune]          ## The runes of the text.
    positions*: seq[Vec2]      ## The positions of the glyphs for each rune.
    selectionRects*: seq[Rect] ## The selection rects for each glyph.

  TextSpan* = object
    text*: string
    font*: UiFont

proc newFont*(
    typeface: TypefaceId
): UiFont {.raises: [].} =
  result = UiFont()
  result.typefaceId = typeface
  result.size = 12'ui
  result.lineHeight = -1.0'ui

proc hash*(fnt: UiFont): Hash =
  var h = Hash(0)
  for n, f in fnt.fieldPairs():
    when n != "paints":
      h = h !& hash(f)
  result = !$h

proc getId*(font: UiFont): FontId =
  FontId font.hash()
