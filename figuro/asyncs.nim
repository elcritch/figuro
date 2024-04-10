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

  AsyncExecutor* = ref object of RootObj

method run*(ap: AsyncExecutor) {.base, gcsafe.} =
  discard

variant Commands:
  Finish
  AddExec(exec: AsyncExecutor)

type
  AsyncProcessorRaw* = object
    commands*: Chan[Commands]
    thread*: Thread[SharedPtr[AsyncProcessorRaw]]

  AsyncProcessor* = SharedPtr[AsyncProcessorRaw]

  AsyncMethod*[T, U] = ref object of RootObj

proc newAsyncProcessor*(): AsyncProcessor =
  result = newSharedPtr(AsyncProcessorRaw)
  result[].commands = newChan[Commands]()

proc execute*(ah: AsyncProcessor) {.thread.} =
  var asyncExecs: seq[AsyncExecutor]
  while true:
    echo "Running ..."
    os.sleep(1_000)
    var cmd: Commands
    let hasCmd = ah[].commands.tryRecv(cmd)
    if hasCmd:
      match cmd:
        Finish:
          echo "stopping exec"
          break
        AddExec(exec):
          echo "adding exec: ", repr exec
          asyncExecs.add(exec)
    else:
      for exec in asyncExecs:
        exec.run()

proc start*(ap: AsyncProcessor) =
  createThread(ap[].thread, execute, ap)

proc finish*(ap: AsyncProcessor) =
  ap[].commands.send(Finish())

proc newAgentProxy*[T, U](): AgentProxy[T, U] =
  result = newSharedPtr(AgentProxyRaw[T, U])
  result[].inputs = newChan[AsyncMessage[T]]()
  result[].outputs = newChan[AsyncMessage[U]]()
  result[].trigger = newAsyncEvent()

proc send*[T, U](proxy: AgentProxy[T, U], agent: Agent, val: sink Isolated[T]) =
  let wref = agent.getId()
  proxy[].agents[wref] = agent
  proxy[].inputs.send(AsyncMessage[T](handle: wref, value: val.extract()))

template send*[T, U](proxy: AgentProxy[T, U], agent: Agent, val: T) =
  send(proxy, agent, isolate(val))

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
    url: Uri
  HttpResult* = object
    data: Option[string]

  AsyncHttp* = ref object of AsyncExecutor
    proxy*: AgentProxy[HttpRequest, HttpResult]


  ThreadAgent* = ref object of Agent

  HttpAgent* = ref object of ThreadAgent
    url: Uri

proc newHttpAgent*(url: Uri): HttpAgent =
  result = HttpAgent(url: url)

proc newHttpAgent*(url: string): HttpAgent =
  newHttpAgent(parseUri(url))

proc update*(req: HttpAgent, gotByts: int) {.signal.}
proc received*(req: HttpAgent, val: string) {.signal.}
