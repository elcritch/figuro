import ./rchannels

import nodes/uinodes
import inputs
import fonttypes
import pixie
import chronicles
import windex

export fonttypes

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

when (NimMajor, NimMinor, NimPatch) < (2, 2, 0):
  {.passc:"-fpermissive -Wno-incompatible-function-pointer-types".}
  {.passl:"-fpermissive -Wno-incompatible-function-pointer-types".}

when not defined(nimscript):
  import fontutils
  export TypeFaceKinds
  ## these are set at runtime by the opengl window

  proc getWindowTitle*(frame: AppFrame): string =
    frame.windowTitle

  proc setWindowTitle*(frame: AppFrame, title: sink string) =
    if frame.getWindowTitle() != title:
      frame.rendInputList.push(RenderSetTitle(name= move title))

  proc getTypeface*(name: string): TypefaceId =
    ## loads typeface from pixie
    getTypefaceImpl(name)

  proc getTypeface*(name, data: string, kind: TypeFaceKinds): TypefaceId =
    getTypefaceImpl(name, data, kind)

  proc getLineHeight*(font: UiFont): UiScalar =
    getLineHeightImpl(font)

  proc getTypeset*(
      box: Box, spans: openArray[(UiFont, string)], hAlign = Left, vAlign = Top, minContent = false, wrap = true
  ): GlyphArrangement =
    getTypesetImpl(box, spans, hAlign, vAlign, minContent, wrap)

  proc clipboardText*(): string =
    when defined(linux):
      warn "clipboardText is not implemented on linux"
    else:
      windex.getClipboardString()

  proc clipboardSet*(str: string) =
    when defined(linux):
      warn "clipboardSet is not implemented on linux"
    else:
      windex.setClipboardString(str)

  proc clipboardImage*(): Image =
    when defined(linux):
      warn "clipboardImage is not implemented on linux"
    else:
      windex.getClipboardImage()

  when defined(clipboardImage):
    proc clipboardSet*(img: Image) =
      when defined(linux):
        warn "clipboardSet is not implemented on linux"
      else:
        windex.setClipboardImage(img)
