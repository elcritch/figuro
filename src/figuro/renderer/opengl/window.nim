import std/[strformat, times, strutils]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windex

import utils
import glcommons
import ../../common/nodes/uinodes

import pkg/sigils/weakrefs

export AppFrame

# import ../patches/textboxes 
var
  cursorDefault*: Cursor
  cursorPointer*: Cursor
  cursorGrab*: Cursor
  cursorNSResize*: Cursor

when defined(glDebugMessageCallback):
  import strformat, strutils

static:
  ## compile check to ensure windex buttons don't change on us
  for i in 0 .. windex.Button.high().int:
    assert $Button(i) == $UiButton(i)

proc toUi*(wbtn: windex.ButtonView): UiButtonView =
  when defined(nimscript):
    for b in set[Button](wbtn):
      result.incl UiButton(b.int)
  else:
    copyMem(addr result, unsafeAddr wbtn, sizeof(ButtonView))

proc getScaleInfo*(window: Window): ScaleInfo =
  let scale = window.contentScale()
  result.x = scale
  result.y = scale

proc updateWindowSize*(frame: WeakRef[AppFrame], window: Window) =
  app.requestedFrame.inc

  var cwidth, cheight: cint
  let size = window.size()
  frame[].windowRawSize.x = size.x.toFloat
  frame[].windowRawSize.y = size.y.toFloat
  frame[].minimized = window.minimized()
  app.pixelRatio = window.contentScale()

  glViewport(0, 0, cwidth, cheight)

  let scale = window.getScaleInfo()
  if app.autoUiScale:
    app.uiScale = min(scale.x, scale.y)

  let sz = frame[].windowRawSize.descaled()
  # TODO: set screen logical offset too?
  frame[].windowSize.w = sz.x
  frame[].windowSize.h = sz.y

proc startOpenGL*(frame: WeakRef[AppFrame], window: Window, openglVersion: (int, int)) =
  assert not frame.isNil
  if frame[].fullscreen:
    window.fullscreen = frame[].fullscreen
  else:
    frame[].windowRawSize = frame[].windowSize.wh.scaled()
    window.size = ivec2(frame[].windowRawSize)

  window.visible = true

  if window.isNil:
    quit(
      "Failed to open window. GL version:" & &"{openglVersion[0]}.{$openglVersion[1]}"
    )

  window.makeContextCurrent()

  when not defined(emscripten):
    loadExtensions()

  openglDebug()

  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBlendFuncSeparate(
    GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA
  )

  # app.lastDraw = getTicks()
  # app.lastTick = app.lastDraw
  frame[].focused = true

  useDepthBuffer(false)
  updateWindowSize(frame, window)
