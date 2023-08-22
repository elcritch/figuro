
import common/nodes/render
import shared
import exec

import nimscripter/nimscr

from "$nim"/compiler/nimeval import findNimStdLibCompileTime
import std/[strformat, os, times, json, osproc, sequtils]

when isMainModule:

  var 
    intr: WrappedInterpreter
    init, tick, draw, getRoot, getAppState: WrappedPnode
    addins: VmAddins
    lastModification = fromUnix(0)


errorHook = proc(name: cstring, line, col: int, msg: cstring, sev: Severity) {.cdecl.} =
  echo fmt"{line}:col; {msg}"

proc runImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    init = args.getNode(0)
    tick = args.getNode(1)
    draw = args.getNode(2)
    getRoot = args.getNode(3)
    getAppState = args.getNode(4)

proc getAgentId(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    echo "getAgentId"
    let res = args.getNode(0)
    let id = cast[int](cast[pointer](addr(res)))
    echo "getAgentId: ", id
    args.setResult id

const 
  vmProcs* = [
    VmProcSignature(package: "figuro",
                    name: "run",
                    module: "wrappers",
                    vmProc: runImpl),
    VmProcSignature(package: "figuro",
                    name: "getAgentId",
                    module: "datatypes",
                    vmProc: getAgentId),
  ]

when isMainModule:
  let theProcs = vmProcs
  addins = VmAddins(procs: cast[ptr UncheckedArray[typeof theProcs[0]]](theProcs.addr), procLen: vmProcs.len)

let
  scriptDir = getAppDir() / "../tests/"
  # scriptPath = scriptDir / "twidget.nim"
  scriptPath = scriptDir / "tminimal.nim"

proc loadTheScript*(addins: VmAddins): WrappedInterpreter =
  let (res, _) = execCmdEx("nim dump --verbosity:0 --dump.format:json dump.json")
  let jsPaths = parseJson(res)["lib_paths"]
  let oldDir = getCurrentDir()
  setCurrentDir scriptDir
  var paths = @[scriptDir]
  paths.add jsPaths.mapIt(it.getStr)
  paths.add "../".absolutePath # figuro
  let cpaths = paths.mapIt(it.cstring())

  result = loadScript(cstring scriptPath, addins, cpaths, cstring findNimStdLibCompileTime(), defaultDefines)
  setCurrentDir oldDir

proc invokeVmInit*() =
  if intr != nil and init != nil:
    discard intr.invoke(init, [])

proc invokeVmTick*() =
  if intr != nil and tick != nil:
    let state: AppStatePartial = (
      tickCount: app.tickCount,
      requestedFrame: app.requestedFrame,
      uiScale: app.uiScale
    )
    let ret = intr.invoke(tick, [newNode state])
    let appRet = fromVm(AppStatePartial, ret)
    app.requestedFrame = appRet.requestedFrame

proc invokeVmDraw*(): AppStatePartial =
  if intr != nil and draw != nil:
    let ret = intr.invoke(draw, [])
    let appRet = fromVm(AppStatePartial, ret)
    result = appRet

proc invokeVmGetRoot*(): seq[Node] =
  if intr != nil and getRoot != nil:
    let nodes = intr.invoke(getRoot, [])
    if not nodes.isNil:
      result = fromVm(seq[Node], nodes)

proc invokeVmGetAppState*(): AppState =
  if intr != nil and getAppState != nil:
    let state = intr.invoke(getAppState, [])
    if not state.isNil:
      result = fromVm(AppState, state)

proc scriptUpdate() =
  let lastMod = getLastModificationTime(scriptPath);
  if lastMod > lastModification:
    if intr.isNil:
      intr = loadTheScript(addins)
    else:
      echo "reload"
      let saveState = intr.saveState()
      intr = loadTheScript(addins)
      # intr.reload()
      intr.loadState(saveState)
      discard intr.invoke("mySetup".cstring, [])
    if intr != nil:
      invokeVmInit()
      lastModification = lastMod

proc startFiguroRuntime() =
  scriptUpdate()
  # invokeVmInit()
  shared.app = invokeVmGetAppState()
  app.requestedFrame = 5

  if not app.fullscreen:
    app.windowSize = Position vec2(app.uiScale * app.width.float32,
                                   app.uiScale * app.height.float32)

  proc appRender() =
    let ret = invokeVmDraw()
    app.requestedFrame = ret.requestedFrame
    # echo "appRender: ", app.requestedFrame
    if not uxInputs.mouse.consumed:
      echo "got mouse: ", uxInputs.mouse.pos
      uxInputs.mouse.consumed = true
    sendRoot(invokeVmGetRoot())

  proc appTick() =
    scriptUpdate()
    invokeVmTick()
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

  renderer.run()

when isMainModule:
  startFiguroRuntime()
