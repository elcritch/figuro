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
  var ss: Variant
  ss.pack(err)
  result.result = RpcParams(buf: ss)

proc wrapResponseError*(
    id: AgentId,
    code: FastErrorCodes,
    msg: string,
    err: ref Exception,
    stacktraces: bool
): AgentResponse = 
  let errobj = AgentError(code: code, msg: msg)
  if stacktraces and not err.isNil():
    errobj.trace = @[]
    for se in err.getStackTraceEntries():
      let file: string = rsplit($(se.filename), '/', maxsplit=1)[^1]
      errobj.trace.add( ($se.procname, file, se.line, ) )
  result = wrapResponseError(id, errobj)

proc parseError*(ss: Variant): AgentError = 
  ss.unpack(result)

proc parseParams*[T](ss: Variant, val: var T) = 
  ss.unpack(val)

proc createRpcRouter*(): AgentRouter =
  result = new(AgentRouter)
  result.procs = initTable[string, AgentProc]()

proc register*(router: var AgentRouter, path, name: string, call: AgentProc) =
  router.procs[path] = call
  echo "registering: ", path

proc sysRegister*(router: var AgentRouter, path, name: string, call: AgentProc) =
  router.sysprocs[path] = call
  echo "registering: sys: ", path

var globalRouter {.global.} = AgentRouter()

proc register*(path, name: string, call: AgentProc) =
  globalRouter.procs[name] = call
  echo "registering: ", name, " @ ", path

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
        clientId: ClientId,
      ): AgentResponse {.gcsafe.} =
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
        let res = RpcParams(buf: newVariant(true)) 

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

import typetraits

macro signalObj*(p: typed): auto =
  ## gets the type of the signal's object arg 
  ## 
  let p = p.getTypeInst
  let obj = p[0][1]
  result = obj[1].getTypeInst
macro signalType*(p: typed): auto =
  ## gets the type of the signal without 
  ## the Agent proc type
  ## 
  let p = p.getTypeInst
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
  var res = false
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

template connect*(
    a: Agent,
    signal: typed,
    b: Agent,
    slot: typed
) =
  # echo "signal: ", repr typeof signal
  # echo "slot: ", repr typeof slot
  when signalObj(signal) isnot Agent:
    {.error: "signal is wrong type".}
  when signalObj(slot) isnot Agent:
    {.error: "slot is wrong type".}
  signalCheck(signal, slot)

  let name = getSignalName(signal)
  a.addAgentListeners(name, b, `slot AgentSlot`)

import pretty

proc callSlots*(obj: Agent, req: AgentRequest) {.gcsafe.} =
  {.cast(gcsafe).}:
    # echo "call slot: ", req.procName
    let listeners = obj.getAgentListeners(req.procName)

    # echo "call slots: ", $obj.listeners
    for (tgt, slot) in listeners:
      # echo "call listener: ", repr tgt
      let res = slot.callMethod(tgt, req, ClientId(0))
      variantMatch case res.result.buf as u
      of AgentError:
        print u
        raise newException(AgentSlotError, u.msg)
      else:
        discard

template emit*(call: untyped) =
  call
