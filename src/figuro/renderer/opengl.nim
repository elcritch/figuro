import std/[options, unicode, hashes, strformat, strutils, tables, times]
import std/[os, json]
import std/terminal

import pkg/pixie
import pkg/windex
import pkg/sigils/weakrefs

import pkg/chronicles 

import ../commons
# import ../inputs
import ./opengl/utils
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
    pos*: IVec2 = ivec2(0, 0)
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

proc configureWindowEvents(renderer: Renderer) =
  let window = renderer.window
  let winCfgFile = renderer.frame.windowCfgFile()

  window.runeInputEnabled = true

  let winCfg = renderer.frame.loadLastWindow()
  window.pos = winCfg.pos
  # if winCfg.size.x != 0 and winCfg.size.y != 0:
  #   window.size = winCfg.size

  window.onCloseRequest = proc() =
    notice "onCloseRequest"

  window.onMove = proc() =
    writeWindowConfig(window, winCfgFile)
    debug "window moved: ", pos= window.pos

  window.onResize = proc() =
    updateWindowSize(renderer.frame, window)
    renderer.pollAndRender(updated = true, poll = false)
    var uxInput = window.copyInputs()
    uxInput.windowSize = some renderer.frame[].windowSize
    discard renderer.uxInputList.trySend(uxInput)
    writeWindowConfig(window, winCfgFile)
    debug "window resize: ", size= window.size

  window.onFocusChange = proc() =
    renderer.frame[].focused = window.focused
    let uxInput = window.copyInputs()
    discard renderer.uxInputList.trySend(uxInput)

  window.onMouseMove = proc() =
    var uxInput = AppInputs()
    let pos = vec2(window.mousePos())
    uxInput.mouse.pos = pos.descaled()
    let prevPos = vec2(window.mousePrevPos())
    uxInput.mouse.prev = prevPos.descaled()
    uxInput.mouse.consumed = false
    lastMouse = uxInput.mouse
    let res = renderer.uxInputList.trySend(uxInput)
    if res == false:
      echo "warning: mouse event blocked!"

  window.onScroll = proc() =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.mouse.consumed = false
    uxInput.mouse.wheelDelta = window.scrollDelta().descaled()
    discard renderer.uxInputList.trySend(uxInput)

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
    discard renderer.uxInputList.trySend(uxInput)

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
    discard renderer.uxInputList.trySend(uxInput)

  window.onRune = proc(rune: Rune) =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.keyboard.rune = some rune
    when defined(debugEvents):
      stdout.styledWriteLine(
        {styleDim}, fgWhite, "keyboardInput: ", {styleDim}, fgGreen, $rune
      )
    discard renderer.uxInputList.trySend(uxInput)

  renderer.frame[].running = true

proc createRenderer*[F](frame: WeakRef[F]): Renderer =
  let window = newWindow("", ivec2(1280, 800))
  let style: WindowStyle = frame[].windowStyle.convertStyle()
  window.`style=`(style)
  let atlasSize = 1024 shl (app.uiScale.round().toInt() + 1)
  let renderer = newRenderer(frame, window, false, 1.0, atlasSize)
  renderer.configureWindowEvents()
  app.requestedFrame.inc

  return renderer
