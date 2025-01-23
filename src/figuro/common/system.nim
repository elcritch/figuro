
import glyphs
export glyphs
import nodes/uinodes

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
  import fontutils
  export TypeFaceKinds
  ## these are set at runtime by the opengl window

  proc setWindowTitle*(frame: AppFrame, title: string) =
    discard

  proc getWindowTitle*(frame: AppFrame, ): string =
    discard

  proc getTypeface*(name: string): TypefaceId =
    ## loads typeface from pixie
    getTypefaceImpl(name)

  proc getTypeface*(name, data: string, kind: TypeFaceKinds): TypefaceId =
    getTypefaceImpl(name, data, kind)

  proc getTypeset*(
      box: Box, spans: openArray[(UiFont, string)], hAlign = Left, vAlign = Top
  ): GlyphArrangement =
    getTypesetImpl(box, spans, hAlign, vAlign)
