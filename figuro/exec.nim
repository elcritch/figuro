
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

import sigils/threads

import shared, internal
import ui/[core, events]
import common/nodes/ui
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
  # runFrame*: proc(frame: AppFrame) {.nimcall.}
  appFrames*: Table[AppFrame, Renderer]
  uxInputList*: Chan[AppInputs]

const
  renderPeriodMs {.intdefine.} = 14
  renderDuration = initDuration(milliseconds = renderPeriodMs)

var appTickThread: Thread[void]
var appThread: ptr SigilThreadImpl

type
  App* = ref object of Agent
    frame: AppFrame

proc appTick*(tp: App) {.signal.}

proc appRun*(tp: App) {.slot.} =
  timeIt(appAvgTime):
    # runFrame(tp.frame)
    app.frameCount.inc()

proc appTicker() {.thread.} =
  while app.running:
    uiAppEvent.trigger()
    os.sleep(renderPeriodMs)

proc runApplication(frame: AppFrame) {.thread.} =
  {.gcsafe.}:
    while app.running:
      wait(uiAppEvent)
      timeIt(appAvgTime):
        # runFrame(frame)
        app.frameCount.inc()

proc runRenderer(renderer: Renderer) =
  while app.running and renderer.frame.running:
    app.tickCount.inc()
    if app.tickCount == app.tickCount.typeof.high:
      app.tickCount = 0
    timeIt(renderAvgTime):
      renderer.render(false)
    os.sleep(renderDuration.inMilliseconds)

proc setupFrame*(frame: AppFrame): Renderer =
  let renderer = setupRenderer(frame)
  appFrames[frame] = renderer
  result = renderer

proc run*(frame: AppFrame) =
  let renderer = setupFrame(frame)

  uiRenderEvent = initUiEvent()
  uiAppEvent = initUiEvent()

  createThread(appTickThread, appTicker)
  # createThread(appThread, runApplication, frame)
  appThread = newSigilThread()
  appThread.start()

  # connect(appThread, valueChanged, b, setValueGlobal)


  proc ctrlc() {.noconv.} =
    echo "Got Ctrl+C exiting!"
    app.running = false
  setControlCHook(ctrlc)

  runRenderer(renderer)
