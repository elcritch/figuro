import std/[options, unicode, strutils, tables, times]
import std/[os, json]
import std/terminal

import pkg/pixie
import pkg/windex
import pkg/sigils/weakrefs

import pkg/chronicles

import ../commons
import ../common/rchannels
# import ../inputs
import ./opengl/glwindow
import ./opengl/renderer
import ./opengl/utils
import ./opengl/wutils

export Renderer, runRendererLoop

proc createRenderer*[F](frame: WeakRef[F]): Renderer =

  let window = newWindow("Figuro", ivec2(1280, 800), visible = false)
  let style: WindowStyle = frame[].windowStyle.convertStyle()
  let winCfg = frame.loadLastWindow()

  if app.autoUiScale:
    let scale = window.getScaleInfo()
    app.uiScale = min(scale.x, scale.y)

  window.`style=`(style)
  window.`pos=`(winCfg.pos)
  if winCfg.size.x != 0 and winCfg.size.y != 0:
    let sz = vec2(x= winCfg.size.x.float32, y= winCfg.size.y.float32).descaled()
    frame[].window.box.w = sz.x.UiScalar
    frame[].window.box.h = sz.y.UiScalar

  let atlasSize = 1024 shl (app.uiScale.round().toInt() + 1)
  startOpenGL(frame, window, openglVersion)

  let renderer = newRenderer(frame, window, 1.0, atlasSize)
  let renderCb = proc() =
    pollAndRender(renderer, poll = false)

  configureWindowEvents(
    window,
    renderer.uxInputList,
    frame,
    renderCb,
  )
  renderer.frame[].window.running = true
  app.requestedFrame.inc

  return renderer
