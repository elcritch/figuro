
import glyphs
export glyphs

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

type MainCallback* = proc() {.closure.}

when defined(nimscript):
  proc setWindowTitle*(title: string) =
    discard

  proc getWindowTitle*(): string =
    discard

  proc getTypeface*(name: string): TypefaceId =
    discard

  proc getFont*(font: GlyphFont): FontId =
    discard

  proc getTypeset*(text: string, font: FontId, box: Box): GlyphArrangement =
    discard

else:
  from fontutils import getTypefaceImpl, getTypesetImpl
  ## these are set at runtime by the opengl window

  proc setWindowTitle*(title: string) =
    discard

  proc getWindowTitle*(): string =
    discard

  proc getTypeface*(name: string): TypefaceId =
    ## loads typeface from pixie
    fontutils.getTypefaceImpl(name)

  proc getTypeset*(
      box: Box, spans: openArray[(UiFont, string)], hAlign = Left, vAlign = Top
  ): GlyphArrangement =
    fontutils.getTypesetImpl(box, spans, hAlign, vAlign)
