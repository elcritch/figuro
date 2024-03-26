
import std/[options, tables, sets, macros, hashes]
import std/times
import std/sequtils

# import pkg/threading/channels

import protocol

when defined(nimscript):
  import std/json
  import ../runtime/jsonutils_lite
  export json
elif defined(useJsonSerde):
  import std/json
  import std/jsonutils
  export json
else:
  import pkg/variant
  import threading/channels

export protocol
export sets
export options
export variant

type
  WeakRef*[T] = object
    pt* {.cursor.}: T
    ## type alias descring a weak ref that *must* be cleaned
    ## up when an object is set to be destroyed

proc `[]`*[T](r: WeakRef[T]): lent T =
  result = r.pt

proc toPtr*[T](obj: WeakRef[T]): pointer =
  result = cast[pointer](obj.pt)

proc hash*[T](obj: WeakRef[T]): Hash =
  result = hash cast[pointer](obj.pt)

proc `$`*[T](obj: WeakRef[T]): string =
  result = $(T)
  result &= "("
  result &= obj.toPtr().repr
  result &= ")"

type
  Agent* = ref object of RootObj
    agentId*: int = 0
    listeners*: Table[string, OrderedSet[AgentPairing]]
    subscribed*: HashSet[Agent]
    threadQueue*: Option[Chan[AgentRequest]]

  AgentPairing = tuple[tgt: WeakRef[Agent], fn: AgentProc]

  # Context for servicing an RPC call 
  RpcContext* = Agent

  # Procedure signature accepted as an RPC call by server
  AgentProc* = proc(context: RpcContext,
                    params: RpcParams,
                    ) {.nimcall.}

  AgentProcTy*[S] = AgentProc

  Signal*[S] = AgentProcTy[S]
  SignalTypes* = distinct object


proc `=destroy`*(agent: typeof(Agent()[])) =
  let xid: WeakRef[Agent] = WeakRef[Agent](pt: cast[Agent](addr agent))

  # echo "\ndestroy: agent: ", xid[].agentId, " pt: ", xid.toPtr.repr, " lstCnt: ", xid[].listeners.len(), " subCnt: ", xid[].subscribed.len
  # echo "subscribed: ", xid[].subscribed.toSeq.mapIt(it[].agentId).repr

  var delSigs: seq[string]
  for obj in agent.subscribed:
    # echo "freeing subscribed: ", obj[].agentId
    delSigs.setLen(0)
    for signal, listenerPairs in obj[].listeners.mpairs():
      var toDel = initOrderedSet[AgentPairing](listenerPairs.len())
      for item in listenerPairs:
        if item.tgt == xid:
          toDel.incl(item)
          # echo "agentRemoved: ", "tgt: ", xid.toPtr.repr, " id: ", agent.agentId, " obj: ", obj[].agentId, " name: ", signal
      for item in toDel:
        listenerPairs.excl(item)
      if listenerPairs.len() == 0:
        delSigs.add(signal)
    for sig in delSigs:
      obj[].listeners.del(sig)
  
  # xid[].listeners.clear()
  `=destroy`(xid[].listeners)
  `=destroy`(xid[].subscribed)
  `=destroy`(xid[].threadQueue)


when defined(nimscript):
  proc getAgentId(a: Agent): int = discard
  proc getAgentId(a: AgentProc): int = discard
  var lastUId {.compileTime.}: int = 1
else:
  proc getAgentId(a: Agent): int = cast[int](cast[pointer](a))
  proc getAgentId(a: AgentProc): int = cast[int](cast[pointer](a))
  var lastUId: int = 0

proc nextAgentId*(): int =
  lastUId.inc()
  lastUId

proc new*[T: Agent](tp: typedesc[T]): T =
  result = T()
  result.agentId = nextAgentId()

proc hash*(a: Agent): Hash = hash(getAgentId(a))
proc hash*(a: AgentProc): Hash = hash(getAgentId(a))

type

  ConversionError* = object of CatchableError
  AgentSlotError* = object of CatchableError

  AgentErrorStackTrace* = object
    code*: int
    msg*: string
    stacktrace*: seq[string]

  AgentBindError* = object of ValueError
  AgentAddressUnresolvableError* = object of ValueError

  AgentRouter* = ref object
    procs*: Table[string, AgentProc]
    sysprocs*: Table[string, AgentProc]
    stacktraces*: bool
    subscriptionTimeout*: Duration

proc pack*[T](ss: var Variant, val: T) =
  # echo "Pack Type: ", getTypeId(T), " <- ", typeof(val)
  ss = newVariant(val)

proc unpack*[T](ss: Variant, obj: var T) =
  # if ss.ofType(T):
    obj = ss.get(T)
  # else:
    # raise newException(ConversionError, "couldn't convert to: " & $(T))

proc newAgentRouter*(
    inQueueSize = 2,
    outQueueSize = 2,
    registerQueueSize = 2,
): AgentRouter =
  new(result)
  result.procs = initTable[string, AgentProc]()
  result.sysprocs = initTable[string, AgentProc]()
  result.stacktraces = true

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
  when defined(nimscript) or defined(useJsonSerde):
    let jn = toJson(res)
    result = RpcParams(buf: jn)
  else:
    result = RpcParams(buf: newVariant(res))

proc rpcUnpack*[T](obj: var T, ss: RpcParams) =
  # try:
    when defined(nimscript) or defined(useJsonSerde):
      obj.fromJson(ss.buf)
      discard
    else:
      ss.buf.unpack(obj)
  # except ConversionError as err:
  #   raise newException(ConversionError,
  #                      "unable to parse parameters: " & err.msg & " res: " & $repr(ss.buf))
  # except AssertionDefect as err:
  #   raise newException(ConversionError,
  #                      "unable to parse parameters: " & err.msg)

proc initAgentRequest*[T](
  procName: string,
  args: T,
  rkind: AgentType = Request,
  id = AgentId(0),
): AgentRequest =
  # echo "AgentRequest: ", procName, " args: ", args.repr
  result = AgentRequest(
    kind: Request,
    id: AgentId(0),
    procName: procName,
    params: rpcPack(args)
  )

proc getAgentListeners*(obj: Agent,
                        sig: string
                        ): OrderedSet[(WeakRef[Agent], AgentProc)] =
  # echo "FIND:LISTENERS: ", obj.listeners
  if obj.listeners.hasKey(sig):
    result = obj.listeners[sig]

proc unsafeWeakRef*(obj: Agent): WeakRef[Agent] =
  result = WeakRef[Agent](pt: obj)

proc toRef*(obj: WeakRef[Agent]): Agent =
  result = cast[Agent](obj)


proc addAgentListeners*(obj: Agent,
                        sig: string,
                        tgt: Agent,
                        slot: AgentProc
                        ) =

  # echo "add agent listener: ", sig, " obj: ", obj.agentId, " tgt: ", tgt.agentId
  # if obj.listeners.hasKey(sig):
  #   echo "listener:count: ", obj.listeners[sig].len()
  assert slot != nil

  obj.listeners.withValue(sig, agents):
    # if (tgt.unsafeWeakRef(), slot,) notin agents[]:
    #   echo "addAgentListeners: ", "tgt: ", tgt.unsafeWeakRef().toPtr().pointer.repr, " id: ", tgt.agentId, " obj: ", obj.agentId, " name: ", sig
    agents[].incl((tgt.unsafeWeakRef(), slot,))
  do:
    # echo "addAgentListeners: ", "tgt: ", tgt.unsafeWeakRef().toPtr().pointer.repr, " id: ", tgt.agentId, " obj: ", obj.agentId, " name: ", sig
    var agents = initOrderedSet[AgentPairing]()
    agents.incl( (tgt.unsafeWeakRef(), slot,) )
    obj.listeners[sig] = move agents

  tgt.subscribed.incl(obj)
  # echo "LISTENERS: ", obj.listeners.len, " SUBSC: ", tgt.subscribed.len
