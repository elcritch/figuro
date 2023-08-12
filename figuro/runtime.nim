
# import ../figuro

import nimscripter/nimscr
from "$nim"/compiler/nimeval import findNimStdLibCompileTime
import std/[strformat, os, times, json, osproc, sequtils]

when isMainModule:
  const orgName = "script"
  const appName = "scripter"

  var 
    intr: WrappedInterpreter
    init, tick, draw: WrappedPnode
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
    init = args.getNode(0)
    tick = args.getNode(1)
    draw = args.getNode(2)


# proc createWindowImpl(args: VmArgs) {.cdecl.} =
#   {.cast(gcSafe).}:
#     setWindowTitle($args.getString(0))

const 
  vmProcs* = [
    VmProcSignature(package: "script", name: "test", module: "figuroscript", vmProc: testImpl),
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
  if intr != nil and draw != nil:
    discard intr.invoke(draw, [])

proc invokeVmUpdate*(dt: float32) =
  if intr != nil and draw != nil:
    discard intr.invoke(update, [newNode dt])

proc invokeVmDraw*() =
  if intr != nil and draw != nil:
    discard intr.invoke(draw, [])

when isMainModule:
  intr = loadTheScript(addins)
  invokeVmInit()
