
when defined(js):
  import figuro/htmlbackend
  export htmlbackend
elif defined(blank):
  import engine/blank
  export blank
else:
  import renderer/default
  export default

import std/os
import std/sets
import shared, internal
import ui/[core, events]
import common/nodes/ui
import common/nodes/render
import common/nodes/transfer
import widget
import timers

export core, events

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

when not defined(gcArc) and not defined(gcOrc) and not defined(nimdoc):
  {.error: "Figuro requires --gc:arc or --gc:orc".}

var
  mainApp*: MainCallback
  tickMain*: MainCallback
  eventMain*: MainCallback
  loadMain*: MainCallback
  sendRoot*: proc (nodes: sink RenderNodes) {.closure.}

const renderPeriodMs {.intdefine.} = 16
const appPeriodMs {.intdefine.} = 16

var frameTickThread, appTickThread: Thread[void]
var appThread, : Thread[MainCallback]

proc renderTicker() {.thread.} =
  while true:
    uiRenderEvent.trigger()
    os.sleep(appPeriodMs - 2)
    app.tickCount.inc()
    if app.tickCount == app.tickCount.typeof.high:
      app.tickCount = 0

proc runRenderer(renderer: Renderer) =
  while app.running:
    wait(uiRenderEvent)
    timeIt(renderAvgTime):
      renderer.render(true)

proc appTicker() {.thread.} =
  while app.running:
    uiAppEvent.trigger()
    os.sleep(renderPeriodMs - 2)

proc runApplication(mainApp: MainCallback) {.thread.} =
  {.gcsafe.}:
    while app.running:
      wait(uiAppEvent)
      timeIt(appAvgTime):
        tickMain()
        eventMain()
        mainApp()
        app.frameCount.inc()

proc init*(renderer: Renderer) =
  sendRoot = proc (nodes: sink RenderNodes) =
      renderer.updated = true
      renderer.nodes = nodes

proc run*(renderer: Renderer) =

  sendRoot = proc (nodes: sink RenderNodes) =
      renderer.updated = true
      renderer.nodes = nodes

  uiRenderEvent = initUiEvent()
  uiAppEvent = initUiEvent()

  createThread(frameTickThread, renderTicker)
  createThread(appTickThread, appTicker)
  createThread(appThread, runApplication, mainApp)

  proc ctrlc() {.noconv.} =
    echo "Got Ctrl+C exiting!"
    app.running = false
  setControlCHook(ctrlc)

  runRenderer(renderer)
  # while not renderer.window.closeRequested:
  #   pollEvents()
