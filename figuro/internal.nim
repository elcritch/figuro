
import std/locks
import common/glyphs

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

type
  MainCallback* = proc() {.closure.}


type
  UiEvent* = tuple[cond: Cond, lock: Lock]

when defined(nimscript):
    proc setWindowTitle*(title: string) = discard
    proc getWindowTitle*(): string = discard
    proc getTypeface*(name: string): TypefaceId = discard
    proc getFont*(font: GlyphFont): FontId = discard
    proc getTypeset*(text: string, font: FontId, box: Box): GlyphArrangement = discard
else:

  from renderer/opengl/fontutils import getTypeface, getFont, getTypeset
  ## these are set at runtime by the opengl window

  proc setWindowTitle*(title: string) =
    discard
  proc getWindowTitle*(): string =
    discard

  proc getTypeface*(name: string): TypefaceId =
    ## loads typeface from pixie
    fontutils.getTypeface(name)

  proc getFont*(font: GlyphFont): FontId =
    ## loads fonts from pixie
    fontutils.getFont(font)

  proc getTypeset*(text: string, font: FontId, box: Box): GlyphArrangement =
    fontutils.getTypeset(text, font, box)

  var
    uiAppEvent* {.runtimeVar.}: UiEvent
    uiRenderEvent* {.runtimeVar.}: UiEvent

proc initUiEvent*(): UiEvent =
  result.lock.initLock()
  result.cond.initCond()

proc trigger*(evt: var UiEvent) =
  withLock(evt.lock):
    signal(evt.cond)

proc wait*(evt: var UiEvent) =
  withLock(evt.lock):
    wait(evt.cond, evt.lock)
