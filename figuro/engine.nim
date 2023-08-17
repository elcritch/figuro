
when defined(js):
  import figuro/htmlbackend
  export htmlbackend
elif defined(blank):
  import engine/blank
  export blank
else:
  import renderer/window
  export window

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

  var
    appMain*: MainCallback
    tickMain*: MainCallback
    loadMain*: MainCallback
    sendRoot*: proc (nodes: sink seq[render.Node]) {.closure.}

  const renderPeriodMs {.intdefine.} = 16
  const appPeriodMs {.intdefine.} = 16

  var frameTickThread, appTickThread: Thread[void]
  var appThread, : Thread[MainCallback]

  proc renderTicker() {.thread.} =
    while true:
      renderEvent.trigger()
      os.sleep(appPeriodMs - 2)
      app.tickCount.inc()
      if app.tickCount == app.tickCount.typeof.high:
        app.tickCount = 0

  proc appTicker() {.thread.} =
    while app.running:
      appEvent.trigger()
      os.sleep(renderPeriodMs - 2)

  proc runApplication(appMain: MainCallback) {.thread.} =
    {.gcsafe.}:
      while app.running:
        wait(appEvent)
        timeIt(appAvgTime):
          tickMain()
          echo "runApplication: ", app.requestedFrame
          if app.requestedFrame > 0:
            appMain()
            app.frameCount.inc()


  proc runRenderer(renderer: Renderer) =
    while app.running:
      wait(renderEvent)
      timeIt(renderAvgTime):
        renderLoop(renderer, true)

  proc init*(renderer: Renderer) =
    sendRoot = proc (nodes: sink seq[render.Node]) =
        renderer.nodes = nodes

  proc run*(renderer: Renderer) =

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
  {.error: "Figuro requires --gc:arc or --gc:orc".}

proc startFiguro*(
    widget: FiguroApp,
    setup: proc() = nil,
    fullscreen = false,
    pixelate = false,
    pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 

  # appWidget = widget
  app.fullscreen = fullscreen

  if not fullscreen:
    app.windowSize = Position vec2(app.uiScale * app.width.float32,
                                   app.uiScale * app.height.float32)

  root = widget

  proc appRender() =
    mixin draw
    root.diffIndex = 0
    if not uxInputs.mouse.consumed:
      echo "got mouse: ", uxInputs.mouse.pos
      uxInputs.mouse.consumed = true
      echo root.listeners
      # echo "emit:hover: ", cast[pointer](root).repr
      emit root.eventHover()
    emit root.onDraw()
    computeScreenBox(nil, root)
    sendRoot(root.copyInto())

  proc appTick() =
    emit root.onTick()

  proc appLoad() =
    emit root.onLoad()
  
  setupRoot(root)

  appMain = appRender
  tickMain = appTick
  loadMain = appLoad

  if appMain.isNil:
    raise newException(AssertionDefect, "appMain cannot be nil")
  if tickMain.isNil:
    tickMain = proc () = discard
  if loadMain.isNil:
    loadMain = proc () = discard

  let atlasStartSz = 1024 shl (app.uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"

  let renderer = setupRenderer(pixelate, pixelScale, atlasStartSz)

  if not setup.isNil: setup()
  renderer.run()
