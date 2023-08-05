

when defined(js):
  import figuro/htmlbackend
  export htmlbackend
elif defined(blank):
  import engine/blank
  export blank
else:
  import engine/opengl
  export opengl

import common, internal, widgets/core

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
        sleep(8)

  proc runApplication(drawMain: MainCallback) {.thread.} =
    {.gcsafe.}:
      while base.running:
          proc running() {.async.} =
            setupRoot()
            drawMain()
            computeScreenBox(nil, root)
            var rootCopy = root.deepCopy
            renderRoot = rootCopy.move()
            await sleepAsync(8)
          waitFor running()

  proc runRenderer() =

    frameLock.initLock()
    frameTick.initCond()
    createThread(frameTickThread, tickerRenderer)
    createThread(appThread, runApplication, drawMain)

    withLock(frameLock):
      while base.running:
        wait(frameTick, frameLock)
        renderLoop()
        if isEvent:
          isEvent = false
          eventTimePost = epochTime()


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
  common.fullscreen = fullscreen
  
  if not fullscreen:
    windowSize = vec2(uiScale * w.float32, uiScale * h.float32)
  drawMain = draw
  tickMain = tick
  loadMain = load

  let atlasStartSz = 1024 shl (uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"

  setupWindow(pixelate, pixelScale, atlasStartSz)
  mouse.pixelScale = pixelScale

  if not setup.isNil: setup()
  runRenderer()