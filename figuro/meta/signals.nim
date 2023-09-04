import strutils, macros
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

proc getSignalName*(signal: NimNode): NimNode =
  echo "getSignalName: ", signal.treeRepr
  if signal.kind == nnkClosedSymChoice:
    result = newStrLitNode signal[0].strVal
  else:
    result = newStrLitNode signal.strVal
  echo "getSignalName:result: ", result.treeRepr

macro signalName*(signal: untyped): untyped =
  result = getSignalName(signal)

import typetraits, sequtils

proc getSignalTuple*(obj, sig: NimNode): NimNode =
  let
    otp = obj.getTypeInst
    isGeneric = otp.kind == nnkBracketExpr
    sigTyp =
      if sig.kind == nnkSym: sig.getTypeInst
      else: sig.getTypeInst
    stp =
      if sigTyp.kind == nnkProcTy: sig.getTypeInst[0]
      else: sigTyp.params()

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
  if result.len == 0:
    result = bindSym"void"
  # echo "ARG: ", result.repr
  # echo ""

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

template connect*(
    a: Agent,
    signal: typed,
    b: Agent,
    slot: untyped
) =
  when slot is AgentProc:
    let agentSlot: AgentProc = slot
  else:
    let agentSlot: AgentProc = `slot`(typeof(b))
    # echo "A: ", signalType(a).typeof.repr 
    echo "B: ", SignalTypes.`slot`(typeof(b)).typeof.repr 
  a.addAgentListeners(signalName(signal), b, agentSlot)

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
