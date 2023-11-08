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

  glViewport(0, 0, cwidth, cheight)

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

proc renderFrame*(ctx: RContext, nodes: var RenderNodes) =
  # clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
  let size = ivec2(app.windowRawSize.x.toInt.int32, app.windowRawSize.y.toInt.int32)
  ctx.boxy.beginFrame(size)
  ctx.boxy.saveTransform()
  ctx.boxy.scale(vec2(app.pixelScale, app.pixelScale))

  # uxInputs.mouse.cursorStyle = Default

  # Only draw the root after everything was done:
  ctx.renderRoot(nodes)

  ctx.boxy.restoreTransform()
  ctx.boxy.endFrame()

  when defined(testOneFrame):
    ## This is used for test only
    ## Take a screen shot of the first frame and exit.
    var img = takeScreenshot()
    img.writeFile("screenshot.png")
    quit()

proc renderAndSwap*(ctx: RContext,
                    window: Window,
                    nodes: var RenderNodes,
                    updated: bool) =
  ## Does drawing operations.
  app.tickCount.inc

  timeIt(drawFrame):
    ctx.renderFrame(nodes)

  frameTime = cpuTime()
  dt = frameTime - prevFrameTime
  dtAvg = dtAvg * (1.0-1.0/100.0) + dt / 100.0

  var error: GLenum
  while (error = glGetError(); error != GL_NO_ERROR):
    echo "gl error: " & $error.uint32

  timeIt(drawFrameSwap):
    window.swapBuffers()
