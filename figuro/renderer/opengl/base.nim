import std/[strformat, times, strutils]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windy
import pkg/boxy

import utils, context, render
import commons

# import ../patches/textboxes 

when defined(glDebugMessageCallback):
  import strformat, strutils

const
  deltaTick: int64 = 1_000_000_000 div 240

var
  dpi*: float32
  programStartTime* = epochTime()
  # fpsTimeSeries = newTimeSeries()
  # tpsTimeSeries = newTimeSeries()
  prevFrameTime* = programStartTime
  frameTime* = prevFrameTime
  dt*, dtAvg*, fps*, tps*, avgFrameTime*: float64

var
  cursorDefault*: Cursor
  cursorPointer*: Cursor
  cursorGrab*: Cursor
  cursorNSResize*: Cursor

var
  eventTimePre* = epochTime()
  eventTimePost* = epochTime()

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

  let scale = window.getScaleInfo()
  if app.autoUiScale:
    app.uiScale = min(scale.x, scale.y)

  let sz = app.windowRawSize.descaled()
  # TODO: set screen logical offset too?
  app.windowSize.w = sz.x
  app.windowSize.h = sz.y

proc preInput*() =
  # var x, y: float64
  # window.getCursorPos(addr x, addr y)
  # mouse.setMousePos(x, y)
  discard

proc postInput*() =
  discard

proc startRender*(window: Window, openglVersion: (int, int)) =

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

  # app.lastDraw = getTicks()
  # app.lastTick = app.lastDraw
  app.focused = true

  updateWindowSize(window)
