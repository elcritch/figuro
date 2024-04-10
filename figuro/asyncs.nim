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

  AgentExecutor* = ref object of RootObj

variant Commands:
  Finish
  AddExec(exec: AgentExecutor)

type
  AsyncProcessorRaw* = object
    finished*: bool
    commands*: Chan[Commands]

  AsyncProcessor* = SharedPtr[AsyncProcessorRaw]

  AsyncMethod*[T, U] = ref object of RootObj

proc newAsyncProcessor*(): AsyncProcessor =
  result = newSharedPtr(AsyncProcessorRaw)

proc execute*(ah: AsyncProcessor) {.thread.} =
  while not ah[].finished:
    echo "Running ..."
    os.sleep(1_000)

proc start*(ah: AsyncProcessor): Thread[AsyncProcessor] =
  createThread(result, execute, ah)

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
  ThreadAgent* = ref object of Agent

  HttpRequest* = ref object of ThreadAgent
    url: Uri

proc newHttpRequest*(url: Uri): HttpRequest =
  result = HttpRequest(url: url)

proc newHttpRequest*(url: string): HttpRequest =
  newHttpRequest(parseUri(url))

proc update*(req: HttpRequest, gotByts: int) {.signal.}
proc received*(req: HttpRequest, val: string) {.signal.}
