
import std/[options, tables, sets, macros]
import std/times

# import pkg/threading/channels
import pkg/variant

# import equeues
import protocol

export protocol
export sets
export options
export variant

type
  Agent* = ref object of RootObj
    listeners: Table[string, seq[(Agent, AgentProc)]]

  # Context for servicing an RPC call 
  RpcContext* = Agent

  # Procedure signature accepted as an RPC call by server
  AgentProc* = proc(context: RpcContext,
                    params: RpcParams,
                    ) {.nimcall.}

type

  ConversionError* = object of CatchableError
  AgentSlotError* = object of CatchableError

  AgentErrorStackTrace* = object
    code*: int
    msg*: string
    stacktrace*: seq[string]

  AgentBindError* = object of ValueError
  AgentAddressUnresolvableError* = object of ValueError

  # RpcSubId* = int32
  # RpcSubOpts* = object
  #   subid*: RpcSubId
  #   evt*: Event
  #   timeout*: Duration
  #   source*: string

  # RpcStreamSerializerClosure* = proc(): RpcParams {.closure.}

  # RpcSubClients* = object
  #   eventProc*: RpcStreamSerializerClosure
  #   subs*: TableRef[ClientId, RpcSubId]

  AgentRouter* = ref object
    procs*: Table[string, AgentProc]
    sysprocs*: Table[string, AgentProc]
    # subEventProcs*: Table[Event, RpcSubClients]
    # subNames*: Table[string, Event]
    stacktraces*: bool
    subscriptionTimeout*: Duration
    # inQueue*: EventQueue[Variant]
    # outQueue*: EventQueue[Variant]
    # registerQueue*: EventQueue[InetQueueItem[RpcSubOpts]]

proc pack*[T](ss: var Variant, val: T) =
  echo "Pack Type: ", getTypeId(T), " <- ", typeof(val)
  ss = newVariant(val)

proc unpack*[T](ss: Variant, obj: var T) =
  if ss.ofType(T):
    obj = ss.get(T)
  else:
    raise newException(ConversionError, "couldn't convert to: " & $(T))

proc newAgentRouter*(
    inQueueSize = 2,
    outQueueSize = 2,
    registerQueueSize = 2,
): AgentRouter =
  new(result)
  result.procs = initTable[string, AgentProc]()
  result.sysprocs = initTable[string, AgentProc]()
  result.stacktraces = true

  # let
  #   inQueue = EventQueue[Variant].init(size=inQueueSize)
  #   outQueue = EventQueue[Variant].init(size=outQueueSize)
  #   registerQueue =
  #     EventQueue[InetQueueItem[RpcSubOpts]].init(size=registerQueueSize)
  
  # result.inQueue = inQueue
  # result.outQueue = outQueue
  # result.registerQueue = registerQueue


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

import typetraits, macros

proc rpcPack*[T](res: T): RpcParams =
  when defined(nimscript) or defined(useJsonSerde):
    result = RpcParams(buf: toJson(res))
  else:
    result = RpcParams(buf: newVariant(res))

proc rpcUnpack*[T](obj: var T, ss: RpcParams) =
  try:
    when defined(nimscript) or defined(useJsonSerde):
      obj.fromJson(ss.buf)
    else:
      ss.buf.unpack(obj)
  except ConversionError as err:
    raise newException(ConversionError,
                       "unable to parse parameters: " & err.msg)
  except AssertionDefect as err:
    raise newException(ConversionError,
                       "unable to parse parameters: " & err.msg)

proc getAgentListeners*(obj: Agent,
                        sig: string
                        ): seq[(Agent, AgentProc)] =
  # echo "FIND:LISTENERS: ", obj.listeners
  if obj.listeners.hasKey(sig):
    result = obj.listeners[sig]

proc addAgentListeners*(obj: Agent,
                        sig: string,
                        tgt: Agent,
                        slot: AgentProc
                        ) =
  obj.listeners.
    mgetOrPut(sig, newSeq[(Agent, AgentProc)]()).
    add((tgt, slot))
  # echo "LISTENERS: ", obj.listeners
