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

  Renderer* = ref object of RootObj
    window*: RendererWindow
    duration*: Duration
    uxInputList*: RChan[AppInputs]
    rendInputList*: RChan[RenderCommands]
    lock*: Lock
    updated*: Atomic[bool]

    nodes*: Renders
    frame*: WeakRef[AppFrame]

method swapBuffers*(r: Renderer) {.base.} = discard
method configureRenderer*(
    renderer: Renderer,
    window: RendererWindow,
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
) {.base.} = discard

method pollEvents*(r: RendererWindow) {.base.} = discard
method setTitle*(r: RendererWindow, name: string) {.base.} = discard
method closeWindow*(r: RendererWindow) {.base.} = discard
method getScaleInfo*(r: RendererWindow): ScaleInfo {.base.} = discard
method getWindowInfo*(r: RendererWindow): WindowInfo {.base.} = discard
method configureWindowEvents*(renderer: RendererWindow) {.base.} = discard
method setClipboard*(r: RendererWindow, cb: ClipboardContents) {.base.} = discard
method getClipboard*(r: RendererWindow): ClipboardContents {.base.} = discard
method copyInputs*(r: RendererWindow): AppInputs {.base.} = discard

proc configureBaseRenderer*(
    renderer: Renderer,
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
) =
  app.pixelScale = forcePixelScale
  renderer.nodes = Renders()
  renderer.frame = frame
  renderer.uxInputList = newRChan[AppInputs](5)
  renderer.rendInputList = newRChan[RenderCommands](5)
  renderer.lock.initLock()
  frame[].uxInputList = renderer.uxInputList
  frame[].rendInputList = renderer.rendInputList
  frame[].clipboards = newRChan[ClipboardContents](1)
