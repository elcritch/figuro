import threading/channels
import threading/smartptrs

import std/os
import std/monotimes
import std/options
import std/isolation
import std/uri
import std/asyncdispatch
from std/selectors import IOSelectorsException

import patty

import meta

export smartptrs
export uri

type
  AsyncAgent*[U] = ref object of Agent

  AsyncReqId* = int

  AsyncKey* = object
    reqId*: AsyncReqId
    aid*: AgentId

  AsyncMessage*[T] = object
    continued*: bool
    handle*: AsyncKey
    value*: T

  AgentProxyRaw*[T, U] = object
    agents*: Table[AsyncKey, AsyncAgent[U]]
    inputs*: Chan[AsyncMessage[T]]
    outputs*: Chan[AsyncMessage[U]]
    trigger*: AsyncEvent

  AgentProxy*[T, U] = SharedPtr[AgentProxyRaw[T, U]]

  AsyncExecutor* {.acyclic.} = ref object of RootObj

method setup*(ap: AsyncExecutor) {.base, gcsafe.} =
  discard

variant Commands:
  Finish
  AddExec(exec: AsyncExecutor)

proc received*[U](tp: AsyncAgent[U], key: AsyncKey, value: U) {.signal.}

type
  AsyncProcessorRaw* = object
    commands*: Chan[Commands]
    thread*: Thread[SharedPtr[AsyncProcessorRaw]]
    trigger*: AsyncEvent

  AsyncProcessor* = SharedPtr[AsyncProcessorRaw]

  AsyncMethod*[T, U] = ref object of RootObj

proc initAsyncKey*(agent: Agent): AsyncKey =
  AsyncKey(aid: agent.getId(), reqId: getMonoTime().ticks().int)

proc newAsyncProcessor*(): AsyncProcessor =
  result = newSharedPtr(AsyncProcessorRaw)
  result[].commands = newChan[Commands]()
  result[].trigger = newAsyncEvent()

proc execute*(ap: AsyncProcessor) {.thread.} =
  let cb = proc(fd: AsyncFD): bool {.closure.} =
    echo "running async processor command!"
    var cmd: Commands
    if ap[].commands.tryRecv(cmd):
      match cmd:
        Finish:
          raise newException(CatchableError, "finish")
        AddExec(exec):
          setup(exec)
  ap[].trigger.addEvent(cb)

  try:
    runForever()
  except CatchableError:
    echo "done"

proc start*(ap: AsyncProcessor) =
  createThread(ap[].thread, execute, ap)

proc finish*(ap: AsyncProcessor) =
  ap[].commands.send(Finish())
  ap[].trigger.trigger()

proc add*(ap: AsyncProcessor, exec: sink AsyncExecutor) =
  ap[].commands.send(unsafeIsolate AddExec(exec))
  ap[].trigger.trigger()

proc newAgentProxy*[T, U](): AgentProxy[T, U] =
  result = newSharedPtr(AgentProxyRaw[T, U])
  result[].inputs = newChan[AsyncMessage[T]]()
  result[].outputs = newChan[AsyncMessage[U]]()
  result[].trigger = newAsyncEvent()

proc send*[T, U](
    proxy: AgentProxy[T, U], agent: AsyncAgent[U], val: sink Isolated[T]
): AsyncKey {.discardable, raises: [KeyError, IOSelectorsException].} =
  let rkey = initAsyncKey(agent)
  let msg = AsyncMessage[T](handle: rkey, value: val.extract())
  if rkey in proxy[].agents:
    raise newException(KeyError, "already running")
  else:
    proxy[].agents[rkey] = agent
    proxy[].inputs.send(msg)
    proxy[].trigger.trigger()

proc poll*[T, U](proxy: AgentProxy[T, U], maxCnt = 20) =
  mixin receive
  var cnt = maxCnt
  var msg: AsyncMessage[U]
  while proxy[].outputs.tryRecv(msg) and cnt > 0:
    let agent: AsyncAgent[U] = proxy[].agents[msg.handle]
    if not msg.continued:
      proxy[].agents.del(msg.handle)
    emit agent.received(msg.handle, msg.value)

template send*[T, U](agent: AsyncAgent[U], req: T): AsyncKey =
  asyncs.send(agent.proxy, agent, isolate req)
