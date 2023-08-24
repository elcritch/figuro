
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
import std/sets
import shared, internal, ui/core
import common/nodes/ui as ui
import common/nodes/render as render
import widget
import timers

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

when not defined(gcArc) and not defined(gcOrc) and not defined(nimdoc):
  {.error: "Figuro requires --gc:arc or --gc:orc".}

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

proc runRenderer(renderer: Renderer) =
  while app.running:
    wait(renderEvent)
    timeIt(renderAvgTime):
      renderLoop(renderer, true)

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
        computeEvents(root)
        if redrawNodes.len() > 0:
          appMain()
          app.frameCount.inc()
        # clearInputs()


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
