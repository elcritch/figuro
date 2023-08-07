
import std/tables, std/sets, std/macros, std/sysrand
import std/sugar, std/options
import std/times

import pkg/threading/channels
import pkg/variant

import equeues
import protocol

export protocol, equeues
export sets, channels
export sugar, options
export variant


type

  ConversionError* = object of CatchableError
  AgentSlotError* = object of CatchableError

  AgentErrorStackTrace* = object
    code*: int
    msg*: string
    stacktrace*: seq[string]

  # Context for servicing an RPC call 
  RpcContext* = RootRef

  # Procedure signature accepted as an RPC call by server
  AgentProc* = proc(context: RpcContext,
                    params: RpcParams,
                    ) {.gcsafe, nimcall.}

  AgentBindError* = object of ValueError
  AgentAddressUnresolvableError* = object of ValueError

  RpcSubId* = int32
  RpcSubOpts* = object
    subid*: RpcSubId
    evt*: Event
    timeout*: Duration
    source*: string

  RpcStreamSerializerClosure* = proc(): RpcParams {.closure.}

  RpcSubClients* = object
    eventProc*: RpcStreamSerializerClosure
    subs*: TableRef[ClientId, RpcSubId]

  AgentRouter* = ref object
    procs*: Table[string, AgentProc]
    sysprocs*: Table[string, AgentProc]
    subEventProcs*: Table[Event, RpcSubClients]
    subNames*: Table[string, Event]
    stacktraces*: bool
    subscriptionTimeout*: Duration
    inQueue*: EventQueue[Variant]
    outQueue*: EventQueue[Variant]
    registerQueue*: EventQueue[InetQueueItem[RpcSubOpts]]

type
  ## Rpc Streamer Task types
  RpcStreamSerializer*[T] =
    proc(queue: EventQueue[T]): RpcStreamSerializerClosure {.nimcall.}

  TaskOption*[T] = object
    data*: T
    ch*: Chan[T]

  RpcStreamTask*[T, O] = proc(queue: EventQueue[T], options: TaskOption[O])

  ThreadArg*[T, U] = object
    queue*: EventQueue[T]
    opt*: TaskOption[U]

  RpcStreamThread*[T, U] = Thread[ThreadArg[T, U]]

proc pack*[T](ss: var Variant, val: T) =
  echo "Pack Type: ", getTypeId(T), " <- ", typeof(val)
  ss = newVariant(val)

proc unpack*[T](ss: Variant, obj: var T) =
  if ss.ofType(T):
    obj = ss.get(T)
  else:
    raise newException(ConversionError, "couldn't convert to: " & $(T))

proc randBinString*(): RpcSubId =
  var idarr: array[sizeof(RpcSubId), byte]
  if urandom(idarr):
    result = cast[RpcSubId](idarr)
  else:
    result = RpcSubId(0)

proc newAgentRouter*(
    inQueueSize = 2,
    outQueueSize = 2,
    registerQueueSize = 2,
): AgentRouter =
  new(result)
  result.procs = initTable[string, AgentProc]()
  result.sysprocs = initTable[string, AgentProc]()
  result.subEventProcs = initTable[Event, RpcSubClients]()
  # result.stacktraces = defined(debug)
  result.stacktraces = true

  let
    inQueue = EventQueue[Variant].init(size=inQueueSize)
    outQueue = EventQueue[Variant].init(size=outQueueSize)
    registerQueue =
      EventQueue[InetQueueItem[RpcSubOpts]].init(size=registerQueueSize)
  
  result.inQueue = inQueue
  result.outQueue = outQueue
  result.registerQueue = registerQueue

proc subscribe*(
    router: AgentRouter,
    procName: string,
    clientId: ClientId,
    timeout = initDuration(milliseconds= -1),
    source = "",
): Option[RpcSubId] =
  # send a request to Agentserver to subscribe a client to a subscription
  let 
    to =
      if timeout != initDuration(milliseconds= -1): timeout
      else: router.subscriptionTimeout
  let subid: RpcSubId = randBinString()
  # logDebug "fastrouter:subscribing::", procName, "subid:", subid
  let val = RpcSubOpts(subid: subid,
                       evt: router.subNames[procName],
                       timeout: to,
                       source: source)
  var item = isolate InetQueueItem[RpcSubOpts].init(clientId, val)
  if router.registerQueue.trySend(item):
    result = some(subid)

proc listMethods*(rt: AgentRouter): seq[string] =
  ## list the methods in the given router. 
  result = newSeqOfCap[string](rt.procs.len())
  for name in rt.procs.keys():
    result.add name

proc listSysMethods*(rt: AgentRouter): seq[string] =
  ## list the methods in the given router. 
  result = newSeqOfCap[string](rt.sysprocs.len())
  for name in rt.sysprocs.keys():
    result.add name

proc rpcPack*(res: RpcParams): RpcParams {.inline.} =
  result = res

proc rpcPack*[T](res: T): RpcParams =
  result = RpcParams(buf: newVariant(res))

proc rpcUnpack*[T](obj: var T, ss: RpcParams) =
  try:
    ss.buf.unpack(obj)
  except ConversionError as err:
    raise newException(ConversionError,
                       "unable to parse parameters: " & err.msg)
  except AssertionDefect as err:
    raise newException(ConversionError,
                       "unable to parse parameters: " & err.msg)

type
  Agent* = ref object of RootObj
    listeners: Table[string, seq[(Agent, AgentProc)]]

proc getAgentListeners*(obj: Agent,
                        sig: string
                        ): seq[(Agent, AgentProc)] =
  if obj.listeners.hasKey(sig):
    result = obj.listeners[sig]
