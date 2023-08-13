
import common/nodes/render
import shared
import engine

import nimscripter/nimscr

from "$nim"/compiler/nimeval import findNimStdLibCompileTime
import std/[strformat, os, times, json, osproc, sequtils]
import std/times
import std/monotimes

when isMainModule:
  const orgName = "script"
  const appName = "scripter"

  var 
    intr: WrappedInterpreter
    init, tick, draw, getRoot: WrappedPnode
    lastModification = fromUnix(0)
    addins: VmAddins

proc test() =
  echo "hi"

errorHook = proc(name: cstring, line, col: int, msg: cstring, sev: Severity) {.cdecl.} =
  echo fmt"{line}:col; {msg}"

proc testImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    test()

# proc btnImpl(args: VmArgs) {.cdecl.} =
#   {.cast(gcSafe).}:
#     args.setResult(btn(NicoButton args.getInt(0)))

proc runImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    echo "runImpl"
    init = args.getNode(0)
    tick = args.getNode(1)
    draw = args.getNode(2)
    getRoot = args.getNode(3)

# proc createWindowImpl(args: VmArgs) {.cdecl.} =
#   {.cast(gcSafe).}:
#     setWindowTitle($args.getString(0))

const 
  vmProcs* = [
    VmProcSignature(package: "figuro", name: "test", module: "wrappers", vmProc: testImpl),
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
  echo "tick"
  if intr != nil and tick != nil:
    discard intr.invoke(tick, [newNode frameCount])

proc invokeVmDraw*() =
  if intr != nil and draw != nil:
    echo "invoke draw"
    discard intr.invoke(draw, [])

import pretty
import msgpack4nim

proc invokeVmGetRoot*(): seq[Node] =
  if intr != nil and getRoot != nil:
    echo "invoke root"
    let nodes = intr.invoke(getRoot, [])
    # print nodes
    result = fromVm(seq[Node], nodes)

proc startFiguroRuntime() =
  # appWidget = widget

  app.fullscreen = false
  uiinputs.mouse = Mouse()
  uiinputs.mouse.pos = vec2(0, 0)

  # todo: setup AppState transfer
  let
    w = 620
    h = 140
  
  if not app.fullscreen:
    app.windowSize = vec2(app.uiScale * w.float32, app.uiScale * h.float32)

  proc appRender() =
    invokeVmDraw()
    sendRoot(invokeVmGetRoot())

  proc appTick() =
    invokeVmTick(app.frameCount)
    discard

  proc appLoad() =
    discard

  appMain = appRender
  tickMain = appTick
  loadMain = appLoad

  intr = loadTheScript(addins)
  invokeVmInit()

  let atlasStartSz = 1024 shl (app.uiScale.round().toInt() + 1)

  let
    pixelate = false
    pixelScale = 1.0
    renderer = setupRenderer(pixelate, pixelScale, atlasStartSz)

  uiinputs.mouse.pixelScale = pixelScale

  renderer.run()


when isMainModule:
  startFiguroRuntime()