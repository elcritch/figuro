when defined(js):
  import figuro/htmlbackend
  export htmlbackend
elif defined(blank):
  import ../renderer/blank
  export blank
elif defined(boxyRenderer):
  import ../renderer/boxyBackend
  export boxyBackend
else:
  import ../renderer/openglBackend
  export openglBackend

import pkg/chronicles

import std/os

import sigils
import sigils/threads

import ../commons
import ../ui/[core, events]
import ../common/nodes/uinodes
import ../widget
import utils/cssMonitor

export core, events

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

when not compiles(AppFrame().deepCopy()):
  {.error: "This module requires --deepcopy:on compilation flag".}

when not defined(gcArc) and not defined(gcOrc) and not defined(nimdoc):
  {.error: "Figuro requires --gc:arc or --gc:orc".}

var
  appFrames*: Table[WeakRef[AppFrame], Renderer]

const
  renderPeriodMs* {.intdefine.} = 14
  renderDuration* = initDuration(milliseconds = renderPeriodMs)

var
  appTickThread*: ptr SigilThreadImpl
  cssWatcherThread*: ptr SigilThreadImpl
  appThread*: ptr SigilThreadImpl

type AppTicker* = ref object of Agent
  period*: Duration

proc appTick*(tp: AppTicker) {.signal.}

proc tick*(self: AppTicker) {.slot.} =
  notice "Start AppTicker", period = self.period
  while app.running:
    emit self.appTick()
    os.sleep(self.period.inMilliseconds)

template setupThread(thread, obj, sig, slot, starter: untyped) =
  `thread` = newSigilThread()
  let proxy = `obj`.moveToThread(`thread`)
  threads.connect(proxy, `sig`, frame, `slot`)
  threads.connect(`thread`[].agent, started, proxy, `starter`)
  `thread`.start()
  frame.proxies.add proxy

proc setupHelperThreads*(frame: AppFrame) =
  threadEffects:
    AppMainThread
  var ticker = AppTicker(period: renderDuration)
  appTickThread.setupThread(
    ticker, sig = appTick, slot = frame.frameRunner, starter = AppTicker.tick()
  )

  frame.updateTheme(themePath())
  frame.updateTheme(appThemePath())

  when not defined(noFiguroDmonMonitor):
    var cssWatcher = CssLoader(period: renderDuration)
    cssWatcherThread.setupThread(
      cssWatcher,
      sig = cssUpdate,
      slot = AppFrame.updateTheme(),
      starter = CssLoader.cssWatcher(),
    )
  else:
    echo "dmon file monitor not loaded"

proc appStart*(self: AppFrame) {.slot, forbids: [RenderThreadEff].} =
  threadEffects:
    AppMainThread
  self.setupHelperThreads()
  emit self.root.doInitialize() # run root's doInitialize now things are setup and on the right thread

proc getAppConfigFile(): string =
  # Build the full path to the Figuro config directory
  let configPath = joinPath(getConfigDir(), "figuro")

  # Check if directory exists
  if not dirExists(configPath):
    try:
      # Create directory if it doesn't exist
      createDir(configPath)
      debug "Created Figuro configuration directory at: ", configPath
    except OSError:
      debug "Error creating Figuro configuration directory at: ", configPath
      return ""
  else:
    trace "Figuro configuration directory already exists at: ", configPath

  let appFile = os.getAppFilename().splitFile().name
  let configFile = configPath / appFile & ".json"
  notice "Figuro", configFile = configFile
  return configFile

proc runForever*(frame: var AppFrame, frameRunner: AgentProcTy[tuple[]]) =
  threadEffects:
    RenderThread
  ## run figuro

  when defined(sigilsDebug):
    frame.debugName = "Frame"
  let frameRef = frame.unsafeWeakRef()
  frameRef[].configFile = getAppConfigFile()
  let renderer = frameRef.createRenderer()
  renderer.duration = renderDuration
  appFrames[frameRef] = renderer
  frame.frameRunner = frameRunner

  appThread = newSigilThread()
  let frameProxy = frame.moveToThread(appThread)
  threads.connect(appThread[].agent, started, frameProxy, appStart)
  appThread.start()

  proc ctrlc() {.noconv.} =
    notice "Got Ctrl+C exiting!"
    app.running = false

  setControlCHook(ctrlc)

  runRendererLoop(renderer)
  appTickThread.stop()
  appTickThread.join()
  appThread.stop()
  appThread.join()
  debug "App thread exited, quitting"
  quit()
