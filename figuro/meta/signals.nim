import tables, strutils, macros
import std/times

import datatypes
export datatypes
export times

proc wrapResponse*(id: AgentId, resp: RpcParams, kind = Response): AgentResponse = 
  result.kind = kind
  result.id = id
  result.result = resp

proc wrapResponseError*(id: AgentId, err: AgentError): AgentResponse = 
  result.kind = Error
  result.id = id
  result.result = rpcPack(err)

proc wrapResponseError*(
    id: AgentId,
    code: FastErrorCodes,
    msg: string,
    err: ref Exception,
    stacktraces: bool
): AgentResponse = 
  let errobj = AgentError(code: code, msg: msg)
  # when defined(nimscript):
  #   discard
  # else:
  #   if stacktraces and not err.isNil():
  #     errobj.trace = @[]
  #     for se in err.getStackTraceEntries():
  #       let file: string = rsplit($(se.filename), '/', maxsplit=1)[^1]
  #       errobj.trace.add( ($se.procname, file, se.line, ) )
  result = wrapResponseError(id, errobj)

proc parseError*(ss: Variant): AgentError = 
  ss.unpack(result)

proc parseParams*[T](ss: Variant, val: var T) = 
  ss.unpack(val)

proc createRpcRouter*(): AgentRouter =
  result = new(AgentRouter)
  result.procs = initTable[string, AgentProc]()

proc register*(router: var AgentRouter, path, name: string, call: AgentProc) =
  router.procs[name] = call
  echo "registering: ", name

when nimvm:
  var globalRouter {.compileTime.} = AgentRouter()
else:
  when not compiles(globalRouter):
    var globalRouter {.global.} = AgentRouter()

proc register*(path, name: string, call: AgentProc) =
  globalRouter.procs[name] = call
  echo "registering: ", name

proc listMethods*(): seq[string] =
  globalRouter.listMethods()

proc clear*(router: var AgentRouter) =
  router.procs.clear

proc hasMethod*(router: AgentRouter, methodName: string): bool =
  router.procs.hasKey(methodName)

proc callMethod*(
        slot: AgentProc,
        ctx: RpcContext,
        req: AgentRequest,
        # clientId: ClientId,
      ): AgentResponse {.gcsafe, effectsOf: slot.} =
    ## Route's an rpc request. 

    if slot.isNil:
      let msg = req.procName & " is not a registered RPC method."
      let err = AgentError(code: METHOD_NOT_FOUND, msg: msg)
      result = wrapResponseError(req.id, err)
    else:
      try:
        # Handle rpc request the `context` variable is different
        # based on whether the rpc request is a system/regular/subscription
        slot(ctx, req.params)
        let res = rpcPack(true)

        result = AgentResponse(kind: Response, id: req.id, result: res)
      except ConversionError as err:
        result = wrapResponseError(
                    req.id,
                    INVALID_PARAMS,
                    req.procName & " raised an exception",
                    err,
                    true)
      except CatchableError as err:
        result = wrapResponseError(
                    req.id,
                    INTERNAL_ERROR,
                    req.procName & " raised an exception: " & err.msg,
                    err,
                    true)

template packResponse*(res: AgentResponse): Variant =
  var so = newVariant()
  so.pack(res)
  so

macro getSignalName(signal: typed): auto =
  result = newStrLitNode signal.strVal

import typetraits, sequtils, tables

proc getSignalTuple*(obj, sig: NimNode): NimNode =
  let otp = obj.getTypeInst
  # echo "signalObjRaw:sig1: ", sig.treeRepr
  let sigTyp =
    if sig.kind == nnkSym: sig.getTypeInst
    else: sig.getTypeInst
  # echo "signalObjRaw:sig2: ", sigTyp.treeRepr
  let stp =
    if sigTyp.kind == nnkProcTy:
      sig.getTypeInst[0]
    else:
      sigTyp.params()
  let isGeneric = otp.kind == nnkBracketExpr

  # echo "signalObjRaw:obj: ", otp.repr
  # echo "signalObjRaw:obj:tr: ", otp.treeRepr
  # echo "signalObjRaw:obj:isGen: ", otp.kind == nnkBracketExpr
  # echo "signalObjRaw:sig: ", stp.repr

  var args: seq[NimNode]
  for i in 2..<stp.len:
    args.add stp[i]

  result = nnkTupleConstr.newTree()
  if isGeneric:
    template genArgs(n): auto = n[1][1]
    var genKinds: Table[string, NimNode]
    for i in 1..<stp.genArgs.len:
      genKinds[repr stp.genArgs[i]] = otp[i]
    for arg in args:
      result.add genKinds[arg[1].repr]
  else:
    # genKinds
    # echo "ARGS: ", args.repr
    for arg in args:
      result.add arg[1]
  # echo "ARG: ", result.repr
  # echo ""
  if result.len == 0:
    result = bindSym"void"

macro signalObj*(so: typed): auto =
  ## gets the type of the signal's object arg 
  ## 
  let p = so.getType
  assert p.kind != nnkNone
  echo "signalObj: ", p.repr
  echo "signalObj: ", p.treeRepr
  if p.kind == nnkSym and p.strVal == "none":
    error("cannot determine type of: " & repr(so), so)
  let obj = p[0][1]
  # result = obj[1].getTypeInst
  result = obj[1]
  echo "signalObj:end: ", result.repr

macro signalType*(p: untyped): auto =
  ## gets the type of the signal without 
  ## the Agent proc type
  ## 
  let p = p.getTypeInst
  # echo "signalType: ", p.treeRepr
  if p.kind == nnkNone:
    error("cannot determine type of: " & repr(p), p)
  if p.kind == nnkSym and p.repr == "none":
    error("cannot determine type of: " & repr(p), p)
  let obj = p[0]
  result = nnkTupleConstr.newNimNode()
  for arg in obj[2..^1]:
    result.add arg[1]
proc signalKind(p: NimNode): seq[NimNode] =
  ## gets the type of the signal without 
  ## the Agent proc type
  ## 
  let p = p.getTypeInst
  let obj = p[0]
  for arg in obj[2..^1]:
    result.add arg[1]
macro signalCheck(signal, slot: typed) =
  let ksig = signalKind(signal)
  let kslot = signalKind(slot)
  var res = true
  if ksig.len != kslot.len:
    error("signal and slot types have different number of args", signal)
  var errors = ""
  if ksig.len == kslot.len:
    for i in 0..<ksig.len():
      res = ksig[i] == kslot[i]
      if not res:
        errors &= " signal: " & ksig.repr &
                    " != slot: " & kslot.repr
        errors &= "; first mismatch: " & ksig[i].repr &
                    " != " & kslot[i].repr
        break
  if not res:
    error("signal and slot types don't match;" & errors, signal)
  else:
    result = nnkEmpty.newNimNode()
macro toSlot(slot: typed): untyped =
  echo "TO_SLOT: ", slot.treeRepr
  echo "TO_SLOT:tp: ", slot.getImpl.repr
  echo "TO_SLOT: ", slot.lineinfoObj.filename, ":", slot.lineinfoObj.line
  let name = slot.getImpl().name().repr
  echo "TO_SLOT:NAME: ", name
  let pimpl = ident("agentSlot_" & name)
  echo "pimpl: ", pimpl.treeRepr
  # let pimpl = nnkCall.newTree(
  #   ident("agentSlot" & slot[1].repr),
  #   slot[0],
  # )
  # echo "TO_SLOT: ", slot.getImpl.treeRepr
  # echo "TO_SLOT: ", slot.getTypeImpl.repr
  echo "TO_SLOT: result: ", pimpl.repr
  return pimpl

# template connect*(
#     a: Agent,
#     signal: typed,
#     b: Agent,
#     slot: typed
# ) =
#   # when getSignalTuple(a, signal) isnot getSignalTuple(b, slot):
#   #     {.error: "signal and slot types don't match".}
#   let name = getSignalName(signal)
#   static:
#     echo "TO_SLOT:IS PROC: ", slot.typeof.repr
#   a.addAgentListeners(name, b, AgentProc(toSlot(slot)))

macro connect*(
    a: Agent,
    signal: typed,
    b: Agent,
    slot: typed
) =
  # when getSignalTuple(a, signal) isnot getSignalTuple(b, slot):
  #     {.error: "signal and slot types don't match".}

  echo "\n\nAA:sig: ", signal.repr
  echo "AA:sig: ", signal.getTypeImpl.repr
  echo "AA:sig: ", signal.getImpl.repr
  echo "AA:sig:tup: ", getSignalTuple(a, signal).repr
  echo "\nAA:slot: ", slot.repr
  echo "AA:slot: ", slot.getTypeImpl.repr
  echo "AA:slot: ", slot.getTypeInst.repr
  echo "AA:slot: ", slot.getImpl.repr
  echo "AA:slot:tup: ", getSignalTuple(b, slot).repr
  if getSignalTuple(a, signal) != getSignalTuple(b, slot):
    error("signal and slot types don't match")
  # echo "A: ", getSignalTuple(a, signal)
  # echo "B: ", getSignalTuple(b, slot)

  result = newStmtList()
  # result = quote do:
  #   let name = getSignalName(signal)
  #   static:
  #     echo "TO_SLOT:IS PROC: ", slot.typeof.repr
  #   a.addAgentListeners(name, b, AgentProc(toSlot(slot)))

import pretty

proc callSlots*(obj: Agent, req: AgentRequest) {.gcsafe.} =
  {.cast(gcsafe).}:
    let listeners = obj.getAgentListeners(req.procName)

    # echo "call slots:all: ", req.procName, " ", obj.agentId, " :: ", obj.listeners

    for (tgt, slot) in listeners:
      # echo ""
      # echo "call listener:tgt: ", repr tgt
      # echo "call listener:slot: ", repr slot
      let res = slot.callMethod(tgt, req)
      variantMatch case res.result.buf as u
      of AgentError:
        raise newException(AgentSlotError, u.msg)
      else:
        discard

proc emit*(call: (Agent, AgentRequest)) =
  let (obj, req) = call
  callSlots(obj, req)
