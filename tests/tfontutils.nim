
import unittest
import figuro
import figuro/renderer/opengl/fontutils

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22'ui)
  smallFont = UiFont(typefaceId: typeface, size: 12'ui)

import pretty

suite "fontutils":

  test "basic":
    let box = initBox(10, 10, 400, 100)
    let spans = {font: "hi",
                  smallFont: "AA",
                  font: "AA"}
    let textLayout = internal.getTypeset(box, spans, 
              hAlign = FontHorizontal.Left,
              vAlign = FontVertical.Top)

    print textLayout

    let
      fontId = textLayout.fonts[0].fontId
      smallFontId = textLayout.fonts[1].fontId
      glyphs = textLayout.glyphs().toSeq()

    for glyph in glyphs:
      print glyph

    check glyphs[0].fontId == fontId 
    check glyphs[1].fontId == fontId 
    check glyphs[2].fontId == smallFontId 
    check glyphs[3].fontId == smallFontId 
