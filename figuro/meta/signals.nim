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

proc register*(router: var AgentRouter, path: string, call: AgentProc) =
  router.procs[path] = call
  echo "registering: ", path

proc sysRegister*(router: var AgentRouter, path: string, call: AgentProc) =
  router.sysprocs[path] = call
  echo "registering: sys: ", path

proc clear*(router: var AgentRouter) =
  router.procs.clear

proc hasMethod*(router: AgentRouter, methodName: string): bool =
  router.procs.hasKey(methodName)

proc callMethod*(
        router: AgentRouter,
        req: AgentRequest,
        clientId: ClientId,
      ): AgentResponse {.gcsafe.} =
    ## Route's an rpc request. 
    # dumpAllocstats:
    var rpcProc: AgentProc 
    case req.kind:
    of Request:
      rpcProc = router.procs.getOrDefault(req.procName)
    of SystemRequest:
      rpcProc = router.sysprocs.getOrDefault(req.procName)
    of Subscribe:
      # rpcProc = router.procs.getOrDefault(req.procName)
      echo "CALL:METHOD: SUBSCRIBE"
      let hasSubProc = req.procName in router.subNames
      if not hasSubProc:
        let methodNotFound = req.procName & " is not a registered RPC method."
        return wrapResponseError(req.id, METHOD_NOT_FOUND,
                                 methodNotFound, nil,
                                 router.stacktraces)
      # let subId = router.subscribe(req.procName, clientId)
      # if subId.isSome():
      #   let resp = %* {"subscription": subid.get()}
      #   return AgentResponse(
      #             kind: Response, id: req.id,
      #             result: resp.rpcPack())
      # else:
      #   return wrapResponseError(
      #             req.id, INTERNAL_ERROR,
      #             "", nil, router.stacktraces)
    else:
      return wrapResponseError(
                  req.id,
                  SERVER_ERROR,
                  "unimplemented request typed",
                  nil, 
                  router.stacktraces)

    if rpcProc.isNil:
      let msg = req.procName & " is not a registered RPC method."
      let err = AgentError(code: METHOD_NOT_FOUND, msg: msg)
      result = wrapResponseError(req.id, err)
    else:
      try:
        # Handle rpc request the `context` variable is different
        # based on whether the rpc request is a system/regular/subscription
        var ctx: RootObj
        # var ctx = RpcContext(callId: req.id, clientId: clientId)
        rpcProc(ctx, req.params)
        let res = RpcParams(buf: newVariant(true)) 

        result = AgentResponse(kind: Response, id: req.id, result: res)
      except ConversionError as err:
        result = wrapResponseError(
                    req.id,
                    INVALID_PARAMS,
                    req.procName & " raised an exception",
                    err, 
                    router.stacktraces)
      except CatchableError as err:
        result = wrapResponseError(
                    req.id,
                    INTERNAL_ERROR,
                    req.procName & " raised an exception",
                    err, 
                    router.stacktraces)
 
template packResponse*(res: AgentResponse): Variant =
  var so = newVariant()
  so.pack(res)
  so

proc callMethod*(router: AgentRouter,
                 buffer: Variant,
                 clientId: ClientId,
                 ): Variant =
  # logDebug("msgpack processing")
  var req: AgentRequest
  buffer.unpack(req)
  var res: AgentResponse = router.callMethod(req, clientId)
  return newVariant(res)
