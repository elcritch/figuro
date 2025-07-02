import std/[options, unicode, strutils, tables, times]
import std/[os, json]
import std/terminal

import pkg/pixie
import pkg/windex
import pkg/sigils/weakrefs

import pkg/chronicles

import ../commons
import ../common/rchannels
import ../common/wincfgs

import ./utils/glutils
import ./utils/baserenderer
import ./opengl/renderer

when defined(figuroWindex):
  import ./openglWindex
elif defined(figuroSiwin):
  import ./openglSiwin
else:
  import ./openglWindex

export baserenderer

proc createRenderer*[F](frame: WeakRef[F]): Renderer =

  let atlasSize = 2048 shl (app.uiScale.round().toInt() + 1)
  let window = newRendererWindow(frame)
  let renderer = newOpenGLRenderer(window, frame, atlasSize)

  # window defaults
  frame[].windowInfo.focused = true
  frame[].windowInfo.autoSavePosition = true

  if app.autoUiScale:
    let scale = renderer.window.getScaleInfo()
    app.uiScale = min(scale.x, scale.y)

  renderer.window.setWindowSize(frame)

  if frame[].windowInfo.autoSavePosition:
    let winCfg = frame.loadLastWindow()
    echo "LOADED WIN_CFG: ", winCfg.size
    if winCfg.size.x != 0 and winCfg.size.y != 0:
      let sz = vec2(x= winCfg.size.x.float32, y= winCfg.size.y.float32).descaled()
      frame[].windowInfo.box.w = sz.x.UiScalar
      frame[].windowInfo.box.h = sz.y.UiScalar
      renderer.window.setWindowSize(frame)
      let pos = vec2(x= winCfg.pos.x.float32, y= winCfg.pos.y.float32).descaled()
      frame[].windowInfo.box.x = pos.x.UiScalar
      frame[].windowInfo.box.y = pos.y.UiScalar
      renderer.window.setWindowPos(frame)

  window.configureWindowEvents(renderer)

  renderer.window.frame[].windowInfo.running = true
  app.requestedFrame.inc

  renderer.window.setVisible(true)
  return renderer
