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
    fontSize*: float32
    rune*: Rune
    pos*: Vec2       # Where to draw the image character.
    rect*: Rect
    descent*: float32


var
  glyphImageChan* = newChan[(Hash, Image)](1000)
  glyphImageCached*: HashSet[Hash]

proc toSlices*[T: SomeInteger](a: openArray[(T, T)]): seq[Slice[T]] =
  a.mapIt(it[0]..it[1])

proc hash*(tp: Typeface): Hash =
  var h = Hash(0)
  h = h !& hash tp.filePath
  result = !$h


proc hash*(glyph: GlyphPosition): Hash {.inline.} =
  result = hash((
    2344,
    glyph.fontId,
    glyph.rune,
  ))

proc getId*(typeface: Typeface): TypefaceId =
  TypefaceId typeface.hash()

# proc getId*(font: Font): FontId =
#   FontId font.hash()

iterator glyphs*(arrangement: GlyphArrangement): GlyphPosition =
  # threads: RenderThread

  var idx = 0
  # if arrangement != nil:

  var mlh = 0.0 # maximum line height per row (though this does in total?)
  for f in arrangement.fonts:
    mlh = max(f.lineHeight, mlh)

  block:
    for i, (span, gfont) in zip(arrangement.spans, arrangement.fonts):
      while idx < arrangement.runes.len():
        let
          pos = arrangement.positions[idx]
          rune = arrangement.runes[idx]
          selection = arrangement.selectionRects[idx]

        yield GlyphPosition(
          fontId: gfont.fontId,
          fontSize: gfont.size,
          rune: rune,
          pos: pos,
          rect: selection,
          descent: gfont.lineHeight + (mlh - gfont.lineHeight)/4, ##\
            ## adjust the line height for varying sized fonts based
            ## off the max line height and the current font's lh
            ## the 1/4 is empirical, but sorta makes sense
        )

        # echo "GLYPH: ", rune, " pos: ", pos, " sel: ", selection, " lh: ", gfont.lineHeight, " mlh: ", flh, " : ", flh - gfont.lineHeight
        idx.inc()
        if idx notin span:
          break

var
  typefaceTable*: Table[TypefaceId, Typeface]
  fontTable* {.threadvar.}: Table[FontId, Font]

proc generateGlyphImage*(arrangement: GlyphArrangement) =
  ## returns Glyph's hash, will generate glyph if needed
  ## 
  ## Font Glyphs are generated with Bottom vAlign and Center hAlign
  ## this puts the glyphs in the right position
  ## so that the renderer doesn't need to figure out adjustments
  threads: MainThread

  for glyph in arrangement.glyphs():
    if unicode.isWhiteSpace(glyph.rune):
      # echo "skipped:rune: ", glyph.rune, " ", glyph.rune.int
      continue

    let hashFill = glyph.hash()

    if hashFill notin glyphImageCached:
      let
        wh = glyph.rect.wh
        fontId = glyph.fontId
        font = fontTable[fontId]
        text = $glyph.rune
        arrangement = pixie.typeset(
          @[newSpan(text, font)],
          bounds = wh,
          hAlign = CenterAlign,
          vAlign = BottomAlign,
          wrap = false
        )
      var
        snappedBounds = arrangement.computeBounds().snapToPixels()
      # echo "GEN IMG: ", glyph.rune, " wh: ", wh, " snapped: ", snappedBounds

      let
        lh = font.defaultLineHeight()
        bounds = rect(0, 0,
                      snappedBounds.w + snappedBounds.x, lh)
        image = newImage(bounds.w.int, bounds.h.int)
      # echo "GEN IMG: ", glyph.rune, " bounds: ", bounds

      try:
        font.paint = whiteColor
        # var m = translate(bounds.xy)
        image.fillText(arrangement)

        # put into cache
        glyphImageCached.incl hashFill
        glyphImageChan.send(unsafeIsolate (hashFill, image,))

      except PixieError:
        discard

proc getTypeface*(name: string): FontId =
  threads: MainThread

  let
    typefacePath = DataDirPath.string / name
    typeface = readTypeface(typefacePath)
    id = typeface.getId()

  typefaceTable[id] = typeface
  result = id
  # echo "typefaceTable:addr: ", getThreadId()
  # echo "getTypeFace: ", result
  # echo "getTypeFace:res: ", typefaceTable[id].hash()

proc convertFont*(font: UiFont): (FontId, Font) =
  threads: MainThread
  # echo "convertFont: ", font.typefaceId
  # echo "typefaceTable:addr: ", getThreadId()
  let
    id = font.getId()
    typeface = typefaceTable[font.typefaceId]
  # echo "convertFont:res: ", typeface.hash

  if not fontTable.hasKey(id):
    var pxfont = newFont(typeface)
    pxfont.size = font.size.scaled
    pxfont.typeface = typeface
    pxfont.textCase = parseEnum[TextCase]($font.fontCase)
    # copy rest of the fields with matching names
    for pn, a in fieldPairs(pxfont[]):
      for fn, b in fieldPairs(font):
        when pn == fn:
          when b is UICoord:
            a = b.scaled()
          else:
            a = b
    if font.lineHeight < 0.0'ui:
      pxfont.lineHeight = pxfont.defaultLineHeight()
    
    fontTable[id] = pxfont
    result = (id, pxfont)
    # echo "getFont:input: "
    # print font
  else:
    result = (id, fontTable[id])

import sugar

proc getTypeset*(
    box: Box,
    uiSpans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top
): GlyphArrangement =
  threads: MainThread

  var
    wh = box.scaled().wh
    sz = uiSpans.mapIt(it[0].size.float)
    minSz = sz.foldl(max(a,b), 0.0)

  var spans: seq[Span]
  var pfs: seq[Font]
  var gfonts: seq[GlyphFont]
  for (uiFont, txt) in uiSpans:
    let (_, pf) = uiFont.convertFont()
    pfs.add(pf)
    spans.add(newSpan(txt, pf))
    assert not pf.typeface.isNil
    gfonts.add GlyphFont(fontId: uiFont.getId(),
                          lineHeight: pf.lineHeight)

  var ha: HorizontalAlignment
  case hAlign:
  of Left: ha = LeftAlign
  of Center: ha = CenterAlign
  of Right: ha = RightAlign

  var va: VerticalAlignment
  case vAlign:
  of Top: va = TopAlign
  of Middle: va = MiddleAlign
  of Bottom: va = BottomAlign

  let arrangement =
    pixie.typeset(spans, bounds = wh, hAlign = ha, vAlign = va)

  # echo "getTypeset:"
  # echo "getTypeset:wh: ", wh
  # print arrangement

  var
    lines = newSeqOfCap[Slice[int]](arrangement.lines.len())
    spanSlices = newSeqOfCap[Slice[int]](arrangement.spans.len())
    selectionRects = newSeqOfCap[Rect](arrangement.selectionRects.len())
    # a.mapIt(it[0]..it[1])
  for line in arrangement.lines:
    lines.add line[0]..line[1]
  for span in arrangement.spans:
    spanSlices.add span[0]..span[1]
  for rect in arrangement.selectionRects:
    selectionRects.add rect

  result = GlyphArrangement(
    lines: lines, # arrangement.lines.toSlices(),
    spans: spanSlices, # arrangement.spans.toSlices(),
    fonts: gfonts,
    runes: arrangement.runes,
    positions: arrangement.positions,
    selectionRects: selectionRects,
  )
  # echo "arrangement:\n", result.repr
  # print result

  result.generateGlyphImage()
  # echo "font: "
  # print arrangement.fonts[0].size
  # print arrangement.fonts[0].lineHeight
  # echo "arrangement: "
  # print result
