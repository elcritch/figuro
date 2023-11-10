import std/[strformat, times, strutils]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windy

import utils
import commons

# import ../patches/textboxes 
var
  cursorDefault*: Cursor
  cursorPointer*: Cursor
  cursorGrab*: Cursor
  cursorNSResize*: Cursor

when defined(glDebugMessageCallback):
  import strformat, strutils

static:
  ## compile check to ensure windy buttons don't change on us
  for i in 0..windy.Button.high().int:
    assert $Button(i) == $UiButton(i)

proc toUi*(wbtn: windy.ButtonView): UiButtonView =
  when defined(nimscript):
    for b in set[Button](wbtn):
      result.incl UiButton(b.int)
  else:
    copyMem(addr result, unsafeAddr wbtn, sizeof(ButtonView))

proc getScaleInfo*(window: Window): ScaleInfo =
  let scale = window.contentScale()
  result.x = scale
  result.y = scale

proc updateWindowSize*(window: Window) =
  app.requestedFrame.inc

  var cwidth, cheight: cint
  let size = window.size()
  app.windowRawSize.x = size.x.toFloat
  app.windowRawSize.y = size.y.toFloat

  app.minimized = window.minimized()
  app.pixelRatio = window.contentScale()

  glViewport(0, 0, cwidth, cheight)

  let scale = window.getScaleInfo()
  if app.autoUiScale:
    app.uiScale = min(scale.x, scale.y)

  let sz = app.windowRawSize.descaled()
  # TODO: set screen logical offset too?
  app.windowSize.w = sz.x
  app.windowSize.h = sz.y

proc startOpenGL*(window: Window, openglVersion: (int, int)) =

  let scale = window.getScaleInfo()
  
  if app.autoUiScale:
    app.uiScale = min(scale.x, scale.y)

  if app.fullscreen:
    window.fullscreen = app.fullscreen
  else:

    app.windowRawSize = app.windowSize.wh.scaled()
    window.size = ivec2(app.windowRawSize)

  if window.isNil:
    quit(
      "Failed to open window. GL version:" &
      &"{openglVersion[0]}.{$openglVersion[1]}"
    )

  window.makeContextCurrent()

  when not defined(emscripten):
    loadExtensions()

  openglDebug()

  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBlendFuncSeparate(
    GL_SRC_ALPHA,
    GL_ONE_MINUS_SRC_ALPHA,
    GL_ONE,
    GL_ONE_MINUS_SRC_ALPHA
  )

  # app.lastDraw = getTicks()
  # app.lastTick = app.lastDraw
  app.focused = true

  useDepthBuffer(false)

  updateWindowSize(window)
