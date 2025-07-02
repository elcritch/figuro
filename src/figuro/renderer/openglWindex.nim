import std/strformat
import std/terminal

import pkg/pixie
import pkg/opengl
import pkg/windex
import pkg/chronicles

import ./utils/glutils

import ../common/nodes/uinodes
import ../common/rchannels
import ../common/wincfgs
import ../common/shared

import ./utils/baserenderer

export AppFrame

var
  cursorDefault*: Cursor
  cursorPointer*: Cursor
  cursorGrab*: Cursor
  cursorNSResize*: Cursor

when defined(glDebugMessageCallback):
  import strformat, strutils

proc convertStyle*(fs: FrameStyle): WindowStyle

type
  WindexWindow* = ref object of RendererWindow
    window: Window

method setWindowSize*(w: WindexWindow, size: IVec2) =
  w.window.`size=`(size)

method setWindowPos*(w: WindexWindow, pos: IVec2) =
  w.window.`pos=`(pos)

method setVisible*(w: WindexWindow, visible: bool) =
  w.window.visible = visible

proc newRendererWindow*(
    frame: WeakRef[AppFrame],
): RendererWindow =
  let window = newWindow("Figuro", ivec2(200, 200), visible = false)
  result = WindexWindow(window: window, frame: frame)
  startOpenGL(openglVersion)

  assert not frame.isNil

  if window.isNil:
    let glVersion = &"{openglVersion[0]}.{$openglVersion[1]}"
    quit("Failed to open window. GL version: " & glVersion)

  window.makeContextCurrent()
  window.`style=`(frame[].windowStyle.convertStyle())

  configureBaseWindow(result)

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

proc toMouse(wbtn: windex.Button, value: var UiMouse): bool
proc toKey(wbtn: windex.Button, value: var UiKey): bool

proc toMouse(wbtn: windex.ButtonView): set[UiMouse] =
  let btns = set[windex.Button](wbtn)
  result = {}
  for mb in btns:
    var value: UiMouse
    if toMouse(mb, value):
      result.incl value

proc toKey(wbtn: windex.ButtonView): set[UiKey] =
  let btns = set[windex.Button](wbtn)
  result = {}
  for kb in btns:
    var value: UiKey
    if toKey(kb, value):
      result.incl value

method swapBuffers*(r: WindexWindow) =
  r.window.swapBuffers()

method pollEvents*(r: WindexWindow) =
  windex.pollEvents()

method getScaleInfo*(r: WindexWindow): ScaleInfo =
  let scale = r.window.contentScale()
  result.x = scale
  result.y = scale

var lastMouse = Mouse()

proc copyInputs*(w: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  result.buttonRelease = toMouse(w.buttonReleased())
  result.buttonPress = toMouse(w.buttonPressed())
  result.buttonDown = toMouse(w.buttonDown())
  result.buttonToggle = toMouse(w.buttonToggle())
  result.keyRelease = toKey(w.buttonReleased())
  result.keyPress = toKey(w.buttonPressed())
  result.keyDown = toKey(w.buttonDown())
  result.keyToggle = toKey(w.buttonToggle())

method copyInputs*(r: WindexWindow): AppInputs =
  copyInputs(r.window)

method setClipboard*(r: WindexWindow, cb: ClipboardContents) =
  match cb:
    ClipboardStr(str):
      windex.setClipboardString(str)
    ClipboardEmpty:
      discard

method getClipboard*(r: WindexWindow): ClipboardContents =
  let str = windex.getClipboardString()
  return ClipboardStr(str)

method setTitle*(r: WindexWindow, name: string) =
  r.window.title = name

method closeWindow*(r: WindexWindow) =
  r.window.close()

method getWindowInfo*(r: WindexWindow): WindowInfo =
    app.requestedFrame.inc

    result.minimized = r.window.minimized()
    result.pixelRatio = r.window.contentScale()

    var cwidth, cheight: cint
    let size = r.window.size()

    result.box.w = size.x.float32.descaled()
    result.box.h = size.y.float32.descaled()

method configureWindowEvents*(w: WindexWindow, r: Renderer) =
  let winCfgFile = w.frame.windowCfgFile()
  let uxInputList = w.uxInputList
  let frame = w.frame
  let window = w.window

  window.runeInputEnabled = true

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
    let windowState = w.getWindowInfo()
    var uxInput = window.copyInputs()
    uxInput.windowInfo = some windowState
    uxInputList.push(uxInput)
    r.pollAndRender(poll = false)

  window.onFocusChange = proc() =
    var uxInput = window.copyInputs()
    uxInput.windowInfo = some w.getWindowInfo()
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

proc toMouse(wbtn: windex.Button, value: var UiMouse): bool =
  result = true
  case wbtn
  of Button.ButtonUnknown: value = UiMouse.MouseUnknown
  of Button.MouseLeft: value = UiMouse.MouseLeft
  of Button.MouseRight: value = UiMouse.MouseRight
  of Button.MouseMiddle: value = UiMouse.MouseMiddle
  of Button.MouseButton4: value = UiMouse.MouseButton4
  of Button.MouseButton5: value = UiMouse.MouseButton5
  of Button.DoubleClick: value = UiMouse.DoubleClick
  of Button.TripleClick: value = UiMouse.TripleClick
  of Button.QuadrupleClick: value = UiMouse.QuadrupleClick
  else:
    result = false

proc toKey(wbtn: windex.Button, value: var UiKey): bool =
  result = true
  case wbtn
  of Button.ButtonUnknown: value = UiKey.KeyUnknown
  of Button.Key0: value = UiKey.Key0
  of Button.Key1: value = UiKey.Key1
  of Button.Key2: value = UiKey.Key2
  of Button.Key3: value = UiKey.Key3
  of Button.Key4: value = UiKey.Key4
  of Button.Key5: value = UiKey.Key5
  of Button.Key6: value = UiKey.Key6
  of Button.Key7: value = UiKey.Key7
  of Button.Key8: value = UiKey.Key8
  of Button.Key9: value = UiKey.Key9
  of Button.KeyA: value = UiKey.KeyA
  of Button.KeyB: value = UiKey.KeyB
  of Button.KeyC: value = UiKey.KeyC
  of Button.KeyD: value = UiKey.KeyD
  of Button.KeyE: value = UiKey.KeyE
  of Button.KeyF: value = UiKey.KeyF
  of Button.KeyG: value = UiKey.KeyG
  of Button.KeyH: value = UiKey.KeyH
  of Button.KeyI: value = UiKey.KeyI
  of Button.KeyJ: value = UiKey.KeyJ
  of Button.KeyK: value = UiKey.KeyK
  of Button.KeyL: value = UiKey.KeyL
  of Button.KeyM: value = UiKey.KeyM
  of Button.KeyN: value = UiKey.KeyN
  of Button.KeyO: value = UiKey.KeyO
  of Button.KeyP: value = UiKey.KeyP
  of Button.KeyQ: value = UiKey.KeyQ
  of Button.KeyR: value = UiKey.KeyR
  of Button.KeyS: value = UiKey.KeyS
  of Button.KeyT: value = UiKey.KeyT
  of Button.KeyU: value = UiKey.KeyU
  of Button.KeyV: value = UiKey.KeyV
  of Button.KeyW: value = UiKey.KeyW
  of Button.KeyX: value = UiKey.KeyX
  of Button.KeyY: value = UiKey.KeyY
  of Button.KeyZ: value = UiKey.KeyZ
  of Button.KeyBacktick: value = UiKey.KeyBacktick
  of Button.KeyMinus: value = UiKey.KeyMinus
  of Button.KeyEqual: value = UiKey.KeyEqual
  of Button.KeyBackspace: value = UiKey.KeyBackspace
  of Button.KeyTab: value = UiKey.KeyTab
  of Button.KeyLeftBracket: value = UiKey.KeyLeftBracket
  of Button.KeyRightBracket: value = UiKey.KeyRightBracket
  of Button.KeyBackslash: value = UiKey.KeyBackslash
  of Button.KeyCapsLock: value = UiKey.KeyCapsLock
  of Button.KeySemicolon: value = UiKey.KeySemicolon
  of Button.KeyApostrophe: value = UiKey.KeyApostrophe
  of Button.KeyEnter: value = UiKey.KeyEnter
  of Button.KeyLeftShift: value = UiKey.KeyLeftShift
  of Button.KeyRightShift: value = UiKey.KeyRightShift
  of Button.KeyLeftControl: value = UiKey.KeyLeftControl
  of Button.KeyRightControl: value = UiKey.KeyRightControl
  of Button.KeyLeftAlt: value = UiKey.KeyLeftAlt
  of Button.KeyRightAlt: value = UiKey.KeyRightAlt
  of Button.KeyLeftSuper: value = UiKey.KeyLeftSuper
  of Button.KeyRightSuper: value = UiKey.KeyRightSuper
  of Button.KeyMenu: value = UiKey.KeyMenu
  of Button.KeyDelete: value = UiKey.KeyDelete
  of Button.KeyHome: value = UiKey.KeyHome
  of Button.KeyEnd: value = UiKey.KeyEnd
  of Button.KeyInsert: value = UiKey.KeyInsert
  of Button.KeyPageUp: value = UiKey.KeyPageUp
  of Button.KeyPageDown: value = UiKey.KeyPageDown
  of Button.KeyEscape: value = UiKey.KeyEscape
  of Button.KeyUp: value = UiKey.KeyUp
  of Button.KeyDown: value = UiKey.KeyDown
  of Button.KeyLeft: value = UiKey.KeyLeft
  of Button.KeyRight: value = UiKey.KeyRight
  of Button.KeyPrintScreen: value = UiKey.KeyPrintScreen
  of Button.KeyScrollLock: value = UiKey.KeyScrollLock
  of Button.KeyPause: value = UiKey.KeyPause
  of Button.KeyF1: value = UiKey.KeyF1
  of Button.KeyF2: value = UiKey.KeyF2
  of Button.KeyF3: value = UiKey.KeyF3
  of Button.KeyF4: value = UiKey.KeyF4
  of Button.KeyF5: value = UiKey.KeyF5
  of Button.KeyF6: value = UiKey.KeyF6
  of Button.KeyF7: value = UiKey.KeyF7
  of Button.KeyF8: value = UiKey.KeyF8
  of Button.KeyF9: value = UiKey.KeyF9
  of Button.KeyF10: value = UiKey.KeyF10
  of Button.KeyF11: value = UiKey.KeyF11
  of Button.KeyF12: value = UiKey.KeyF12
  of Button.KeyNumLock: value = UiKey.KeyNumLock
  of Button.Numpad0: value = UiKey.Numpad0
  of Button.Numpad1: value = UiKey.Numpad1
  of Button.Numpad2: value = UiKey.Numpad2
  of Button.Numpad3: value = UiKey.Numpad3
  of Button.Numpad4: value = UiKey.Numpad4
  of Button.Numpad5: value = UiKey.Numpad5
  of Button.Numpad6: value = UiKey.Numpad6
  of Button.Numpad7: value = UiKey.Numpad7
  of Button.Numpad8: value = UiKey.Numpad8
  of Button.Numpad9: value = UiKey.Numpad9 
  of Button.NumpadDecimal: value = UiKey.NumpadDecimal
  of Button.NumpadEnter: value = UiKey.NumpadEnter
  of Button.NumpadAdd: value = UiKey.NumpadAdd
  of Button.NumpadSubtract: value = UiKey.NumpadSubtract
  of Button.NumpadMultiply: value = UiKey.NumpadMultiply
  of Button.NumpadDivide: value = UiKey.NumpadDivide
  of Button.NumpadEqual: value = UiKey.NumpadEqual 
  else:
    result = false
