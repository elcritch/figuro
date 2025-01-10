
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

type
  RenderTicker* = ref object of Agent

var
  runFrame*: proc(frame: AppFrame) {.nimcall.}
  appFrames*: Table[AppFrame, Renderer]

const
  renderPeriodMs {.intdefine.} = 16
  appPeriodMs {.intdefine.} = 16
  renderDuration = initDuration(milliseconds = renderPeriodMs)
  appDuration  = initDuration(milliseconds = appPeriodMs)

var appTickThread: Thread[void]
var appThread, : Thread[AppFrame]

proc waitFor*(ts: var MonoTime, dur: Duration) =
  var
    next = ts
    now = getMonoTime()
    waitDur = (next-now)
  while waitDur.inMilliseconds < 0:
    next = next + dur
    waitDur = (next-now)
  # if app.tickCount mod 100 == 0:
  #   echo "render time: ", $(renderDuration-waitDur)
  os.sleep(waitDur.inMilliseconds)

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
  var ts = getMonoTime()
  while app.running and renderer.frame.running:
    app.tickCount.inc()
    if app.tickCount == app.tickCount.typeof.high:
      app.tickCount = 0
    timeIt(renderAvgTime):
      renderer.render(false)
    ts.waitFor(renderDuration)

proc setupFrame*(frame: AppFrame): Renderer =
  let renderer = setupRenderer(frame)
  appFrames[frame] = renderer
  result = renderer

proc run*(frame: AppFrame) =
  let renderer = setupFrame(frame)

  uiRenderEvent = initUiEvent()
  uiAppEvent = initUiEvent()

  createThread(appTickThread, appTicker)
  createThread(appThread, runApplication, frame)

  proc ctrlc() {.noconv.} =
    echo "Got Ctrl+C exiting!"
    app.running = false
  setControlCHook(ctrlc)

  runRenderer(renderer)
