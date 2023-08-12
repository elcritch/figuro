
import common/nodes/render

import nimscripter/nimscr
import nimscripter/vmconversion

from "$nim"/compiler/nimeval import findNimStdLibCompileTime
import std/[strformat, os, times, json, osproc, sequtils]

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
  if intr != nil and tick != nil:
    discard intr.invoke(tick, [newNode frameCount])

proc invokeVmDraw*() =
  if intr != nil and draw != nil:
    echo "invoke draw"
    discard intr.invoke(draw, [])

import pretty
import msgpack4nim

proc invokeVmGetRoot*() =
  if intr != nil and getRoot != nil:
    echo "invoke root"
    let nodes = intr.invoke(getRoot, [])
    var str: cstring
    let res = getString(nodes, str)
    var ss = MsgStream.init($str)
    var xx: seq[Node]
    ss.unpack(xx) #and here too
    print "root: ", xx

when isMainModule:
  echo "main"
  intr = loadTheScript(addins)
  invokeVmInit()
  invokeVmDraw()
  invokeVmGetRoot()
