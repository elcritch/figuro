

when defined(js):
  import figuro/htmlbackend
  export htmlbackend
elif defined(blank):
  import engine/blank
  export blank
else:
  import renderer/opengl
  export opengl

import std/os
import shared, internal, widgets/core
import common/nodes/transfer
import common/nodes/ui as ui
import common/nodes/render as render

when defined(emscripten):
  proc runRenderer() =
    # Emscripten can't block so it will call this callback instead.
    proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}
    proc mainLoop() {.cdecl.} =
      asyncPoll()
      renderLoop()
    emscripten_set_main_loop(main_loop, 0, true)
else:
  import locks

  var frameEvent: UiEvent
  var frameTickThread: Thread[void]
  var appThread: Thread[MainCallback]

  proc tickerRenderer() {.thread.} =
    while true:
      frameEvent.trigger()
      os.sleep(8)

  proc runApplication(appMain: MainCallback) {.thread.} =
    {.gcsafe.}:
      var appNodes: ui.Node
      while app.running:
        appNodes.setupRoot()
        appMain()
        computeScreenBox(nil, appNodes)
        sendRoot(appNodes.copyInto())
        os.sleep(16)

  proc run(renderer: Renderer) =

    sendRoot = proc (nodes: sink seq[render.Node]) =
        renderer.nodes = nodes

    frameEvent = initUiEvent()
    createThread(frameTickThread, tickerRenderer)
    createThread(appThread, runApplication, appMain)

    while app.running:
      wait(frameEvent)
      renderLoop(renderer, true)

proc startFidget*(
    draw: proc() {.nimcall.} = nil,
    tick: proc() {.nimcall.} = nil,
    load: proc() {.nimcall.} = nil,
    setup: proc() = nil,
    fullscreen = false,
    w: Positive = 1280,
    h: Positive = 800,
    pixelate = false,
    pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 
  app.fullscreen = fullscreen
  
  if not fullscreen:
    windowSize = vec2(uiScale * w.float32, uiScale * h.float32)
  appMain = draw
  tickMain = tick
  loadMain = load

  let atlasStartSz = 1024 shl (uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"

  let renderer = setupRenderer(pixelate, pixelScale, atlasStartSz)
  mouse.pixelScale = pixelScale

  if not setup.isNil: setup()
  renderer.run()