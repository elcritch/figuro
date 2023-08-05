import std/[os, strformat, unicode, times]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windy

import perf, utils
import ../../[common, internal]

# import ../patches/textboxes 

when defined(glDebugMessageCallback):
  import strformat, strutils

const
  deltaTick: int64 = 1_000_000_000 div 240

var
  dpi*: float32
  drawFrame*: MainCallback
  programStartTime* = epochTime()
  fpsTimeSeries = newTimeSeries()
  tpsTimeSeries = newTimeSeries()
  prevFrameTime* = programStartTime
  frameTime* = prevFrameTime
  dt*, dtAvg*, fps*, tps*, avgFrameTime*: float64
  frameCount*, tickCount*: int
  lastDraw, lastTick: int64

var
  cursorDefault*: Cursor
  cursorPointer*: Cursor
  cursorGrab*: Cursor
  cursorNSResize*: Cursor

var
  eventTimePre* = epochTime()
  eventTimePost* = epochTime()
  isEvent* = false

proc getScaleInfo*(window: Window): ScaleInfo =
  let scale = window.contentScale()
  result.x = scale
  result.y = scale

proc updateWindowSize(window: Window) =
  requestedFrame.inc

  var cwidth, cheight: cint
  let size = window.size()
  windowSize.x = size.x.toFloat
  windowSize.y = size.y.toFloat

  minimized = window.minimized()
  pixelRatio = window.contentScale()

  glViewport(0, 0, cwidth, cheight)

  let scale = window.getScaleInfo()
  if common.autoUiScale:
    common.uiScale = min(scale.x, scale.y)

  windowLogicalSize = windowSize / common.pixelScale * common.pixelRatio

proc setWindowTitle*(title: string) =
  if window != nil:
    window.title = title

proc preInput() =
  # var x, y: float64
  # window.getCursorPos(addr x, addr y)
  # mouse.setMousePos(x, y)
  discard

proc postInput() =
  # clearInputs()
  discard

proc preTick() =
  discard

proc postTick() =
  tpsTimeSeries.addTime()
  tps = float64(tpsTimeSeries.num())

  inc tickCount
  lastTick += deltaTick

proc drawAndSwap() =
  ## Does drawing operations.
  inc frameCount
  fpsTimeSeries.addTime()
  fps = float64(fpsTimeSeries.num())
  avgFrameTime = fpsTimeSeries.avg()

  prevFrameTime = cpuTime()

  drawFrame()

  frameTime = cpuTime()
  dt = frameTime - prevFrameTime
  dtAvg = dtAvg * (1.0-1.0/100.0) + dt / 100.0

  var error: GLenum
  while (error = glGetError(); error != GL_NO_ERROR):
    echo "gl error: " & $error.uint32

  window.swapBuffers()

proc renderLoop*(poll = true) =
  if window.closeRequested:
    running = false
    return

  if poll:
    windy.pollEvents()
  
  if requestedFrame <= 0 or minimized:
    return
  requestedFrame.dec
  preInput()
  if tickMain != nil:
    preTick()
    tickMain()
    postTick()
  drawAndSwap()
  postInput()

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

proc configureWindowEvents(window: Window) =

  window.onResize = proc () =
    updateWindowSize(window)
    renderLoop(poll = false)
    renderEvent.trigger()
  
  window.onFocusChange = proc () =
    focused = window.focused
    uiEvent.trigger()

  window.onScroll = proc () =
    requestedFrame.inc
    mouse.wheelDelta += window.scrollDelta().x
    renderEvent.trigger()

  window.onRune = keyboardInput

  window.onMouseMove = proc () =
    requestedFrame.inc
    uiEvent.trigger()

  window.onButtonPress = proc (button: windy.Button) =
    requestedFrame.inc
    uiEvent.trigger()

  window.onButtonRelease = proc (button: Button) =
    uiEvent.trigger()


proc start*(openglVersion: (int, int)) =

  var window: windy.Window

  window = newWindow("Windy Basic", ivec2(1280, 800))

  running = true

  # if msaa != msaaDisabled:
  #   windowHint(SAMPLES, msaa.cint)
  # windowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
  # windowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
  # windowHint(CONTEXT_VERSION_MAJOR, openglVersion[0].cint)
  # windowHint(CONTEXT_VERSION_MINOR, openglVersion[1].cint)

  let
    scale = window.getScaleInfo()
  
  if common.autoUiScale:
    common.uiScale = min(scale.x, scale.y)

  if common.fullscreen:
    window.fullscreen = common.fullscreen
  else:
    # var dpiScale, yScale: cfloat
    # monitor.getMonitorContentScale(addr dpiScale, addr yScale)
    # assert dpiScale == yScale

    window.size = ivec2(
      (windowSize.x * common.pixelScale * common.uiScale).int32,
      (windowSize.y * common.pixelScale * common.uiScale).int32,
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
  focused = true

  configureWindowEvents(window)
  updateWindowSize(window)
