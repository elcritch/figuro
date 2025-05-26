import std/locks
import std/atomics
import std/times

import ../../common/shared
import ../../common/nodes/render
import ../../common/nodes/uinodes
import ../../common/rchannels
import ../../common/wincfgs


type
  RendererWindow* = ref object of RootObj
    appWindow*: WindowInfo
    frame*: WeakRef[AppFrame]
    uxInputList*: RChan[AppInputs]

  Renderer* = ref object of RootObj
    window*: RendererWindow
    duration*: Duration
    rendInputList*: RChan[RenderCommands]
    lock*: Lock
    updated*: Atomic[bool]

    nodes*: Renders
    frame*: WeakRef[AppFrame]

method swapBuffers*(r: Renderer) {.base.} = discard
method pollAndRender*(renderer: Renderer, poll = true) {.base.} = discard

method configureRenderer*(
    renderer: Renderer,
    window: RendererWindow,
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
) {.base.} = discard

method pollEvents*(w: RendererWindow) {.base.} = discard
method setTitle*(w: RendererWindow, name: string) {.base.} = discard
method closeWindow*(w: RendererWindow) {.base.} = discard
method getScaleInfo*(w: RendererWindow): ScaleInfo {.base.} = discard
method getWindowInfo*(w: RendererWindow): WindowInfo {.base.} = discard
method configureWindowEvents*(w: RendererWindow, r: Renderer) {.base.} = discard
method setClipboard*(w: RendererWindow, cb: ClipboardContents) {.base.} = discard
method getClipboard*(w: RendererWindow): ClipboardContents {.base.} = discard
method copyInputs*(w: RendererWindow): AppInputs {.base.} = discard

proc configureBaseRenderer*(
    renderer: Renderer,
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
) =
  app.pixelScale = forcePixelScale
  renderer.nodes = Renders()
  renderer.frame = frame
  renderer.rendInputList = newRChan[RenderCommands](5)
  renderer.lock.initLock()
  frame[].rendInputList = renderer.rendInputList

proc configureBaseWindow*(
    window: RendererWindow,
) =
  assert not window.frame.isNil
  window.uxInputList = newRChan[AppInputs](5)
  window.frame[].uxInputList = window.uxInputList
  window.frame[].clipboards = newRChan[ClipboardContents](1)
