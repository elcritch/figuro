
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

import sigils
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
  appFrames*: Table[WeakRef[AppFrame], Renderer]
  uxInputList*: Chan[AppInputs]

const
  renderPeriodMs* {.intdefine.} = 14
  renderDuration* = initDuration(milliseconds = renderPeriodMs)

var appTickThread*: ptr SigilThreadImpl
var appThread*: ptr SigilThreadImpl

type
  AppTicker* = ref object of Agent
    period*: Duration

proc appTick*(tp: AppTicker) {.signal.}

proc appTicker*(self: AppTicker) {.slot.} =
  while app.running:
    emit self.appTick()
    os.sleep(self.period.inMilliseconds)

proc runRenderer(renderer: Renderer) =
  while app.running and renderer[].frame[].running:
    app.tickCount.inc()
    if app.tickCount == app.tickCount.typeof.high:
      app.tickCount = 0
    timeIt(renderAvgTime):
      renderer.render(false)
    os.sleep(renderDuration.inMilliseconds)

proc setupFrame*(frame: WeakRef[AppFrame]): Renderer =
  let renderer = setupRenderer(frame)
  appFrames[frame] = renderer
  result = renderer

proc run*(frameProxy: AgentProxy[AppFrame]) =
  let renderer = setupFrame(frameProxy.remote.toKind(AppFrame))

  uiRenderEvent = initUiEvent()
  uiAppEvent = initUiEvent()

  appTickThread = newSigilThread()
  appThread = newSigilThread()

  appTickThread.start()
  appThread.start()


  proc ctrlc() {.noconv.} =
    echo "Got Ctrl+C exiting!"
    app.running = false
  setControlCHook(ctrlc)

  runRenderer(renderer)
