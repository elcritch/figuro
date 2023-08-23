import std/[os, strformat, unicode, times, strutils, hashes]

import pkg/chroma
import pkg/pixie
import pkg/pixie/fonts
import pkg/opengl
import pkg/windy

import utils, context
import commons

var
  typefaceTable*: Table[TypefaceId, Typeface]
  fontTable*: Table[FontId, Font]

  glyphOffsets*: Table[Hash, Vec2]

proc hash*(tp: Typeface): Hash = 
  var h = Hash(0)
  h = h !& hash tp.filePath
  result = !$h

proc hash*(fnt: Font): Hash = 
  var h = Hash(0)
  for n, f in fnt[].fieldPairs():
    when n != "paints":
      h = h !& hash(f)
  result = !$h

proc getTypeface*(name: string): FontId =
  let
    typeface = readTypeface(DataDirPath / name)
    id = TypefaceId hash(typeface)
  typefaceTable[id] = typeface
  result = id
  echo "getTypeFace: ", result

proc getFont*(font: GlyphFont): FontId =
  let id = FontId hash(font)
  let typeface = typefaceTable[font.typefaceId]
  var pxfont = newFont(typeface)
  pxfont.typeface = typeface
  pxfont.textCase = parseEnum[TextCase]($font.fontCase)
  # copy rest of the fields with matching names
  for pn, a in fieldPairs(pxfont[]):
    for fn, b in fieldPairs(font):
      when pn == fn:
        a = b
  if font.lineHeight == -1.0:
    pxfont.lineHeight = autoLineHeight
  fontTable[id] = pxfont
  result = id
  echo "getFont: ", result

# proc loadGlyph*(font: GlyphFont):  =

proc hash*(glyph: GlyphPosition): Hash {.inline.} =
  result = hash((
    2344,
    glyph.fontId,
    glyph.rune,
    (glyph.subPixelShift*100).int,
    0
  ))

proc getGlyphImage*(ctx: context.Context, glyph: GlyphPosition): Option[Hash] = 
  ## returns Glyph's hash, will generate glyph if needed
  
  let hashFill = glyph.hash()

  if hashFill in ctx.entries:
    result = some hashFill
  if hashFill notin ctx.entries:
    let
      fontId = glyph.fontId
      font = fontTable[fontId]
      w = glyph.selectRect.w.int
      h = glyph.selectRect.h.int

    let
      image = newImage(w, h)
    
    try:
      let path = getGlyphPath(font.typeface, glyph.rune)
      image.fillPath(path, rgba(255, 255, 255, 255))
      ctx.putImage(hashFill, image)
      result = some hashFill
    except PixieError:
      result = none Hash

proc getTypeset*(text: string, font: FontId, box: Box): GlyphArrangement =
  let
    rect = box.scaled()
    wh = rect.wh
    pf = fontTable[font]
    arrangement = typeset(@[newSpan(text, pf)], bounds = rect.wh)
    snappedBounds = arrangement.computeBounds().snapToPixels()

  echo "snappedBounds: ", snappedBounds

