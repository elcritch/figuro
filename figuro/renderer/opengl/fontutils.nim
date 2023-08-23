import std/[os, strformat, unicode, times, strutils, hashes]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windy

import utils, context, render
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

proc loadTypeface*(name: string): FontId =
    let
      typeface = readTypeface(DataDirPath / name)
      id = TypefaceId hash(typeface)
    typefaceTable[id] = typeface

proc loadFont*(font: GlyphFont): FontId =
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
  fontTable[id] = pxfont

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

  
    # glyphOffsets[hashFill] = glyphOffset

  # if node.stroke.weight > 0:
  #   hashStroke = node.hashFontStroke(pos, subPixelShift)

  #   if hashStroke notin ctx.entries:
  #     var
  #       glyph = font.typeface.glyphs[pos.character]
  #       glyphOffset: Vec2
  #     let
  #       glyphFill = font.getGlyphImage( glyph, glyphOffset, subPixelShift=subPixelShift)

  #     let glyphStroke = glyphFill.outlineBorder(node.stroke.weight.int)
  #     ctx.putImage(hashStroke, glyphStroke)


# proc hashFontStroke*(node: Node, pos: GlyphPosition, subPixelShift: float32): Hash {.inline.} =
#   result = hash((
#     9812,
#     node.textStyle.fontFamily,
#     pos.rune,
#     (node.textStyle.fontSize*100).int,
#     (subPixelShift*100).int,
#     node.stroke.weight
#   ))