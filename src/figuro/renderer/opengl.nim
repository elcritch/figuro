import std/[options, unicode, hashes, strformat, strutils, tables, times]
import std/[os, json]
import std/terminal

import pkg/opengl
import pkg/sigils/weakrefs

import pkg/chronicles 

import ../commons
import ../common/rchannels
# import ../inputs
import ./opengl/utils
import ./opengl/renderer

export Renderer, runRendererLoop

proc startOpenGL*(frame: WeakRef[AppFrame], window: RendererWindow, openglVersion: (int, int)) =

  makeContextCurrent(window)

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
  frame[].appWindow.focused = true

  useDepthBuffer(false)
  # updateWindowSize(frame, window)

proc createRenderer*[F](frame: WeakRef[F]): Renderer =
  let winCfg = frame.loadLastWindow()
  if winCfg.size.x != 0 and winCfg.size.y != 0:
    let sz = vec2(x= winCfg.size.x.float32, y= winCfg.size.y.float32).descaled()
    frame[].appWindow.box.w = sz.x.UiScalar
    frame[].appWindow.box.h = sz.y.UiScalar
  else:
    frame[].appWindow.box.w = 100'ui
    frame[].appWindow.box.h = 100'ui
  frame[].appWindow.running = true
  echo "WINDOW:size: ", winCfg.size

  let atlasSize = 1024 shl (app.uiScale.round().toInt() + 1)
  let window = createWindow(frame)
  startOpenGL(frame, window, openglVersion)
  let renderer = newRenderer(frame, window, 1.0, atlasSize)

  app.requestedFrame.inc

  return renderer
