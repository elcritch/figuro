import std/[options, unicode, strutils, tables, times]
import std/[os, json]
import std/terminal

import pkg/pixie
import pkg/windex
import pkg/sigils/weakrefs

import pkg/chronicles

import ../commons
import ../common/rchannels
# import ../inputs
import ./opengl/window
import ./opengl/renderer

export Renderer, runRendererLoop

var lastMouse = Mouse()

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

proc copyInputs(window: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  result.buttonRelease = toUi window.buttonReleased()
  result.buttonPress = toUi window.buttonPressed()
  result.buttonDown = toUi window.buttonDown()
  result.buttonToggle = toUi window.buttonToggle()

type
  WindowConfig* = object
    pos*: IVec2 = ivec2(100, 100)
    size*: IVec2 = ivec2(0, 0)

proc windowCfgFile*(frame: WeakRef[AppFrame]): string =
  frame[].configFile & ".window"

proc loadLastWindow*(frame: WeakRef[AppFrame]): WindowConfig =
  result = WindowConfig()
  if frame.windowCfgFile().fileExists():
    try:
      let jn = parseFile(frame.windowCfgFile())
      result = jn.to(WindowConfig)
    except Defect, CatchableError:
      discard
  notice "loadLastWindow", config= result

proc writeWindowConfig*(window: Window, winCfgFile: string) =
    try:
      let wc = WindowConfig(pos: window.pos, size: window.size)
      let jn = %*(wc)
      writeFile(winCfgFile, $(jn))
    except Defect, CatchableError:
      debug "error writing window position"

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
    if renderer.frame[].saveWindowState:
      writeWindowConfig(window, winCfgFile)
    app.running = false

  window.onMove = proc() =
    discard
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

proc createRenderer*[F](frame: WeakRef[F]): Renderer =

  let window = newWindow("Figuro", ivec2(1280, 800), visible = false)
  let style: WindowStyle = frame[].windowStyle.convertStyle()
  let winCfg = frame.loadLastWindow()

  if app.autoUiScale:
    let scale = window.getScaleInfo()
    app.uiScale = min(scale.x, scale.y)

  window.`style=`(style)
  window.`pos=`(winCfg.pos)
  if winCfg.size.x != 0 and winCfg.size.y != 0:
    let sz = vec2(x= winCfg.size.x.float32, y= winCfg.size.y.float32).descaled()
    frame[].window.box.w = sz.x.UiScalar
    frame[].window.box.h = sz.y.UiScalar

  let atlasSize = 1024 shl (app.uiScale.round().toInt() + 1)
  let renderer = newRenderer(frame, window, 1.0, atlasSize)
  renderer.configureWindowEvents()
  app.requestedFrame.inc

  return renderer
