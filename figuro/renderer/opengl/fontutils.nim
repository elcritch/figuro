import std/[os, unicode, strutils, sets, hashes]
import std/isolation

import pkg/vmath
import pkg/pixie
import pkg/pixie/fonts
import pkg/windy
import pkg/threading/channels

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
  # threads: RenderThread

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

proc hash*(glyph: GlyphPosition): Hash {.inline.} =
  result = hash((
    2344,
    glyph.font.hash(),
    glyph.rune,
    # (glyph.subPixelShift*100).int,
    0
  ))

proc getTypeface*(name: string): FontId =
  threads: MainThread

  let
    typeface = readTypeface(DataDirPath.string / name)
    id = TypefaceId hash(typeface)
  typefaceTable[id] = typeface
  result = id
  echo "getTypeFace: ", result

var
  glyphImageChan* = newChan[(Hash, Image)](1000)
  glyphImageCached*: HashSet[Hash]

proc generateGlyphImage*(arrangement: GlyphArrangement) =
  threads: MainThread
  ## returns Glyph's hash, will generate glyph if needed

  for glyph in arrangement.glyphs():
    let hashFill = glyph.hash()

    if hashFill notin glyphImageCached:
      let
        wh = glyph.rect.wh
        font = glyph.font

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

        # put into cache
        glyphImageCached.incl hashFill
        glyphImageChan.send(unsafeIsolate (hashFill, image,))

      except PixieError:
        discard

proc getTypeset*(
    text: string,
    gfont: GlyphFont,
    box: Box
): GlyphArrangement =
  threads: MainThread

  let
    rect = box.scaled()
    wh = rect.wh
    (_, pf) = convertFont(gfont)

  assert pf.isNil == false
  # echo "FONTS: ", pf.repr
  let arrangement = typeset(@[newSpan(text, pf)], bounds = rect.wh)

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

  result.generateGlyphImage()
  # echo "font: "
  # print arrangement.fonts[0].size
  # print arrangement.fonts[0].lineHeight
  # echo "arrangement: "
  # print result
