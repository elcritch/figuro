import std/strformat

import pkg/pixie
import pkg/opengl
import pkg/siwin
import pkg/sigils/weakrefs
import pkg/chronicles

import ./utils/glutils

import ../common/nodes/uinodes
import ../common/rchannels
import ../common/wincfgs
import ../common/shared
import ../common/keys

import ./utils/baserenderer

export AppFrame

# import ../patches/textboxes
var
  cursorDefault*: Cursor
  cursorPointer*: Cursor
  cursorGrab*: Cursor
  cursorNSResize*: Cursor

when defined(glDebugMessageCallback):
  import strformat, strutils

# proc convertStyle*(fs: FrameStyle): WindowStyle

type
  RendererSiwin* = ref object of RendererWindow
    window: Window

proc setupWindow*(
    frame: WeakRef[AppFrame],
    window: Window,
) =
  # let style: WindowStyle = frame[].windowStyle.convertStyle()
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

  # window.makeContextCurrent()

  let winCfg = frame.loadLastWindow()

  # window.`style=`(style)
  window.`pos=`(winCfg.pos)

proc newSiwinRenderer*(
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
): RendererSiwin =
  let window = newSiwinGlobals().newOpenglWindow()

  result = RendererSiwin(window: window, frame: frame)
  startOpenGL(openglVersion)

  setupWindow(frame, window)

  configureBaseWindow(result)

method setWindowSize*(w: RendererSiwin, size: IVec2) =
  w.window.`size=`(size)


method swapBuffers*(r: RendererSiwin) =
  # r.window.swapBuffers()
  discard

method pollEvents*(r: RendererSiwin) =
  # windex.pollEvents()
  discard

method getScaleInfo*(r: RendererSiwin): ScaleInfo =
  # let scale = r.window.contentScale()
  # result.x = scale
  # result.y = scale
  result.x = 1.0
  result.y = 1.0

var lastMouse: keys.Mouse

proc copyInputs*(w: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  # result.buttonRelease = toUi w.buttonReleased()
  # result.buttonPress = toUi w.buttonPressed()
  # result.buttonDown = toUi w.buttonDown()
  # result.buttonToggle = toUi w.buttonToggle()

method copyInputs*(r: RendererSiwin): AppInputs =
  copyInputs(r.window)

method setClipboard*(r: RendererSiwin, cb: ClipboardContents) =
  match cb:
    ClipboardStr(str):
      # windex.setClipboardString(str)
      discard
    ClipboardEmpty:
      discard

method getClipboard*(r: RendererSiwin): ClipboardContents =
  # let str = windex.getClipboardString()
  # return ClipboardStr(str)
  # return ClipboardEmpty
  discard

method setTitle*(r: RendererSiwin, name: string) =
  r.window.title = name

method closeWindow*(r: RendererSiwin) =
  r.window.close()

method getWindowInfo*(r: RendererSiwin): WindowInfo =
    app.requestedFrame.inc

    result.minimized = r.window.minimized()
    # result.pixelRatio = r.window.contentScale()
    result.pixelRatio = 1.0

    var cwidth, cheight: cint
    let size = r.window.size()

    result.box.w = size.x.float32.descaled()
    result.box.h = size.y.float32.descaled()

method configureWindowEvents*(renderer: RendererSiwin) =
  let window {.cursor.} = renderer.window

  let winCfgFile = renderer.frame.windowCfgFile()
  let uxInputList = renderer.uxInputList
  let frame = renderer.frame

  # window.runeInputEnabled = true


