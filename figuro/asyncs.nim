
import threading/channels
import threading/smartptrs

import std/options
import std/isolation
import std/uri

import meta

export smartptrs

type
  AsyncMessage*[T] = object
    handle*: WeakRef[Agent]
    req*: Isolated[T]

  AgentProxy*[T, U] = object
    agents*: Table[WeakRef[Agent], Agent]
    inputs*: Chan[AsyncMessage[T]]
    outputs*: Chan[AsyncMessage[U]]
  
  AgentProxyPtr*[T, U] = SharedPtr[AgentProxy[T, U]]

proc newAgentProxy*[T, U](): AgentProxyPtr[T, U] =
  result = newSharedPtr(AgentProxy[T, U])
  result[].inputs = newChan[AsyncMessage[T]]()
  result[].outputs = newChan[AsyncMessage[U]]()

proc send*[T, U](proxy: AgentProxy[T, U], obj: Agent, val: Isolated[T]) =
  let wref = obj.getId()
  proxy.inputs.send( (wref, val) )

template send*[T, U](proxy: AgentProxy[T, U], obj: Agent, val: T) =
  send(proxy, isolate(obj))

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

