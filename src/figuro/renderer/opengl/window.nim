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

proc startOpenGL*(frame: WeakRef[AppFrame], window: Window, openglVersion: (int, int)) =
  assert not frame.isNil
  if frame[].window.fullscreen:
    window.fullscreen = frame[].window.fullscreen
  else:
    window.size = ivec2(frame[].window.box.wh.scaled())

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
  frame[].window.focused = true

  useDepthBuffer(false)
  # updateWindowSize(frame, window)
