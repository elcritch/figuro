import std/strformat

import pkg/pixie
import pkg/opengl
import pkg/windex

import utils
import glcommons
import ../../common/nodes/uinodes
import ../../common/rchannels

import wutils
import renderer

import pkg/sigils/weakrefs
import pkg/chronicles

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

proc convertStyle*(fs: FrameStyle): WindowStyle

type
  Renderer* = ref object of RendererBase
    window: Window

proc setupWindow*(
    frame: WeakRef[AppFrame],
    window: Window,
) =
  let style: WindowStyle = frame[].windowStyle.convertStyle()
  assert not frame.isNil
  if frame[].windowInfo.fullscreen:
    window.fullscreen = frame[].windowInfo.fullscreen
  else:
    window.size = ivec2(frame[].windowInfo.box.wh.scaled())

  window.visible = true

  if window.isNil:
    quit(
      "Failed to open window. GL version:" & &"{openglVersion[0]}.{$openglVersion[1]}"
    )

  window.makeContextCurrent()

  let winCfg = frame.loadLastWindow()

  window.`style=`(style)
  window.`pos=`(winCfg.pos)

proc newRenderer*(
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
): Renderer =
  let window = newWindow("Figuro", ivec2(1280, 800), visible = false)
  result = Renderer(window: window, frame: frame)
  startOpenGL(openglVersion)

  setupWindow(frame, window)

  configureRendererBase(result, frame, forcePixelScale, atlasSize)

proc convertStyle*(fs: FrameStyle): WindowStyle =
  case fs
  of FrameStyle.DecoratedResizable:
    WindowStyle.DecoratedResizable
  of FrameStyle.DecoratedFixedSized:
    WindowStyle.Decorated
  of FrameStyle.Undecorated:
    WindowStyle.Undecorated
  of FrameStyle.Transparent:
    WindowStyle.Transparent

proc toUi*(wbtn: windex.ButtonView): UiButtonView =
  when defined(nimscript):
    for b in set[Button](wbtn):
      result.incl UiButton(b.int)
  else:
    copyMem(addr result, unsafeAddr wbtn, sizeof(ButtonView))

method getScaleInfo*(r: Renderer): ScaleInfo =
  let scale = r.window.contentScale()
  result.x = scale
  result.y = scale

var lastMouse = Mouse()

proc copyInputs(window: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  result.buttonRelease = toUi window.buttonReleased()
  result.buttonPress = toUi window.buttonPressed()
  result.buttonDown = toUi window.buttonDown()
  result.buttonToggle = toUi window.buttonToggle()

method setTitle*(r: Renderer, name: string) =
  r.window.title = name

method swapBuffers*(r: Renderer) =
  r.window.swapBuffers()

method closeWindow*(r: Renderer) =
  r.window.close()

method getWindowInfo*(r: Renderer): WindowInfo =
    app.requestedFrame.inc

    result.minimized = r.window.minimized()
    result.pixelRatio = r.window.contentScale()

    var cwidth, cheight: cint
    let size = r.window.size()

    result.box.w = size.x.float32.descaled()
    result.box.h = size.y.float32.descaled()

proc configureWindowEvents*(
    renderer: Renderer,
) =
  let window {.cursor.} = renderer.window

  let winCfgFile = renderer.frame.windowCfgFile()
  let uxInputList = renderer.uxInputList
  let frame = renderer.frame

  window.runeInputEnabled = true

  window.onCloseRequest = proc() =
    notice "onCloseRequest"
    if frame[].saveWindowState:
      writeWindowConfig(window, winCfgFile)
    app.running = false

  window.onMove = proc() =
    discard
    # debug "window moved: ", pos= window.pos

  window.onResize = proc() =
    # updateWindowSize(renderer.frame, window)
    let windowState = renderer.getWindowInfo()
    var uxInput = window.copyInputs()
    uxInput.window = some windowState
    uxInputList.push(uxInput)
    pollAndRender(renderer, poll = false)

  window.onFocusChange = proc() =
    var uxInput = window.copyInputs()
    uxInput.window = some renderer.getWindowInfo()
    uxInputList.push(uxInput)

  window.onMouseMove = proc() =
    var uxInput = AppInputs()
    let pos = vec2(window.mousePos())
    uxInput.mouse.pos = pos.descaled()
    let prevPos = vec2(window.mousePrevPos())
    uxInput.mouse.prev = prevPos.descaled()
    uxInput.mouse.consumed = false
    lastMouse = uxInput.mouse
    lastMouse.consumed = true
    uxInputList.push(uxInput)

  window.onScroll = proc() =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.mouse.consumed = false
    uxInput.mouse.wheelDelta = window.scrollDelta().descaled()
    uxInputList.push(uxInput)

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
    uxInputList.push(uxInput)

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
    uxInputList.push(uxInput)

  window.onRune = proc(rune: Rune) =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.keyboard.rune = some rune
    when defined(debugEvents):
      stdout.styledWriteLine(
        {styleDim}, fgWhite, "keyboardInput: ", {styleDim}, fgGreen, $rune
      )
    uxInputList.push(uxInput)

