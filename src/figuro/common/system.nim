import pkg/threading/channels

import nodes/uinodes
import inputs
import fonttypes
export fonttypes

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

type MainCallback* = proc() {.closure.}

when not defined(nimscript):
  import fontutils
  export TypeFaceKinds
  ## these are set at runtime by the opengl window

  proc getWindowTitle*(frame: AppFrame): string =
    frame.windowTitle

  proc setWindowTitle*(frame: AppFrame, title: sink string) =
    if frame.getWindowTitle() != title:
      frame.rendInputList.send(RenderSetTitle(name= move title))

  proc getTypeface*(name: string): TypefaceId =
    ## loads typeface from pixie
    getTypefaceImpl(name)

  proc getTypeface*(name, data: string, kind: TypeFaceKinds): TypefaceId =
    getTypefaceImpl(name, data, kind)

  proc getTypeset*(
      box: Box, spans: openArray[(UiFont, string)], hAlign = Left, vAlign = Top
  ): GlyphArrangement =
    getTypesetImpl(box, spans, hAlign, vAlign)
