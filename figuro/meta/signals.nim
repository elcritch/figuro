import strutils, macros, options
import std/times
import slots

import datatypes
export datatypes
export times

proc wrapResponse*(id: AgentId, resp: RpcParams, kind = Response): AgentResponse = 
  # echo "WRAP RESP: ", id, " kind: ", kind
  result.kind = kind
  result.id = id
  result.result = resp

proc wrapResponseError*(id: AgentId, err: AgentError): AgentResponse = 
  echo "WRAP ERROR: ", id, " err: ", err.repr
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
  raise err
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
      # try:
        # Handle rpc request the `context` variable is different
        # based on whether the rpc request is a system/regular/subscription
        slot(ctx, req.params)
        let res = rpcPack(true)

        result = AgentResponse(kind: Response, id: req.id, result: res)
      # except ConversionError as err:
      #   result = wrapResponseError(
      #               req.id,
      #               INVALID_PARAMS,
      #               req.procName & " raised an exception",
      #               err,
      #               true)
      # except CatchableError as err:
      #   result = wrapResponseError(
      #               req.id,
      #               INTERNAL_ERROR,
      #               req.procName & " raised an exception: " & err.msg,
      #               err,
      #               true)

template packResponse*(res: AgentResponse): Variant =
  var so = newVariant()
  so.pack(res)
  so

proc getSignalName*(signal: NimNode): NimNode =
  # echo "getSignalName: ", signal.treeRepr
  if signal.kind in [nnkClosedSymChoice, nnkOpenSymChoice]:
    result = newStrLitNode signal[0].strVal
  else:
    result = newStrLitNode signal.strVal
    # echo "getSignalName:result: ", result.treeRepr

macro signalName*(signal: untyped): untyped =
  result = getSignalName(signal)

proc splitNamesImpl(slot: NimNode): Option[(NimNode, NimNode)] =
  # echo "splitNamesImpl: ", slot.treeRepr
  if slot.kind == nnkCall and slot[0].kind == nnkDotExpr:
    return splitNamesImpl(slot[0])
  elif slot.kind == nnkCall:
    result = some (
      slot[1].copyNimTree,
      slot[0].copyNimTree,
    )
  elif slot.kind == nnkDotExpr:
    result = some (
      slot[0].copyNimTree,
      slot[1].copyNimTree,
    )
  # echo "splitNamesImpl:res: ", result.repr

macro signalType*(s: untyped): auto =
  ## gets the type of the signal without 
  ## the Agent proc type
  ## 
  let p = s.getTypeInst
  # echo "\nsignalType: ", p.treeRepr
  # echo "signalType: ", p.repr
  # echo "signalType:orig: ", s.treeRepr
  if p.kind == nnkNone:
    error("cannot determine type of: " & repr(p), p)
  if p.kind == nnkSym and p.repr == "none":
    error("cannot determine type of: " & repr(p), p)
  let obj =
    if p.kind == nnkProcTy:
      p[0]
    else:
      p[0]
  # echo "signalType:p0: ", obj.repr
  result = nnkTupleConstr.newNimNode()
  for arg in obj[2..^1]:
    result.add arg[1]

macro tryGetTypeAgentProc(slot: untyped): untyped =
  let res = splitNamesImpl(slot)
  if res.isNone:
    error("can't determine slot type", slot)
      
  let (tp, name) = res.get()

  result = quote do:
    SignalTypes.`name`(typeof(`tp`))

macro typeMismatchError(signal, slot: typed): untyped =
  error("mismatched signal and slot type: " & repr(signal) & " != " & repr(slot), slot)

proc getAgentProcTy[T](tp: AgentProcTy[T]): T =
  discard

template connect*[T](
    a: Agent,
    signal: typed,
    b: Agent,
    slot: Signal[T],
    acceptVoidSlot: static bool = false,
) =
  let agentSlot = slot
  # static:
  block:
    ## statically verify signal / slot types match
    # echo "TYP: ", repr typeof(SignalTypes.`signal`(typeof(a)))
    var signalType {.used, inject.}: typeof(SignalTypes.`signal`(typeof(a)))
    var slotType {.used, inject.}: typeof(getAgentProcTy(slot))
    when acceptVoidSlot and slotType is tuple[]:
      discard
    else:
      signalType = slotType
  a.addAgentListeners(signalName(signal), b, agentSlot)

template connect*(
    a: Agent,
    signal: typed,
    b: Agent,
    slot: typed,
    acceptVoidSlot: static bool = false,
) =
  let agentSlot = `slot`(typeof(b))
  block:
    ## statically verify signal / slot types match
    var signalType {.used, inject.}: typeof(SignalTypes.`signal`(typeof(a)))
    var slotType {.used, inject.}: typeof(getAgentProcTy(agentSlot))
    when acceptVoidSlot and slotType is tuple[]:
      discard
    else:
      signalType = slotType
  static:
    echo "TYPE CONNECT:slot: ", typeof(SignalTypes.`signal`(typeof(a)))
    echo "TYPE CONNECT:st: ", agentSlot.typeof.repr, " " , repr getAgentProcTy(agentSlot).typeof
    echo ""

  a.addAgentListeners(signalName(signal), b, agentSlot)



# template connect*(
#     a: Agent,
#     signal: typed,
#     b: Agent,
#     slot: untyped
# ) =
#   when slot is AgentProc:
#     static:
#       echo "TYPE CONNECT: ", slot.typeof.repr, " ", genericParams(slot.typeof)
#     when SignalTypes.`signal`(typeof(a)).typeof isnot
#           tryGetTypeAgentProc(slot).typeof:
#       typeMismatchError(signal, slot)
#     let agentSlot: AgentProc = slot
#   else:
#     let agentSlot: AgentProc = `slot`(typeof(b))
#   a.addAgentListeners(signalName(signal), b, agentSlot)

proc callSlots*(obj: Agent, req: AgentRequest) {.gcsafe.} =
  {.cast(gcsafe).}:
    let listeners = obj.getAgentListeners(req.procName)

    # echo "call slots:req: ", req.repr
    # echo "call slots:all: ", req.procName, " ", obj.agentId, " :: ", obj.listeners

    for (tgt, slot) in listeners:
      # echo ""
      # echo "call listener:tgt: ", tgt.agentId, " ", req.procName
      # echo "call listener:slot: ", repr slot
      let res = slot.callMethod(tgt, req)
      when defined(nimscript) or defined(useJsonSerde):
        discard
      else:
        discard
        variantMatch case res.result.buf as u
        of AgentError:
          raise newException(AgentSlotError, $u.code & " msg: " & u.msg)
        else:
          discard

proc emit*(call: (Agent, AgentRequest)) =
  let (obj, req) = call
  callSlots(obj, req)
