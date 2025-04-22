import std/[strformat, times, strutils, os, files]

import pkg/[chroma, pixie]
import pkg/opengl
import pkg/windex
import pkg/sigils/weakrefs
import pkg/chronicles

import utils
import glcommons
import renderertypes
import ../../common/nodes/uinodes
import ../../common/rchannels


type Renderer* = RendererImpl[Window]

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

proc convertStyle*(fs: FrameStyle): WindowStyle =
  case fs
  of FrameStyle.FrameResizable:
    WindowStyle.DecoratedResizable
  of FrameStyle.FrameFixedSized:
    WindowStyle.Decorated
  of FrameStyle.FrameUndecorated:
    WindowStyle.Undecorated
  of FrameStyle.FrameTransparent:
    WindowStyle.Transparent

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

proc configureWindow*(frame: WeakRef[AppFrame], window: Window) =
  assert not frame.isNil
  if frame[].appWindow.fullscreen:
    window.fullscreen = frame[].appWindow.fullscreen
  else:
    window.size = ivec2(frame[].appWindow.box.wh.scaled())

  window.visible = true

proc createWindow*[F](frame: WeakRef[F]): Window =

  let window = newWindow("Figuro", ivec2(1280, 800), visible = false)
  let style: WindowStyle = frame[].windowStyle.convertStyle()
  let winCfg = frame.loadLastWindow()

  if app.autoUiScale:
    let scale = window.getScaleInfo()
    app.uiScale = min(scale.x, scale.y)

  window.`style=`(style)
  window.`pos=`(winCfg.pos)

  return window

proc getWindowInfo*(window: Window): AppWindow =
    app.requestedFrame.inc

    result.minimized = window.minimized()
    result.pixelRatio = window.contentScale()

    var cwidth, cheight: cint
    let size = window.size()

    result.box.w = size.x.float32.descaled()
    result.box.h = size.y.float32.descaled()

proc configureWindowEvents*(renderer: RendererImpl[Window], pollAndRender: PollAndRenderProc) =
  let window = renderer.window
  let winCfgFile = renderer.frame.frameCfgFile()

  `runeInputEnabled=`(window, true)

  window.onCloseRequest = proc() =
    notice "onCloseRequest"
    app.running = false

  window.onMove = proc() =
    let frameCfg = FrameConfig(size: window.size(), pos: window.pos())
    writeFrameConfig(frameCfg, winCfgFile)
    # debug "window moved: ", pos= window.pos

  window.onResize = proc() =
    # updateWindowSize(renderer.frame, window)
    let windowState = getWindowInfo(window)
    var uxInput = window.copyInputs()
    uxInput.appWindow = some windowState
    renderer.uxInputList.push(uxInput)
    # echo "RENDER LOOP: resize: start: ", windowState.box.wh.scaled(), " sent: ", sent
    # writeWindowConfig(window, winCfgFile)
    # debug "window resize: ", size= window.size
    pollAndRender(renderer, poll = false)
    # echo "RENDER LOOP: resize: done: ", windowState.box.wh.scaled(), " sent: ", sent

  window.onFocusChange = proc() =
    var uxInput = window.copyInputs()
    uxInput.appWindow = some getWindowInfo(window)
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

  renderer.frame[].appWindow.running = true

proc swapBuffers*(renderer: Renderer) =
  renderer.window.swapBuffers()

proc pollEvents*(renderer: Renderer) =
  windex.pollEvents()

proc setTitle*(renderer: Renderer, title: string) =
  renderer.window.title = title

proc makeContextCurrent*(renderer: Renderer) =
  renderer.window.makeContextCurrent()
