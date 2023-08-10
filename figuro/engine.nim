
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
import shared, internal, ui/core
import common/nodes/transfer
import common/nodes/ui as ui
import common/nodes/render as render
import widget
import timers

when defined(emscripten):
  proc runRenderer() =
    # Emscripten can't block so it will call this callback instead.
    proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}
    proc mainLoop() {.cdecl.} =
      asyncPoll()
      renderLoop()
    emscripten_set_main_loop(main_loop, 0, true)
else:

  const renderPeriodMs {.intdefine.} = 16
  const appPeriodMs {.intdefine.} = 16

  var frameTickThread, appTickThread: Thread[void]
  var appThread, : Thread[MainCallback]

  proc renderTicker() {.thread.} =
    while true:
      renderEvent.trigger()
      os.sleep(appPeriodMs - 2)

  proc appTicker() {.thread.} =
    while app.running:
      appEvent.trigger()
      os.sleep(renderPeriodMs - 2)

  proc runApplication(appMain: MainCallback) {.thread.} =
    {.gcsafe.}:
      var appNodes: Figuro
      while app.running:
        wait(appEvent)
        timeIt(appAvgTime):
          appNodes.setupRoot()
          appMain()
          computeScreenBox(nil, appNodes)
          sendRoot(appNodes.copyInto())

  proc runRenderer(renderer: Renderer) =
    while app.running:
      wait(renderEvent)
      timeIt(renderAvgTime):
        renderLoop(renderer, true)
        app.frameCount.inc()

  proc run(renderer: Renderer) =

    sendRoot = proc (nodes: sink seq[render.Node]) =
        renderer.nodes = nodes

    renderEvent = initUiEvent()
    appEvent = initUiEvent()

    createThread(frameTickThread, renderTicker)
    createThread(appTickThread, appTicker)
    createThread(appThread, runApplication, appMain)

    proc ctrlc() {.noconv.} =
      echo "Got Ctrl+C exiting!"
      app.running = false
    setControlCHook(ctrlc)

    runRenderer(renderer)

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

when not defined(gcArc) and not defined(gcOrc) and not defined(nimdoc):
  {.error: "This channel implementation requires --gc:arc or --gc:orc".}

proc emptyProc() = discard


proc startFiguro*[T: Figuro](
    widget: T,
    setup: proc() = nil,
    fullscreen = false,
    w: Positive = 1280,
    h: Positive = 800,
    pixelate = false,
    pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 

  # appWidget = widget
  app.fullscreen = fullscreen
  uiinputs.mouse = Mouse()
  uiinputs.mouse.pos = vec2(0, 0)

  
  if not fullscreen:
    app.windowSize = vec2(app.uiScale * w.float32, app.uiScale * h.float32)

  let appWidget = widget

  proc appRender() =
    mixin render
    appWidget.render()

  proc appTick() =
    appWidget.tick()

  proc appLoad() =
    appWidget.load()
  
  appMain = appRender
  tickMain = appTick
  loadMain = appLoad

  if appMain.isNil:
    raise newException(AssertionDefect, "appMain cannot be nil")
  if tickMain.isNil:
    tickMain = emptyProc
  if loadMain.isNil:
    loadMain = emptyProc

  let atlasStartSz = 1024 shl (app.uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"

  let renderer = setupRenderer(pixelate, pixelScale, atlasStartSz)
  uiinputs.mouse.pixelScale = pixelScale

  if not setup.isNil: setup()
  renderer.run()
