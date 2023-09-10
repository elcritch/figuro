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

  GlyphPosition* = ref object
    ## Represents a glyph position after typesetting.
    fontId*: FontId
    font*: Font
    fontSize*: float32
    rune*: Rune
    pos*: Vec2       # Where to draw the image character.
    rect*: Rect
    descent*: float32

var
  typefaceTable*: Table[TypefaceId, Typeface]

  fontTable* {.threadvar.}: Table[FontId, Font]


proc convertFont*(font: GlyphFont): (FontId, Font) =
  let
    id = FontId hash(font)
    typeface = typefaceTable[font.typefaceId]

  if not fontTable.hasKey(id):
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
      pxfont.lineHeight = pxfont.defaultLineHeight()

    fontTable[id] = pxfont
    result = (id, pxfont)
    # echo "getFont:input: "
    # print font
  else:
    result = (id, fontTable[id])

iterator glyphs*(arrangement: GlyphArrangement): GlyphPosition =
  var idx = 0
  if arrangement != nil:
    for (span, gfont) in zip(arrangement.spans, arrangement.fonts):
      let
        span = span[0] .. span[1]
        (fontId, font) = convertFont(gfont)

      while idx < arrangement.runes.len():
        let
          pos = arrangement.positions[idx]
          rune = arrangement.runes[idx]
          selection = arrangement.selectionRects[idx]

        yield GlyphPosition(
          fontId: fontId,
          font: font,
          fontSize: font.size,
          rune: rune,
          pos: pos,
          rect: selection,
          descent: font.lineHeight,
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
    typeface = readTypeface(DataDirPath.string / name)
    id = TypefaceId hash(typeface)
  typefaceTable[id] = typeface
  result = id
  echo "getTypeFace: ", result

# proc loadGlyph*(font: GlyphFont):  =

proc hash*(glyph: GlyphPosition): Hash {.inline.} =
  result = hash((
    2344,
    glyph.font.hash(),
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

    let
      text = $glyph.rune
      arrangement = typeset(@[newSpan(text, font)], bounds=wh)
      snappedBounds = arrangement.computeBounds().snapToPixels()
      lh = font.defaultLineHeight()
      bounds = rect(snappedBounds.x, snappedBounds.h + snappedBounds.y - lh,
                    snappedBounds.w, lh)
      image = newImage(bounds.w.int, bounds.h.int)
    
    try:
      font.paint = whiteColor
      var m = translate(-bounds.xy)
      image.fillText(arrangement, m)
      ctx.putImage(hashFill, image)
      result = some hashFill
    except PixieError:
      result = none Hash

proc getTypeset*(text: string, gfont: GlyphFont, box: Box): GlyphArrangement =
  let
    rect = box.scaled()
    wh = rect.wh
    (_, pf) = convertFont(gfont)

  assert pf.isNil == false
  # echo "FONTS: ", pf.repr
  let
    arrangement = typeset(@[newSpan(text, pf)], bounds = rect.wh)

  # echo "getTypeset:"
  # echo "snappedBounds: ", snappedBounds
  # echo "arrangement: "
  # print arrangement
  result = GlyphArrangement(
    lines: arrangement.lines,
    spans: arrangement.spans,
    fonts: arrangement.fonts.mapIt(gfont), ## FIXME
    runes: arrangement.runes,
    positions: arrangement.positions,
    selectionRects: arrangement.selectionRects,
  )
  # echo "font: "
  # print arrangement.fonts[0].size
  # print arrangement.fonts[0].lineHeight
  # echo "arrangement: "
  # print result
