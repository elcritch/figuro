import std/[os, strformat, unicode, times]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windy

import perf, utils, context, draw
import commons

# import ../patches/textboxes 

when defined(glDebugMessageCallback):
  import strformat, strutils

const
  deltaTick: int64 = 1_000_000_000 div 240

var
  dpi*: float32
  programStartTime* = epochTime()
  fpsTimeSeries = newTimeSeries()
  tpsTimeSeries = newTimeSeries()
  prevFrameTime* = programStartTime
  frameTime* = prevFrameTime
  dt*, dtAvg*, fps*, tps*, avgFrameTime*: float64
  lastDraw, lastTick: int64

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
  requestedFrame.inc

  var cwidth, cheight: cint
  let size = window.size()
  windowSize.x = size.x.toFloat
  windowSize.y = size.y.toFloat

  app.minimized = window.minimized()
  pixelRatio = window.contentScale()

  glViewport(0, 0, cwidth, cheight)

  let scale = window.getScaleInfo()
  if shared.autoUiScale:
    shared.uiScale = min(scale.x, scale.y)

  windowLogicalSize = windowSize / shared.pixelScale * shared.pixelRatio

proc preInput*() =
  # var x, y: float64
  # window.getCursorPos(addr x, addr y)
  # mouse.setMousePos(x, y)
  discard

proc postInput*() =
  # clearInputs()
  discard

proc preTick*() =
  discard

proc postTick*() =
  tpsTimeSeries.addTime()
  tps = float64(tpsTimeSeries.num())

  inc tickCount
  lastTick += deltaTick



proc clearDepthBuffer*() =
  glClear(GL_DEPTH_BUFFER_BIT)

proc clearColorBuffer*(color: Color) =
  glClearColor(color.r, color.g, color.b, color.a)
  glClear(GL_COLOR_BUFFER_BIT)

proc useDepthBuffer*(on: bool) =
  if on:
    glDepthMask(GL_TRUE)
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)
  else:
    glDepthMask(GL_FALSE)
    glDisable(GL_DEPTH_TEST)



proc startOpenGL*(window: Window, openglVersion: (int, int)) =

  let scale = window.getScaleInfo()
  
  if shared.autoUiScale:
    shared.uiScale = min(scale.x, scale.y)

  if app.fullscreen:
    window.fullscreen = app.fullscreen
  else:

    window.size = ivec2(
      (windowSize.x * shared.pixelScale * shared.uiScale).int32,
      (windowSize.y * shared.pixelScale * shared.uiScale).int32,
    )

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

  lastDraw = getTicks()
  lastTick = lastDraw
  app.focused = true

  updateWindowSize(window)

proc drawFrame*(nodes: var seq[Node]) =
  clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
  ctx.beginFrame(windowSize)
  ctx.saveTransform()
  ctx.scale(ctx.pixelScale)

  mouse.cursorStyle = Default

  # Only draw the root after everything was done:
  drawRoot(nodes)

  ctx.restoreTransform()
  ctx.endFrame()

  when defined(testOneFrame):
    ## This is used for test only
    ## Take a screen shot of the first frame and exit.
    var img = takeScreenshot()
    img.writeFile("screenshot.png")
    quit()

proc drawAndSwap*(window: Window, nodes: var seq[Node]) =
  ## Does drawing operations.
  inc frameCount
  fpsTimeSeries.addTime()
  fps = float64(fpsTimeSeries.num())
  avgFrameTime = fpsTimeSeries.avg()

  prevFrameTime = cpuTime()

  drawFrame(nodes)

  frameTime = cpuTime()
  dt = frameTime - prevFrameTime
  dtAvg = dtAvg * (1.0-1.0/100.0) + dt / 100.0

  var error: GLenum
  while (error = glGetError(); error != GL_NO_ERROR):
    echo "gl error: " & $error.uint32

  window.swapBuffers()
