
import nico
import nimscripter/nimscr
from "$nim"/compiler/nimeval import findNimStdLibCompileTime
import std/[strformat, os, times]

when isMainModule:
  const orgName = "script"
  const appName = "scripter"

  var 
    intr: WrappedInterpreter
    init, update, draw: WrappedPnode
    lastModification = fromUnix(0)
    addins: VmAddins

errorHook = proc(name: cstring, line, col: int, msg: cstring, sev: Severity) {.cdecl.} =
  echo fmt"{line}:col; {msg}"

proc clsImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    cls()

proc circImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    circ(args.getInt(0), args.getInt(1), args.getInt(2))

proc circFillImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    circFill(args.getInt(0), args.getInt(1), args.getInt(2))

proc rectImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    rect(args.getInt(0), args.getInt(1), args.getInt(2), args.getInt(3))

proc rectFillImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    rectFill(args.getInt(0), args.getInt(1), args.getInt(2), args.getInt(3))

proc setColorImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    setColor(args.getInt(0))

proc btnImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    args.setResult(btn(NicoButton args.getInt(0)))

proc btnupImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    args.setResult(btnup(NicoButton args.getInt(0)))

proc runImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    init = args.getNode(0)
    update = args.getNode(1)
    draw = args.getNode(2)

proc createWindowImpl(args: VmArgs) {.cdecl.} =
  {.cast(gcSafe).}:
    setWindowTitle($args.getString(0))
    setTargetSize args.getInt(1), args.getInt(2)
    setFullscreen(args.getBool(4))


const 
  vmProcs* = [
    VmProcSignature(package: "script", name: "cls", module: "nicoscript", vmProc: clsImpl),
    VmProcSignature(package: "script", name: "circ", module: "nicoscript", vmProc: circImpl),
    VmProcSignature(package: "script", name: "circFill", module: "nicoscript", vmProc: circFillImpl),
    VmProcSignature(package: "script", name: "rect", module: "nicoscript",  vmProc: rectImpl),
    VmProcSignature(package: "script", name: "rectFill", module: "nicoscript", vmProc: rectFillImpl),
    VmProcSignature(package: "script", name: "setColor", module: "nicoscript", vmProc: setColorImpl),
    VmProcSignature(package: "script", name: "btn", module: "nicoscript", vmProc: btnImpl),
    VmProcSignature(package: "script", name: "btnup", module: "nicoscript", vmProc: btnupImpl),
    VmProcSignature(package: "script", name: "run", module: "nicoscript", vmProc: runImpl),
    VmProcSignature(package: "script", name: "createWindow", module: "nicoscript", vmProc: createWindowImpl)
  ]

when isMainModule:
  let theProcs = vmProcs
  addins = VmAddins(procs: cast[ptr UncheckedArray[typeof theProcs[0]]](theProcs.addr), procLen: vmProcs.len)

let
  scriptDir = getAppDir() / "script"
  scriptPath = scriptDir / "script.nim"

proc loadTheScript*(addins: VmAddins): WrappedInterpreter =
  let oldDir = getCurrentDir()
  setCurrentDir scriptDir
  result = loadScript(cstring scriptPath, addins, [cstring scriptDir], cstring findNimStdLibCompileTime(), defaultDefines)
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
  proc gameInit() =
    loadFont(0, "font.png")
    intr = loadTheScript(addins)
    invokeVmInit()

  proc gameUpdate(dt: float32) =
    if (let lastMod = getLastModificationTime(scriptPath); lastMod) > lastModification:
      if intr.isNil:
        intr = loadTheScript(addins)
      else:
        let saveState = intr.saveState()
        intr.reload()
        intr.loadState(saveState)
      if intr != nil:
        lastModification = lastMod
    invokeVmUpdate(dt)

  proc gameDraw() =
    invokeVmDraw()

  nico.init(orgName, appName)
  nico.createWindow(appName, 128, 128, 4, false)
  nico.run(gameInit, gameUpdate, gameDraw)