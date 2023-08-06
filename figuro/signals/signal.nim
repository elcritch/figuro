import tables, strutils, macros

import mcu_utils/basictypes
import mcu_utils/msgbuffer
import mcu_utils/logging
include mcu_utils/threads


import datatypes
export datatypes
export Millis

proc wrapResponse*(id: FastRpcId, resp: FastRpcParamsBuffer, kind = Response): FastRpcResponse = 
  result.kind = kind
  result.id = id
  result.result = resp

proc wrapResponseError*(id: FastRpcId, err: FastRpcError): FastRpcResponse = 
  result.kind = Error
  result.id = id
  var ss = MsgBuffer.init()
  ss.pack(err)
  result.result = FastRpcParamsBuffer(buf: ss)

proc wrapResponseError*(id: FastRpcId, code: FastErrorCodes, msg: string, err: ref Exception, stacktraces: bool): FastRpcResponse = 
  let errobj = FastRpcError(code: SERVER_ERROR, msg: msg)
  if stacktraces and not err.isNil():
    errobj.trace = @[]
    for se in err.getStackTraceEntries():
      let file: string = rsplit($(se.filename), '/', maxsplit=1)[^1]
      errobj.trace.add( ($se.procname, file, se.line, ) )
  result = wrapResponseError(id, errobj)

proc parseError*(ss: MsgBuffer): FastRpcError = 
  ss.unpack(result)

proc parseParams*[T](ss: MsgBuffer, val: var T) = 
  ss.unpack(val)

proc createRpcRouter*(): FastRpcRouter =
  result = new(FastRpcRouter)
  result.procs = initTable[string, FastRpcProc]()

proc register*(router: var FastRpcRouter;
               path: string,
               evt: SelectEvent,
               serializer: RpcStreamSerializerClosure) =
  router.subNames[path] = evt
  let subs = newTable[InetClientHandle, RpcSubId]()
  router.subEventProcs[evt] = RpcSubClients(eventProc: serializer, subs: subs)
  echo "registering:sub: ", path

proc register*(router: var FastRpcRouter, path: string, call: FastRpcProc) =
  router.procs[path] = call
  echo "registering: ", path

proc sysRegister*(router: var FastRpcRouter, path: string, call: FastRpcProc) =
  router.sysprocs[path] = call
  echo "registering: sys: ", path

proc clear*(router: var FastRpcRouter) =
  router.procs.clear

proc hasMethod*(router: FastRpcRouter, methodName: string): bool =
  router.procs.hasKey(methodName)

proc callMethod*(
        router: FastRpcRouter,
        req: FastRpcRequest,
        clientId: InetClientHandle,
      ): FastRpcResponse {.gcsafe.} =
    ## Route's an rpc request. 
    # dumpAllocstats:
    var rpcProc: FastRpcProc 
    case req.kind:
    of Request:
      rpcProc = router.procs.getOrDefault(req.procName)
    of SystemRequest:
      rpcProc = router.sysprocs.getOrDefault(req.procName)
    of Subscribe:
      # rpcProc = router.procs.getOrDefault(req.procName)
      echo "CALL:METHOD: SUBSCRIBE"
      let hasSubProc = req.procname in router.subNames
      if not hasSubProc:
        let methodNotFound = req.procName & " is not a registered RPC method."
        return wrapResponseError(req.id, METHOD_NOT_FOUND,
                                 methodNotFound, nil,
                                 router.stacktraces)
      let subId = router.subscribe(req.procName, clientId)
      if subId.isSome():
        let resp = %* {"subscription": subid.get()}
        return FastRpcResponse(
                  kind: Response, id: req.id,
                  result: resp.rpcPack())
      else:
        return wrapResponseError(
                  req.id, INTERNAL_ERROR,
                  "", nil, router.stacktraces)
    else:
      return wrapResponseError(
                  req.id,
                  SERVER_ERROR,
                  "unimplemented request typed",
                  nil, 
                  router.stacktraces)

    if rpcProc.isNil:
      let msg = req.procName & " is not a registered RPC method."
      let err = FastRpcError(code: METHOD_NOT_FOUND, msg: msg)
      result = wrapResponseError(req.id, err)
    else:
      try:
        # Handle rpc request the `context` variable is different
        # based on whether the rpc request is a system/regular/subscription
        var ctx: RpcContext
        # var ctx = RpcContext(callId: req.id, clientId: clientId)
        let res: FastRpcParamsBuffer =
          rpcProc(req.params, ctx)

        result = FastRpcResponse(kind: Response, id: req.id, result: res)
      except ObjectConversionDefect as err:
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
 
template packResponse*(res: FastRpcResponse, size: int): QMsgBuffer =
  var so = newUniquePtr(MsgBuffer.init(size))
  so[].pack(res)
  so

proc callMethod*(router: FastRpcRouter,
                 buffer: MsgBuffer,
                 clientId: InetClientHandle,
                 ): QMsgBuffer =
  logDebug("msgpack processing")
  var req: FastRpcRequest
  buffer.unpack(req)
  var res: FastRpcResponse = router.callMethod(req, clientId)
  return res.packResponse(res.result.buf.data.len() + sizeof(res))
  