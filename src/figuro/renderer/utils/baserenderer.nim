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
    info*: WindowInfo
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


method pollAndRender*(renderer: Renderer, poll = true) {.base.} =
  ## renders and draws a window given set of nodes passed
  ## in via the Renderer object

  if poll:
    renderer.window.pollEvents()

  var update = false
  var cmd: RenderCommands
  while renderer.rendInputList.tryRecv(cmd):
    match cmd:
      RenderUpdate(nlayers, rwindow):
        renderer.nodes = nlayers
        renderer.appWindow = rwindow
        update = true
      RenderQuit:
        echo "QUITTING"
        renderer.frame[].windowInfo.running = false
        app.running = false
        return
      RenderSetTitle(name):
        renderer.setTitle(name)
      RenderClipboardGet:
        let cb = renderer.getClipboard()
        renderer.frame[].clipboards.push(cb)
      RenderClipboard(cb):
        renderer.setClipboard(cb)

  if update:
    renderAndSwap(renderer)

method runRendererLoop*(renderer: Renderer) {.base.} =
  threadEffects:
    RenderThread
  while app.running:
    pollAndRender(renderer)

    os.sleep(renderer.duration.inMilliseconds)
  debug "Renderer loop exited"
  renderer.closeWindow()
  debug "Renderer window closed"
