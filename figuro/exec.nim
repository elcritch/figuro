
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
import runtime/cssMonitor
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

var
  appTickThread*: ptr SigilThreadImpl
  cssLoaderThread*: ptr SigilThreadImpl
  cssWatcherThread*: ptr SigilThreadImpl
  appThread*: ptr SigilThreadImpl

type
  AppTicker* = ref object of Agent
    period*: Duration

proc appTick*(tp: AppTicker) {.signal.}

proc tick*(self: AppTicker) {.slot.} =
  echo "start tick"
  printConnections(self)
  while app.running:
    emit self.appTick()
    os.sleep(self.period.inMilliseconds)

proc updateTheme*(self: AppFrame, cssRules: seq[CssBlock]) {.slot.} =
  echo "CSS theme loaded: "
  self.theme.cssRules = cssRules
  refresh(self.root)

template setupThread(thread, obj, sig, slot, starter: untyped) =
  `thread` = newSigilThread()
  let proxy = `obj`.moveToThread(`thread`)
  threads.connect(proxy, `sig`, frame, `slot`)
  threads.connect(`thread`[].agent, started, proxy, `starter`)
  `thread`.start()
  frame.proxies.add proxy

proc setupTicker*(frame: AppFrame) =
  var ticker = AppTicker(period: renderDuration)
  appTickThread.setupThread(ticker, sig=appTick, slot=frame.frameRunner, starter=AppTicker.tick())

  var cssLoader = CssLoader(period: renderDuration)
  cssLoaderThread.setupThread(cssLoader, sig=cssUpdate, slot=AppFrame.updateTheme(), starter=CssLoader.cssLoader())
  
  var cssWatcher = CssLoader(period: renderDuration)
  cssWatcherThread.setupThread(cssWatcher, sig=cssUpdate, slot=AppFrame.updateTheme(), starter=CssLoader.cssWatcher())

proc start(self: AppFrame) {.slot.} =
  self.setupTicker()
  # self.loadTheme()

proc runRenderer(renderer: Renderer) =
  while app.running and renderer[].frame[].running:
    app.tickCount.inc()
    if app.tickCount == app.tickCount.typeof.high:
      app.tickCount = 0
    timeIt(renderAvgTime):
      renderer.render(false)
    os.sleep(renderDuration.inMilliseconds)

proc run*(frame: var AppFrame, frameRunner: AgentProcTy[tuple[]]) =
  ## run figuro
  when defined(sigilsDebug): frame.debugName = "Frame"
  let frameRef = frame.unsafeWeakRef()
  let renderer = setupRenderer(frameRef)
  appFrames[frameRef] = renderer
  frame.frameRunner = frameRunner

  uiRenderEvent = initUiEvent()
  uiAppEvent = initUiEvent()

  appThread = newSigilThread()
  let frameProxy = frame.moveToThread(ensureMove appThread)
  threads.connect(appThread[].agent, started, frameProxy, start)
  appThread.start()

  proc ctrlc() {.noconv.} =
    echo "Got Ctrl+C exiting!"
    app.running = false
  setControlCHook(ctrlc)

  runRenderer(renderer)
