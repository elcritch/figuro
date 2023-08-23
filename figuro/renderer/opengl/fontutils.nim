import std/[os, strformat, unicode, times, strutils, hashes]

import pkg/vmath
import pkg/chroma
import pkg/pixie
import pkg/pixie/fonts
import pkg/opengl
import pkg/windy

import utils, context
import commons

import pretty

type

  GlyphPosition* = object
    ## Represents a glyph position after typesetting.
    fontId*: FontId
    fontSize*: float32
    rune*: Rune
    pos*: Vec2       # Where to draw the image character.
    rect*: Rect
    descent*: float32

var
  typefaceTable*: Table[TypefaceId, Typeface]
  # typefaceLookupTable*: Table[Typeface, TypefaceId]

  fontTable*: Table[FontId, Font]
  fontLookupTable*: Table[Font, FontId]

  glyphOffsets*: Table[Hash, Vec2]

iterator glyphs*(arrangement: GlyphArrangement): GlyphPosition =
  var idx = 0
  for (span, fontId) in zip(arrangement.spans, arrangement.fonts):
    block spanners:
      let
        span = span[0] .. span[1]
        font = fontTable[fontId]
        typeface = font.typeface

      while idx < arrangement.runes.len():
        let
          pos = arrangement.positions[idx]
          rune = arrangement.runes[idx]
          selection = arrangement.selectionRects[idx]

        echo "glyph:"
        print typeface.descent() / typeface.scale * font.size
        print typeface.ascent() / typeface.scale * font.size
        print typeface.lineGap() / typeface.scale * font.size
        print typeface.lineHeight() / typeface.scale * font.size

        yield GlyphPosition(
          fontId: fontId,
          fontSize: font.size,
          rune: rune,
          pos: pos,
          rect: selection,
          descent: typeface.descent() / typeface.scale * font.size,
        )

        if idx notin span:
          break
        else:
          idx.inc()

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
  pxfont.size = font.size
  pxfont.typeface = typeface
  pxfont.textCase = parseEnum[TextCase]($font.fontCase)
  # copy rest of the fields with matching names
  for pn, a in fieldPairs(pxfont[]):
    for fn, b in fieldPairs(font):
      when pn == fn:
        a = b
  if font.lineHeight < 0.0:
    pxfont.lineHeight = autoLineHeight
  fontTable[id] = pxfont
  fontLookupTable[pxfont] = id
  result = id
  echo "getFont:input: "
  print font
  echo "getFont: ", result
  print pxfont.size
  print pxfont.lineHeight

# proc loadGlyph*(font: GlyphFont):  =

proc hash*(glyph: GlyphPosition): Hash {.inline.} =
  result = hash((
    2344,
    glyph.fontId,
    glyph.rune,
    # (glyph.subPixelShift*100).int,
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
      wh = glyph.rect.wh
      w = glyph.rect.w.int
      h = glyph.rect.h.int

    font.paint = whiteColor

    let
      text = $glyph.rune
      arrangement = typeset(@[newSpan(text, font)], bounds=wh)
      snappedBounds = arrangement.computeBounds().snapToPixels()
      image = newImage(snappedBounds.w.int, snappedBounds.h.int)
    
    try:
      # let path = getGlyphPath(font.typeface, glyph.rune)
      # image.fillPath(path, rgba(255, 255, 255, 255))
      # var m = rotate(180.0'f32)
      # var m = translate(-snappedBounds.xy)
      # var m =  translate(-snappedBounds.xy) * rotate(180.0'f32)
      var m = translate(-snappedBounds.xy)
      image.fillText(arrangement, m)
      image.rotate90()
      image.rotate90()
      image.flipHorizontal()
      ctx.putImage(hashFill, image)
      image.writeFile("pics/" & text & ".png")
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

  echo "getTypeset:"
  echo "snappedBounds: ", snappedBounds
  # echo "arrangement: "
  # print arrangement
  result = GlyphArrangement(
    lines: arrangement.lines,
    spans: arrangement.spans,
    fonts: arrangement.fonts.mapIt(fontLookupTable[it]),
    runes: arrangement.runes,
    positions: arrangement.positions,
    selectionRects: arrangement.selectionRects,
  )
  echo "font: "
  print arrangement.fonts[0].size
  print arrangement.fonts[0].lineHeight
  echo "arrangement: "
  print result
