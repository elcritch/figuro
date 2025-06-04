import std/[os, strformat]

import pkg/pixie
import pkg/opengl
import pkg/siwin

import opengl/glutils
import opengl/glcommons
import opengl/renderer

import ../common/nodes/uinodes
import ../common/[inputs, rchannels]
import ../common/wincfgs

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

type
  RendererSiwin* = ref object of Renderer
    window: Window
    globals*: SiwinGlobals

proc setupWindow*(
    frame: WeakRef[AppFrame],
    window: Window,
) =
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

  let winCfg = frame.loadLastWindow()

proc newSiwinRenderer*(
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
): RendererSiwin =
  let globals = newSiwinGlobals(
    preferedPlatform =
      case getEnv("FIGURO_SIWIN_BACKEND", "auto")
      of "x11": x11
      of "wayland": wayland
      else: defaultPreferedPlatform()
  )

  let window = newOpenglWindow(globals, title = "Figuro", size = ivec2(1280, 800))
  result = RendererSiwin(window: window, frame: frame)
  startOpenGL(openglVersion)

  setupWindow(frame, window)

  configureRenderer(result, frame, forcePixelScale, atlasSize)

method swapBuffers*(r: RendererSiwin) =
  # r.window.swapBuffers()

  # It's a no-op for now.
  return

method pollEvents*(r: RendererSiwin) =
  # It's a no-op on this backend.
  return

method getScaleInfo*(r: RendererSiwin): ScaleInfo =
  # TODO: implement
  result.x = 1
  result.y = 1

method setClipboard*(r: RendererSiwin, cb: ClipboardContents) =
  warn "TODO: siwin backend: clipboard write"
  return

method getClipboard*(r: RendererSiwin): ClipboardContents =
  warn "TODO: siwin backend: clipboard read"
  return ClipboardStr("")

method setTitle*(r: RendererSiwin, name: string) =
  r.window.title = name

method closeWindow*(r: RendererSiwin) =
  r.window.close()

method getWindowInfo*(r: RendererSiwin): WindowInfo =
    app.requestedFrame.inc

    result.minimized = r.window.minimized()
    result.pixelRatio = 1.0 # r.window.contentScale()

    var cwidth, cheight: cint
    let size = r.window.size()

    result.box.w = size.x.float32.descaled()
    result.box.h = size.y.float32.descaled()

method configureWindowEvents*(renderer: RendererSiwin) =
  let window {.cursor.} = renderer.window

  let winCfgFile = renderer.frame.windowCfgFile()
  let uxInputList = renderer.uxInputList
  let frame = renderer.frame

  #[
  window.onCloseRequest = proc() =
    notice "onCloseRequest"
    if frame[].saveWindowState:
      let wc = WindowConfig(pos: window.pos, size: window.size)
      writeWindowConfig(wc, winCfgFile)
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
  
  ]#
