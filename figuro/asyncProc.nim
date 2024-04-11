import threading/channels
import threading/smartptrs

import std/os
import std/monotimes
import std/options
import std/isolation
import std/uri
import std/asyncdispatch

import patty

import meta

export smartptrs
export uri

type
  AsyncReqId* = int

  AsyncKey* = object
    reqId*: AsyncReqId
    aid*: AgentId

  AsyncMessage*[T] = object
    continued*: bool
    handle*: AsyncKey
    value*: T

  AgentProxyRaw*[T, U] = object
    agents*: Table[AsyncKey, Agent]
    inputs*: Chan[AsyncMessage[T]]
    outputs*: Chan[AsyncMessage[U]]
    trigger*: AsyncEvent

  AgentProxy*[T, U] = SharedPtr[AgentProxyRaw[T, U]]

  AsyncExecutor* {.acyclic.} = ref object of RootObj

method setup*(ap: AsyncExecutor) {.base, gcsafe.} =
  discard

# method processOutputs*(ap: AsyncExecutor) {.base, gcsafe.} =
#   discard

variant Commands:
  Finish
  AddExec(exec: AsyncExecutor)

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
  let cb = proc (fd: AsyncFD): bool {.closure.} =
    echo "running async processor command!"
    var cmd: Commands
    if ap[].commands.tryRecv(cmd):
      match cmd:
        Finish:
          echo "stopping exec"
          raise newException(CatchableError, "finish")
        AddExec(exec):
          echo "adding exec: ", repr exec
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

proc sendMsg*[T, U](proxy: AgentProxy[T, U], agent: Agent, val: sink Isolated[T]) =
  let rkey = initAsyncKey(agent)
  let msg = AsyncMessage[T](handle: rkey, value: val.extract())
  proxy[].agents[rkey] = agent
  proxy[].inputs.send(msg)
  proxy[].trigger.trigger()

template sendMsg*[T, U](proxy: AgentProxy[T, U], agent: Agent, val: T) =
  sendMsg(proxy, agent, isolate(val))

proc process*[T, U](proxy: AgentProxy[T, U], maxCnt = 20) =
  mixin receive
  var cnt = maxCnt
  var msg: AsyncMessage[U]
  while proxy[].outputs.tryRecv(msg) and cnt > 0:
    let agent: Agent = proxy[].agents[msg.handle]
    if not msg.continued:
      proxy[].agents.del(msg.handle)
    proxy.receive(agent, msg.value)
