import std/[os, strformat, unicode, times]
import std/asyncdispatch

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windy

import ./perf
import ../commonutils
import ../common, ../input, ../internal
import ../patches/textboxes 

when defined(glDebugMessageCallback):
  import strformat, strutils

type
  MSAA* = enum
    msaaDisabled, msaa2x = 2, msaa4x = 4, msaa8x = 8

  MainLoopMode* = enum
    ## Only repaints on event
    ## Used for normal for desktop UI apps.
    RepaintOnEvent

    ## Repaints every frame (60hz or more based on display)
    ## Updates are done every matching frame time.
    ## Used for simple multimedia apps and games.
    RepaintOnFrame

    ## Repaints every frame (60hz or more based on display)
    ## But calls the tick function for keyboard and mouse updates at 240hz
    ## Used for low latency games.
    RepaintSplitUpdate
  
  ScaleInfo* = object
    x*: float32
    y*: float32

const
  deltaTick: int64 = 1_000_000_000 div 240

var
  window: windy.Window
  loopMode*: MainLoopMode
  dpi*: float32
  drawFrame*: proc()
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
  cursorDefault*: CursorHandle
  cursorPointer*: CursorHandle
  cursorGrab*: CursorHandle
  cursorNSResize*: CursorHandle

var
  uiEvent*: AsyncEvent

var
  eventTimePre* = epochTime()
  eventTimePost* = epochTime()
  isEvent* = false

proc setCursor*(cursor: CursorHandle) =
  echo "set cursor"
  window.setCursor(cursor)

proc getScaleInfo*(monitor: Monitor): ScaleInfo =
  var xs, ys: cfloat
  getMonitorContentScale(monitor, addr xs, addr ys)
  result.x = xs
  result.y = ys

proc updateWindowSize() =
  requestedFrame.inc

  var cwidth, cheight: cint
  window.getWindowSize(addr cwidth, addr cheight)
  windowSize.x = float32(cwidth)
  windowSize.y = float32(cheight)

  window.getFramebufferSize(addr cwidth, addr cheight)
  windowFrame.x = float32(cwidth)
  windowFrame.y = float32(cheight)

  minimized = windowSize == vec2(0, 0)
  pixelRatio = if windowSize.x > 0: windowFrame.x / windowSize.x else: 0

  glViewport(0, 0, cwidth, cheight)

  let
    monitor = getPrimaryMonitor()
    mode = monitor.getVideoMode()
  monitor.getMonitorPhysicalSize(addr cwidth, addr cheight)
  dpi = mode.width.float32 / (cwidth.float32 / 25.4)

  let scale = monitor.getScaleInfo()
  if common.autoUiScale:
    common.uiScale = min(scale.x, scale.y)

  windowLogicalSize = windowSize / common.pixelScale * common.pixelRatio

proc setWindowTitle*(title: string) =
  if window != nil:
    window.setWindowTitle(title)

proc preInput() =
  var x, y: float64
  window.getCursorPos(addr x, addr y)
  mouse.setMousePos(x, y)

proc postInput() =
  clearInputs()

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

  assert drawFrame != nil
  drawFrame()

  frameTime = cpuTime()
  dt = frameTime - prevFrameTime
  dtAvg = dtAvg * (1.0-1.0/100.0) + dt / 100.0

  var error: GLenum
  while (error = glGetError(); error != GL_NO_ERROR):
    echo "gl error: " & $error.uint32

  window.swapBuffers()

proc updateLoop*(poll = true) =
  if window.windowShouldClose() != 0:
    running = false
    return

  case loopMode:
    of RepaintOnEvent:
      if poll:
        pollEvents()
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

    of RepaintOnFrame:
      if poll:
        pollEvents()
      preInput()
      if tickMain != nil:
        preTick()
        tickMain()
        postTick()
      drawAndSwap()
      postInput()

    of RepaintSplitUpdate:
      if poll:
        pollEvents()
      preInput()
      while lastTick < getTicks():
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

proc exit*() =
  ## Cleanup GLFW.
  terminate()

proc glGetInteger*(what: GLenum): int =
  var val: GLint
  glGetIntegerv(what, val.addr)
  return val.int

proc onResize(handle: staticglfw.Window, w, h: int32) {.cdecl.} =
  updateWindowSize()
  let prevloopMode = loopMode
  updateLoop(poll = false)
  loopMode = prevloopMode

proc onFocus(window: staticglfw.Window, state: cint) {.cdecl.} =
  focused = state == 1
  uiEvent.trigger()

proc nextFocus*(parent, node: Node, foundFocus: var bool): bool =
  ## find the next node to focus on
  for child in node.nodes:
    if child.selectable:
      if foundFocus:
        child.setFocus = true
        return true
      if child == keyboard.focusNode:
        foundFocus = true
    else:
      if nextFocus(node, child, foundFocus):
        return

proc nextFocus() =
  echo "focusNode:tab: ", keyboard.focusNode.id
  echo "focusNode:tab: ", common.root.id
  var foundFocus = false
  discard nextFocus(nil, root, foundFocus)

proc onSetKey(
  window: staticglfw.Window, key, scancode, action, modifiers: cint
) {.cdecl.} =
  requestedFrame.inc
  let setKey = action != RELEASE

  keyboard.altKey = setKey and ((modifiers and MOD_ALT) != 0)
  keyboard.ctrlKey = setKey and
    ((modifiers and MOD_CONTROL) != 0 or (modifiers and MOD_SUPER) != 0)
  keyboard.shiftKey = setKey and ((modifiers and MOD_SHIFT) != 0)

  # Do the text box commands.
  if keyboard.focusNode != nil and setKey:
    keyboard.state = KeyState.Press
    let
      ctrl = keyboard.ctrlKey
      shift = keyboard.shiftKey
    case cast[Button](key):
      of TAB:
        nextFocus()
      of ARROW_LEFT:
        if ctrl:
          currTextBox.leftWord(shift)
        else:
          currTextBox.left(shift)
      of ARROW_RIGHT:
        if ctrl:
          currTextBox.rightWord(shift)
        else:
          currTextBox.right(shift)
      of ARROW_UP:
        currTextBox.up(shift)
      of ARROW_DOWN:
        currTextBox.down(shift)
      of Button.HOME:
        currTextBox.startOfLine(shift)
      of Button.END:
        currTextBox.endOfLine(shift)
      of Button.PAGE_UP:
        currTextBox.pageUp(shift)
      of Button.PAGE_DOWN:
        currTextBox.pageDown(shift)
      of ENTER:
        #TODO: keyboard.multiline:
        currTextBox.typeCharacter(Rune(10))
      of BACKSPACE:
        currTextBox.backspace(shift)
      of DELETE:
        currTextBox.delete(shift)
      of LETTER_C: # copy
        if ctrl:
          base.window.setClipboardString(currTextBox.copy())
      of LETTER_V: # paste
        if ctrl:
          currTextBox.paste($base.window.getClipboardString())
      of LETTER_X: # cut
        if ctrl:
          base.window.setClipboardString(currTextBox.cut())
      of LETTER_A: # select all
        if ctrl:
          currTextBox.selectAll()
      else:
        discard

  # Now do the buttons.
  if key < buttonDown.len and key >= 0:
    if buttonDown[key] == false and setKey:
      buttonToggle[key] = not buttonToggle[key]
      buttonPress[key] = true
    if buttonDown[key] == true and setKey == false:
      buttonRelease[key] = true
    buttonDown[key] = setKey
  # ui event
  isEvent = true
  eventTimePre = epochTime()
  uiEvent.trigger()

proc onScroll(window: staticglfw.Window, xoffset, yoffset: float64) {.cdecl.} =
  requestedFrame.inc
  let yoffset = yoffset
  mouse.wheelDelta += 6 * yoffset * common.uiScale
  uiEvent.trigger()

proc onMouseButton(
  window: staticglfw.Window, button, action, modifiers: cint
) {.cdecl.} =
  requestedFrame.inc
  let
    setKey = action != 0
    button = button + 1 # Fidget mouse buttons are +1 from staticglfw
  if button < buttonDown.len:
    if buttonDown[button] == false and setKey == true:
      buttonPress[button] = true
    buttonDown[button] = setKey
  if buttonDown[button] == false and setKey == false:
    buttonRelease[button] = true
  uiEvent.trigger()

proc onMouseMove(window: staticglfw.Window, x, y: cdouble) {.cdecl.} =
  requestedFrame.inc
  uiEvent.trigger()

proc onSetCharCallback(window: staticglfw.Window, character: cuint) {.cdecl.} =
  requestedFrame.inc
  if keyboard.focusNode != nil:
    keyboard.state = KeyState.Press
    currTextBox.typeCharacter(Rune(character))
  else:
    keyboard.state = KeyState.Press
    keyboard.keyString = Rune(character).toUTF8()
  uiEvent.trigger()

proc start*(openglVersion: (int, int), msaa: MSAA, mainLoopMode: MainLoopMode) =
  if init() == 0:
    quit("Failed to intialize GLFW.")

  running = true
  loopMode = mainLoopMode

  if msaa != msaaDisabled:
    windowHint(SAMPLES, msaa.cint)

  windowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
  windowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
  windowHint(CONTEXT_VERSION_MAJOR, openglVersion[0].cint)
  windowHint(CONTEXT_VERSION_MINOR, openglVersion[1].cint)

  let
    monitor = getPrimaryMonitor()
    scale = monitor.getScaleInfo()
  
  if common.autoUiScale:
    common.uiScale = min(scale.x, scale.y)

  if fullscreen:
    let mode = getVideoMode(monitor)
    window = createWindow(mode.width, mode.height, "", monitor, nil)
  else:
    var dpiScale, yScale: cfloat
    monitor.getMonitorContentScale(addr dpiScale, addr yScale)
    assert dpiScale == yScale

    window = createWindow(
      (windowSize.x / dpiScale * common.pixelScale * common.uiScale).cint,
      (windowSize.y / dpiScale * common.pixelScale * common.uiScale).cint,
      "",
      nil,
      nil
    )

  if window.isNil:
    quit(
      "Failed to open window. GL version:" &
      &"{openglVersion[0]}.{$openglVersion[1]}"
    )

  window.makeContextCurrent()

  cursorDefault = createStandardCursor(ARROW_CURSOR)
  cursorPointer = createStandardCursor(HAND_CURSOR)
  cursorGrab = createStandardCursor(HAND_CURSOR)
  cursorNSResize = createStandardCursor(HRESIZE_CURSOR)

  when not defined(emscripten):
    swapInterval(1)
    # Load OpenGL
    loadExtensions()

  when defined(glDebugMessageCallback):
    let flags = glGetInteger(GL_CONTEXT_FLAGS)
    if (flags and GL_CONTEXT_FLAG_DEBUG_BIT.GLint) != 0:
      # Set up error logging
      proc printGlDebug(
        source, typ: GLenum,
        id: GLuint,
        severity: GLenum,
        length: GLsizei,
        message: ptr GLchar,
        userParam: pointer
      ) {.stdcall.} =
        echo &"source={toHex(source.uint32)} type={toHex(typ.uint32)} " &
          &"id={id} severity={toHex(severity.uint32)}: {$message}"
        if severity != GL_DEBUG_SEVERITY_NOTIFICATION:
          running = false

      glDebugMessageCallback(printGlDebug, nil)
      glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS)
      glEnable(GL_DEBUG_OUTPUT)

  when defined(printGLVersion):
    echo getVersionString()
    echo "GL_VERSION:", cast[cstring](glGetString(GL_VERSION))
    echo "GL_SHADING_LANGUAGE_VERSION:",
      cast[cstring](glGetString(GL_SHADING_LANGUAGE_VERSION))

  discard window.setFramebufferSizeCallback(onResize)
  discard window.setWindowFocusCallback(onFocus)
  discard window.setKeyCallback(onSetKey)
  discard window.setScrollCallback(onScroll)
  discard window.setMouseButtonCallback(onMouseButton)
  discard window.setCursorPosCallback(onMouseMove)
  discard window.setCharCallback(onSetCharCallback)

  glEnable(GL_BLEND)
  #glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBlendFuncSeparate(
    GL_SRC_ALPHA,
    GL_ONE_MINUS_SRC_ALPHA,
    GL_ONE,
    GL_ONE_MINUS_SRC_ALPHA
  )

  lastDraw = getTicks()
  lastTick = lastDraw

  onFocus(window, FOCUSED)
  focused = true
  updateWindowSize()

proc captureMouse*() =
  setInputMode(window, CURSOR, CURSOR_DISABLED)

proc releaseMouse*() =
  setInputMode(window, CURSOR, CURSOR_NORMAL)

proc hideMouse*() =
  setInputMode(window, CURSOR, CURSOR_HIDDEN)

proc setWindowBounds*(min, max: Vec2) =
  window.setWindowSizeLimits(min.x.cint, min.y.cint, max.x.cint, max.y.cint)

proc takeScreenshot*(
  frame = rect(0, 0, windowFrame.x, windowFrame.y)
): pixie.Image =
  result = newImage(frame.w.int, frame.h.int)
  glReadPixels(
    frame.x.GLint,
    frame.y.GLint,
    frame.w.GLint,
    frame.h.GLint,
    GL_RGBA,
    GL_UNSIGNED_BYTE,
    result.data[0].addr
  )
  result.flipVertical()
