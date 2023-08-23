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

proc hashFontFill*(node: Node, pos: GlyphPosition, subPixelShift: float32): Hash {.inline.} =
  result = hash((
    2344,
    node.textStyle.fontFamily,
    pos.rune,
    (node.textStyle.fontSize*100).int,
    (subPixelShift*100).int,
    0
  ))

proc hashFontStroke*(node: Node, pos: GlyphPosition, subPixelShift: float32): Hash {.inline.} =
  result = hash((
    9812,
    node.textStyle.fontFamily,
    pos.rune,
    (node.textStyle.fontSize*100).int,
    (subPixelShift*100).int,
    node.stroke.weight
  ))