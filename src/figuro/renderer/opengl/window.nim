import std/[strformat, times, strutils, os, files]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windex
import pkg/sigils/weakrefs

import utils
import glcommons
import ../../common/nodes/uinodes
import windowutils
import renderer

export AppFrame

# import ../patches/textboxes 
var
  cursorDefault*: Cursor
  cursorPointer*: Cursor
  cursorGrab*: Cursor
  cursorNSResize*: Cursor

when defined(glDebugMessageCallback):
  import strformat, strutils

static:
  ## compile check to ensure windex buttons don't change on us
  for i in 0 .. windex.Button.high().int:
    assert $Button(i) == $UiButton(i)

var lastMouse = Mouse()

proc toUi(wbtn: windex.ButtonView): UiButtonView =
  when defined(nimscript):
    for b in set[Button](wbtn):
      result.incl UiButton(b.int)
  else:
    copyMem(addr result, unsafeAddr wbtn, sizeof(ButtonView))

proc copyInputs(window: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  result.buttonRelease = toUi window.buttonReleased()
  result.buttonPress = toUi window.buttonPressed()
  result.buttonDown = toUi window.buttonDown()
  result.buttonToggle = toUi window.buttonToggle()

proc getScaleInfo*(window: Window): ScaleInfo =
  let scale = window.contentScale()
  result.x = scale
  result.y = scale

proc startOpenGL*(frame: WeakRef[AppFrame], window: Window, openglVersion: (int, int)) =
  assert not frame.isNil
  if frame[].window.fullscreen:
    window.fullscreen = frame[].window.fullscreen
  else:
    window.size = ivec2(frame[].window.box.wh.scaled())

  window.visible = true

  if window.isNil:
    quit(
      "Failed to open window. GL version:" & &"{openglVersion[0]}.{$openglVersion[1]}"
    )

  window.makeContextCurrent()

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
  frame[].window.focused = true

  useDepthBuffer(false)
  # updateWindowSize(frame, window)

proc convertStyle(fs: FrameStyle): WindowStyle =
  case fs
  of FrameStyle.DecoratedResizable:
    WindowStyle.DecoratedResizable
  of FrameStyle.DecoratedFixedSized:
    WindowStyle.Decorated
  of FrameStyle.Undecorated:
    WindowStyle.Undecorated
  of FrameStyle.Transparent:
    WindowStyle.Transparent

proc getWindowInfo*(window: Window): AppWindow =
    app.requestedFrame.inc

    result.minimized = window.minimized()
    result.pixelRatio = window.contentScale()

    var cwidth, cheight: cint
    let size = window.size()

    result.box.w = size.x.float32.descaled()
    result.box.h = size.y.float32.descaled()

proc configureWindowEvents(renderer: Renderer) =
  let window = renderer.window
  let winCfgFile = renderer.frame.windowCfgFile()

  window.runeInputEnabled = true

  window.onCloseRequest = proc() =
    notice "onCloseRequest"
    app.running = false

  window.onMove = proc() =
    writeWindowConfig(window, winCfgFile)
    # debug "window moved: ", pos= window.pos

  window.onResize = proc() =
    # updateWindowSize(renderer.frame, window)
    let windowState = getWindowInfo(window)
    var uxInput = window.copyInputs()
    uxInput.window = some windowState
    renderer.uxInputList.push(uxInput)
    # echo "RENDER LOOP: resize: start: ", windowState.box.wh.scaled(), " sent: ", sent
    # writeWindowConfig(window, winCfgFile)
    # debug "window resize: ", size= window.size
    renderer.pollAndRender(poll = false)
    # echo "RENDER LOOP: resize: done: ", windowState.box.wh.scaled(), " sent: ", sent

  window.onFocusChange = proc() =
    var uxInput = window.copyInputs()
    uxInput.window = some getWindowInfo(window)
    renderer.uxInputList.push(uxInput)

  window.onMouseMove = proc() =
    var uxInput = AppInputs()
    let pos = vec2(window.mousePos())
    uxInput.mouse.pos = pos.descaled()
    let prevPos = vec2(window.mousePrevPos())
    uxInput.mouse.prev = prevPos.descaled()
    uxInput.mouse.consumed = false
    lastMouse = uxInput.mouse
    lastMouse.consumed = true
    renderer.uxInputList.push(uxInput)

  window.onScroll = proc() =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.mouse.consumed = false
    uxInput.mouse.wheelDelta = window.scrollDelta().descaled()
    renderer.uxInputList.push(uxInput)

  window.onButtonPress = proc(button: windex.Button) =
    let uxInput = window.copyInputs()
    when defined(debugEvents):
      stdout.styledWriteLine(
        {styleDim},
        fgWhite,
        "buttonPress ",
        {styleBright},
        fgGreen,
        $uxInput.buttonPress,
        fgWhite,
        "buttonRelease ",
        fgGreen,
        $uxInput.buttonRelease,
        fgWhite,
        "buttonDown ",
        {styleBright},
        fgGreen,
        $uxInput.buttonDown,
      ) # fgBlue, " time: " & $(time - lastButtonRelease) )
    renderer.uxInputList.push(uxInput)

  window.onButtonRelease = proc(button: Button) =
    let uxInput = window.copyInputs()
    when defined(debugEvents):
      stdout.styledWriteLine(
        {styleDim},
        fgWhite,
        "release ",
        fgGreen,
        $button,
        fgWhite,
        "buttonRelease ",
        fgGreen,
        $uxInput.buttonRelease,
        fgWhite,
        "buttonDown ",
        {styleBright},
        fgGreen,
        $uxInput.buttonDown,
        fgWhite,
        "buttonPress ",
        {styleBright},
        fgGreen,
        $uxInput.buttonPress,
      )
    renderer.uxInputList.push(uxInput)

  window.onRune = proc(rune: Rune) =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.keyboard.rune = some rune
    when defined(debugEvents):
      stdout.styledWriteLine(
        {styleDim}, fgWhite, "keyboardInput: ", {styleDim}, fgGreen, $rune
      )
    renderer.uxInputList.push(uxInput)

  renderer.frame[].window.running = true
