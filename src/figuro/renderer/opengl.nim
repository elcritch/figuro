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

  let atlasSize = 1024 shl (app.uiScale.round().toInt() + 1)

  let renderer = newRenderer(frame, 1.0, atlasSize)
  frame[].windowInfo.focused = true

  if app.autoUiScale:
    let scale = renderer.getScaleInfo()
    app.uiScale = min(scale.x, scale.y)

  let winCfg = frame.loadLastWindow()
  if winCfg.size.x != 0 and winCfg.size.y != 0:
    let sz = vec2(x= winCfg.size.x.float32, y= winCfg.size.y.float32).descaled()
    frame[].windowInfo.box.w = sz.x.UiScalar
    frame[].windowInfo.box.h = sz.y.UiScalar

  configureWindowEvents(renderer)
  renderer.frame[].windowInfo.running = true
  app.requestedFrame.inc

  return renderer
