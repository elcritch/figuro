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

proc getScaleInfo*(window: Window): ScaleInfo =
  let scale = window.contentScale()
  result.x = scale
  result.y = scale

proc setupWindow*(frame: WeakRef[AppFrame], window: Window) =
  let style: WindowStyle = frame[].windowStyle.convertStyle()
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

  let winCfg = frame.loadLastWindow()

  window.`style=`(style)
  # window.`pos=`(winCfg.pos)


proc startOpenGL*(frame: WeakRef[AppFrame], window: Window, openglVersion: (int, int)) =
  when not defined(emscripten):
    loadExtensions()

  openglDebug()

  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBlendFuncSeparate(
    GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA
  )

  useDepthBuffer(false)

var lastMouse = Mouse()

proc copyInputs(window: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  result.buttonRelease = toUi window.buttonReleased()
  result.buttonPress = toUi window.buttonPressed()
  result.buttonDown = toUi window.buttonDown()
  result.buttonToggle = toUi window.buttonToggle()

proc configureWindowEvents*(
    renderer: Renderer,
    window: Window,
    frame: WeakRef[AppFrame],
    renderCb: proc()
) =
  let win {.cursor.} = window

  let winCfgFile = renderer.frame.windowCfgFile()
  let uxInputList = renderer.uxInputList

  renderer.setTitle = proc(name: string) =
    window.title = name

  renderer.swapBuffers = proc() =
    window.swapBuffers()

  renderer.closeWindow = proc() =
    window.close()

  window.runeInputEnabled = true

  window.onCloseRequest = proc() =
    notice "onCloseRequest"
    if frame[].saveWindowState:
      writeWindowConfig(win, winCfgFile)
    app.running = false

  window.onMove = proc() =
    discard
    # debug "window moved: ", pos= window.pos

  window.onResize = proc() =
    # updateWindowSize(renderer.frame, window)
    let windowState = getWindowInfo(win)
    var uxInput = win.copyInputs()
    uxInput.window = some windowState
    uxInputList.push(uxInput)
    renderCb() # pollAndRender(frame, poll = false)

  window.onFocusChange = proc() =
    var uxInput = win.copyInputs()
    uxInput.window = some getWindowInfo(win)
    uxInputList.push(uxInput)

  window.onMouseMove = proc() =
    var uxInput = AppInputs()
    let pos = vec2(win.mousePos())
    uxInput.mouse.pos = pos.descaled()
    let prevPos = vec2(win.mousePrevPos())
    uxInput.mouse.prev = prevPos.descaled()
    uxInput.mouse.consumed = false
    lastMouse = uxInput.mouse
    lastMouse.consumed = true
    uxInputList.push(uxInput)

  window.onScroll = proc() =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.mouse.consumed = false
    uxInput.mouse.wheelDelta = win.scrollDelta().descaled()
    uxInputList.push(uxInput)

  window.onButtonPress = proc(button: windex.Button) =
    let uxInput = win.copyInputs()
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
    let uxInput = win.copyInputs()
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

