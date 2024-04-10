import threading/channels
import threading/smartptrs

import std/os
import std/options
import std/isolation
import std/uri
import std/asyncdispatch

import patty

import meta

export smartptrs
export uri

type
  AsyncMessage*[T] = object
    continued*: bool
    handle*: int
    value*: T

  AgentProxyRaw*[T, U] = object
    agents*: Table[int, Agent]
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

type
  AsyncProcessorRaw* = object
    commands*: Chan[Commands]
    thread*: Thread[SharedPtr[AsyncProcessorRaw]]
    trigger*: AsyncEvent

  AsyncProcessor* = SharedPtr[AsyncProcessorRaw]

  AsyncMethod*[T, U] = ref object of RootObj

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
  echo "newAgentProxy::trigger ", result[].trigger.repr

proc sendMsg*[T, U](proxy: AgentProxy[T, U], agent: Agent, val: sink Isolated[T]) =
  let wref = agent.getId()
  proxy[].agents[wref] = agent
  proxy[].inputs.send(AsyncMessage[T](handle: wref, value: val.extract()))
  echo "triggering event, ", proxy[].trigger.repr
  proxy[].trigger.trigger()

template sendMsg*[T, U](proxy: AgentProxy[T, U], agent: Agent, val: T) =
  sendMsg(proxy, agent, isolate(val))

proc process*[T, U](proxy: AgentProxy[T, U], maxCnt = 20) =
  mixin receive
  var cnt = maxCnt
  var msg: AsyncMessage[U]
  while proxy[].outputs.tryRecv(msg) and cnt > 0:
    let agent = proxy[].agents[msg.handle]
    if not msg.continued:
      proxy[].agents.del(msg.handle)
    receive(agent, msg.value)

type
  HttpRequest* = object
    uri*: Uri
  HttpResult* = object
    data*: Option[string]

  HttpExecutor* = ref object of AsyncExecutor
    proxy*: AgentProxy[HttpRequest, HttpResult]


  ThreadAgent* = ref object of Agent

  HttpAgent* = ref object of ThreadAgent
    url: Uri

proc send*(proxy: AgentProxy[HttpRequest, HttpResult],
           agent: Agent, uri: string) =
  let req = HttpRequest(uri: parseUri(uri))
  proxy.sendMsg(agent, isolate req)

proc newHttpExecutor*(proxy: AgentProxy[HttpRequest, HttpResult]): HttpExecutor =
  result = HttpExecutor()
  result.proxy = proxy

method setup*(ap: HttpExecutor) {.gcsafe.} =
  echo "setting up async http executor", " tid: ", getThreadId(), " trigger: ", ap.proxy[].trigger.repr 

  let cb = proc (fd: AsyncFD): bool {.closure.} =
    echo "\nrunning http executor event!"
    var msg: AsyncMessage[HttpRequest]
    if ap.proxy[].inputs.tryRecv(msg):
      echo "got message: ", msg

  ap.proxy[].trigger.addEvent(cb)

proc newHttpAgent*(url: Uri): HttpAgent =
  result = HttpAgent(url: url)

proc newHttpAgent*(url: string): HttpAgent =
  newHttpAgent(parseUri(url))

proc update*(req: HttpAgent, gotByts: int) {.signal.}
proc received*(req: HttpAgent, val: string) {.signal.}
