
import std/tables, std/sets, std/macros, std/sysrand
import std/sugar, std/options

export sugar

import std/selectors
import std/times

import threading/channels
export sets, selectors, channels

import protocol
export protocol
export options


type
  ClientId* = int64

  FastRpcErrorStackTrace* = object
    code*: int
    msg*: string
    stacktrace*: seq[string]

  # Context for servicing an RPC call 
  RpcContext* = object
    id*: FastrpcId
    clientId*: ClientId

  # Procedure signature accepted as an RPC call by server
  FastRpcProc* = proc(params: FastRpcParamsBuffer,
                      context: RpcContext
                      ): FastRpcParamsBuffer {.gcsafe, nimcall.}

  FastRpcBindError* = object of ValueError
  FastRpcAddressUnresolvableError* = object of ValueError

  RpcSubId* = int32
  RpcSubOpts* = object
    subid*: RpcSubId
    evt*: SelectEvent
    timeout*: Duration
    source*: string

  RpcStreamSerializerClosure* = proc(): FastRpcParamsBuffer {.closure.}

  RpcSubClients* = object
    eventProc*: RpcStreamSerializerClosure
    subs*: TableRef[ClientId, RpcSubId]

  FastRpcRouter* = ref object
    procs*: Table[string, FastRpcProc]
    sysprocs*: Table[string, FastRpcProc]
    subEventProcs*: Table[SelectEvent, RpcSubClients]
    subNames*: Table[string, SelectEvent]
    stacktraces*: bool
    subscriptionTimeout*: Millis
    inQueue*: InetMsgQueue
    outQueue*: InetMsgQueue
    registerQueue*: InetEventQueue[InetQueueItem[RpcSubOpts]]


type
  ## Rpc Streamer Task types
  RpcStreamSerializer*[T] =
    proc(queue: InetEventQueue[T]): RpcStreamSerializerClosure {.nimcall.}

  TaskOption*[T] = object
    data*: T
    ch*: Chan[T]

  RpcStreamTask*[T, O] = proc(queue: InetEventQueue[T], options: TaskOption[O])


  ThreadArg*[T, U] = object
    queue*: InetEventQueue[T]
    opt*: TaskOption[U]

  RpcStreamThread*[T, U] = Thread[ThreadArg[T, U]]

proc randBinString*(): RpcSubId =
  var idarr: array[sizeof(RpcSubId), byte]
  if urandom(idarr):
    result = cast[RpcSubId](idarr)
  else:
    result = RpcSubId(0)

proc newFastRpcRouter*(
    inQueueSize = 2,
    outQueueSize = 2,
    registerQueueSize = 2,
): FastRpcRouter =
  new(result)
  result.procs = initTable[string, FastRpcProc]()
  result.sysprocs = initTable[string, FastRpcProc]()
  result.subEventProcs = initTable[SelectEvent, RpcSubClients]()
  result.stacktraces = defined(debug)

  let
    inQueue = InetMsgQueue.init(size=inQueueSize)
    outQueue = InetMsgQueue.init(size=outQueueSize)
    registerQueue =
      InetEventQueue[InetQueueItem[RpcSubOpts]].init(size=registerQueueSize)
  
  result.inQueue = inQueue
  result.outQueue = outQueue
  result.registerQueue = registerQueue

proc subscribe*(
    router: FastRpcRouter,
    procName: string,
    clientId: ClientId,
    timeout = -1.Millis,
    source = "",
): Option[RpcSubId] =
  # send a request to fastrpcserver to subscribe a client to a subscription
  let 
    to =
      if timeout != -1.Millis: timeout
      else: router.subscriptionTimeout
  let subid: RpcSubId = randBinString()
  logDebug "fastrouter:subscribing::", procName, "subid:", subid
  let val = RpcSubOpts(subid: subid,
                       evt: router.subNames[procName],
                       timeout: to,
                       source: source)
  var item = isolate InetQueueItem[RpcSubOpts].init(clientId, val)
  if router.registerQueue.trySend(item):
    result = some(subid)

proc listMethods*(rt: FastRpcRouter): seq[string] =
  ## list the methods in the given router. 
  result = newSeqOfCap[string](rt.procs.len())
  for name in rt.procs.keys():
    result.add name

proc listSysMethods*(rt: FastRpcRouter): seq[string] =
  ## list the methods in the given router. 
  result = newSeqOfCap[string](rt.sysprocs.len())
  for name in rt.sysprocs.keys():
    result.add name

proc rpcPack*(res: FastRpcParamsBuffer): FastRpcParamsBuffer {.inline.} =
  result = res

template rpcPack*(res: JsonNode): FastRpcParamsBuffer =
  var jpack = res.fromJsonNode()
  var ss = MsgBuffer.init(jpack)
  ss.setPosition(jpack.len())
  FastRpcParamsBuffer(buf: ss)

proc rpcPack*[T](res: T): FastRpcParamsBuffer =
  var ss = MsgBuffer.init()
  ss.pack(res)
  result = FastRpcParamsBuffer(buf: ss)

proc rpcUnpack*[T](obj: var T, ss: FastRpcParamsBuffer, resetStream = true) =
  try:
    if resetStream:
      ss.buf.setPosition(0)
    ss.buf.unpack(obj)
  except AssertionDefect as err:
    raise newException(ObjectConversionDefect,
                       "unable to parse parameters: " & err.msg)

template rpcQueuePacker*(procName: untyped,
                         rpcProc: untyped,
                         qt: untyped,
                            ): untyped =
  proc `procName`*(queue: `qt`): RpcStreamSerializerClosure  =
      result = proc (): FastRpcParamsBuffer =
        let res = `rpcProc`(queue)
        result = rpcPack(res)

