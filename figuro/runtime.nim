
import common/nodes/render
import shared
import engine

import nimscripter/nimscr

from "$nim"/compiler/nimeval import findNimStdLibCompileTime
import std/[strformat, os, times, json, osproc, sequtils]

when isMainModule:

  var 
    intr: WrappedInterpreter
    init, tick, draw, getRoot, getAppState: WrappedPnode
    addins: VmAddins

errorHook = proc(name: cstring, line, col: int, msg: cstring, sev: Severity) {.cdecl.} =
  echo fmt"{line}:col; {msg}"

proc runImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    echo "runImpl"
    init = args.getNode(0)
    tick = args.getNode(1)
    draw = args.getNode(2)
    getRoot = args.getNode(3)
    getAppState = args.getNode(4)

const 
  vmProcs* = [
    VmProcSignature(package: "figuro", name: "run", module: "wrappers", vmProc: runImpl),
  ]

when isMainModule:
  let theProcs = vmProcs
  addins = VmAddins(procs: cast[ptr UncheckedArray[typeof theProcs[0]]](theProcs.addr), procLen: vmProcs.len)

let
  scriptDir = getAppDir() / "../tests/"
  scriptPath = scriptDir / "twidget.nim"

proc loadTheScript*(addins: VmAddins): WrappedInterpreter =
  let (res, _) = execCmdEx("nim dump --verbosity:0 --dump.format:json dump.json")
  let jsPaths = parseJson(res)["lib_paths"]
  let oldDir = getCurrentDir()
  setCurrentDir scriptDir
  var paths = @[scriptDir]
  paths.add jsPaths.mapIt(it.getStr)
  paths.add "../" # figuro
  let cpaths = paths.mapIt(it.cstring())

  result = loadScript(cstring scriptPath, addins, cpaths, cstring findNimStdLibCompileTime(), defaultDefines)
  setCurrentDir oldDir

proc invokeVmInit*() =
  if intr != nil and init != nil:
    discard intr.invoke(init, [])

proc invokeVmTick*(frameCount: int) =
  if intr != nil and tick != nil:
    discard intr.invoke(tick, [newNode frameCount])

proc invokeVmDraw*(): int =
  if intr != nil and draw != nil:
    let res = intr.invoke(draw, [])
    result = fromVm(int, res)

proc invokeVmGetRoot*(): seq[Node] =
  if intr != nil and getRoot != nil:
    let nodes = intr.invoke(getRoot, [])
    result = fromVm(seq[Node], nodes)

proc invokeVmGetAppState*(): AppState =
  if intr != nil and getAppState != nil:
    let state = intr.invoke(getAppState, [])
    result = fromVm(AppState, state)

proc startFiguroRuntime() =
  intr = loadTheScript(addins)
  invokeVmInit()
  shared.app = invokeVmGetAppState()

  uiinputs.mouse = Mouse()
  uiinputs.mouse.pos = vec2(0, 0)

  if not app.fullscreen:
    app.windowSize = vec2(app.uiScale * app.width.float32,
                          app.uiScale * app.height.float32)

  proc appRender() =
    app.requestedFrame = invokeVmDraw()
    sendRoot(invokeVmGetRoot())

  proc appTick() =
    invokeVmTick(app.frameCount)
    discard

  proc appLoad() =
    discard

  appMain = appRender
  tickMain = appTick
  loadMain = appLoad

  let atlasStartSz = 1024 shl (app.uiScale.round().toInt() + 1)

  let
    pixelate = false
    pixelScale = 1.0
    renderer = setupRenderer(pixelate, pixelScale, atlasStartSz)

  uiinputs.mouse.pixelScale = pixelScale

  renderer.run()


when isMainModule:
  startFiguroRuntime()