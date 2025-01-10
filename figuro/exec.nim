
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
import std/sharedtables

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

when not compiles(AppFrame().deepCopy()):
  {.error: "This module requires --deepcopy:on compilation flag".}

when not defined(gcArc) and not defined(gcOrc) and not defined(nimdoc):
  {.error: "Figuro requires --gc:arc or --gc:orc".}

var
  runFrame*: proc(frame: AppFrame) {.nimcall.}
  appFrames*: Table[AppFrame, Renderer]


const renderPeriodMs {.intdefine.} = 16
const appPeriodMs {.intdefine.} = 16

var frameTickThread, appTickThread: Thread[void]
var appThread, : Thread[AppFrame]

proc renderTicker() {.thread.} =
  while true:
    uiRenderEvent.trigger()
    os.sleep(appPeriodMs - 2)
    app.tickCount.inc()
    if app.tickCount == app.tickCount.typeof.high:
      app.tickCount = 0

proc appTicker() {.thread.} =
  while app.running:
    uiAppEvent.trigger()
    os.sleep(renderPeriodMs - 2)

proc runApplication(frame: AppFrame) {.thread.} =
  {.gcsafe.}:
    while app.running:
      wait(uiAppEvent)
      timeIt(appAvgTime):
        runFrame(frame)
        app.frameCount.inc()

proc runRenderer(renderer: Renderer) =
  while app.running and renderer.frame.running:
    wait(uiRenderEvent)
    timeIt(renderAvgTime):
      renderer.render(true)

proc setupFrame*(frame: AppFrame): Renderer =
  let renderer = setupRenderer(frame)
  appFrames[frame] = renderer
  result = renderer

proc run*(frame: AppFrame) =
  let renderer = setupFrame(frame)

  uiRenderEvent = initUiEvent()
  uiAppEvent = initUiEvent()

  createThread(frameTickThread, renderTicker)
  createThread(appTickThread, appTicker)
  createThread(appThread, runApplication, frame)

  proc ctrlc() {.noconv.} =
    echo "Got Ctrl+C exiting!"
    app.running = false
  setControlCHook(ctrlc)

  runRenderer(renderer)
