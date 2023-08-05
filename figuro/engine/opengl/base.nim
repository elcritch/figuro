import std/[os, strformat, unicode, times]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windy

import ./perf
import ../../[commonutils, common, internal]

# import ../patches/textboxes 

when defined(glDebugMessageCallback):
  import strformat, strutils

const
  deltaTick: int64 = 1_000_000_000 div 240

var
  window*: windy.Window
  dpi*: float32
  drawFrame*: MainCallback
  running*, focused*, minimized*: bool
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

proc setCursor*(cursor: Cursor) =
  echo "set cursor"
  window.cursor = cursor

proc getScaleInfo*(window: Window): ScaleInfo =
  let scale = window.contentScale()
  result.x = scale
  result.y = scale

proc updateWindowSize() =
  requestedFrame.inc

  var cwidth, cheight: cint
  let size = window.size()
  windowSize.x = size.x.toFloat
  windowSize.y = size.y.toFloat

  # window.getFramebufferSize(addr cwidth, addr cheight)
  # windowFrame.x = float32(cwidth)
  # windowFrame.y = float32(cheight)

  minimized = window.minimized()
  pixelRatio = window.contentScale()

  glViewport(0, 0, cwidth, cheight)

  # let
  #   monitor = window.getPrimaryMonitor()
  #   mode = monitor.getVideoMode()
  # monitor.getMonitorPhysicalSize(addr cwidth, addr cheight)
  # dpi = mode.width.float32 / (cwidth.float32 / 25.4)

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

import std/times

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
    # Only repaint when necessary
    # when not defined(emscripten):
      # echo "update loop: ", loopMode.repr
      # sleep(16)
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


proc start*(openglVersion: (int, int), msaa: MSAA, mainLoopMode: MainLoopMode) =
  window = newWindow("Windy Basic", ivec2(1280, 800))

  running = true
  loopMode = mainLoopMode

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

  # cursorDefault = createStandardCursor(ARROW_CURSOR)
  # cursorPointer = createStandardCursor(HAND_CURSOR)
  # cursorGrab = createStandardCursor(HAND_CURSOR)
  # cursorNSResize = createStandardCursor(HRESIZE_CURSOR)

  when not defined(emscripten):
    # swapInterval(1)
    # Load OpenGL
    loadExtensions()

  # when defined(glDebugMessageCallback):
  #   let flags = glGetInteger(GL_CONTEXT_FLAGS)
  #   if (flags and GL_CONTEXT_FLAG_DEBUG_BIT.GLint) != 0:
  #     # Set up error logging
  #     proc printGlDebug(
  #       source, typ: GLenum,
  #       id: GLuint,
  #       severity: GLenum,
  #       length: GLsizei,
  #       message: ptr GLchar,
  #       userParam: pointer
  #     ) {.stdcall.} =
  #       echo &"source={toHex(source.uint32)} type={toHex(typ.uint32)} " &
  #         &"id={id} severity={toHex(severity.uint32)}: {$message}"
  #       if severity != GL_DEBUG_SEVERITY_NOTIFICATION:
  #         running = false
  #     glDebugMessageCallback(printGlDebug, nil)
  #     glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS)
  #     glEnable(GL_DEBUG_OUTPUT)

  # when defined(printGLVersion):
  #   echo getVersionString()
  #   echo "GL_VERSION:", cast[cstring](glGetString(GL_VERSION))
  #   echo "GL_SHADING_LANGUAGE_VERSION:",
  #     cast[cstring](glGetString(GL_SHADING_LANGUAGE_VERSION))

  window.onResize = proc () =
    updateWindowSize()
    let prevloopMode = loopMode
    renderLoop(poll = false)
    loopMode = prevloopMode
    uiEvent.trigger()
  
  window.onFocusChange = proc () =
    focused = window.focused
    uiEvent.trigger()

  window.onScroll = proc () =
    requestedFrame.inc
    # mouse.wheelDelta += 6 * yoffset * common.uiScale
    mouse.wheelDelta += window.scrollDelta().x
    uiEvent.trigger()

  window.onRune = keyboardInput

  window.onMouseMove = proc () =
    requestedFrame.inc
    uiEvent.trigger()

  window.onButtonPress = proc (button: windy.Button) =
    requestedFrame.inc
    # let
    #   setKey = action != 0
    #   button = button + 1 # Fidget mouse buttons are +1 from windy
    # if button < window.buttonDown.len:
    #   if buttonDown[button] == false and setKey == true:
    #     buttonPress[button] = true
    #   buttonDown[button] = setKey

  window.onButtonRelease = proc (button: Button) =
    # if buttonDown[button] == false and setKey == false:
    #   buttonRelease[button] = true
    uiEvent.trigger()


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

  # onFocus(window, FOCUSED)
  focused = true
  updateWindowSize()
