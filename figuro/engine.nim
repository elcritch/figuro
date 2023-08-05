

when defined(js):
  import figuro/htmlbackend
  export htmlbackend
elif defined(blank):
  import engine/blank
  export blank
else:
  import engine/opengl
  export opengl

import std/os
import shared, internal, widgets/core

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

  var frameLock: Lock
  var frameTick: Cond
  var frameTickThread: Thread[void]
  var appThread: Thread[MainCallback]

  proc tickerRenderer() {.thread.} =
    withLock(frameLock):
      while true:
        frameTick.signal()
        os.sleep(8)

  proc runApplication(drawMain: MainCallback) {.thread.} =
    {.gcsafe.}:
      while app.running:
        setupRoot()
        drawMain()
        # computeScreenBox(nil, root)
        var rootCopy = root.deepCopy
        # renderRoot = rootCopy.move()

  proc runRenderer(window: Window) =

    frameLock.initLock()
    frameTick.initCond()
    createThread(frameTickThread, tickerRenderer)
    createThread(appThread, runApplication, drawMain)

    withLock(frameLock):
      while app.running:
        wait(frameTick, frameLock)
        renderLoop(window, true)


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
  drawMain = draw
  tickMain = tick
  loadMain = load

  let atlasStartSz = 1024 shl (uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"

  setupRenderer(pixelate, pixelScale, atlasStartSz)
  mouse.pixelScale = pixelScale

  if not setup.isNil: setup()
  runRenderer()