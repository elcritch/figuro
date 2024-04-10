
import threading/channels
import threading/smartptrs

import std/options
import std/isolation
import std/uri

import meta

export smartptrs

type
  AsyncMessage*[T] = object
    handle*: int
    req*: T

  AgentProxyRaw*[T, U] = object
    agents*: Table[WeakRef[Agent], Agent]
    inputs*: Chan[AsyncMessage[T]]
    outputs*: Chan[AsyncMessage[U]]
  
  AgentProxy*[T, U] = SharedPtr[AgentProxyRaw[T, U]]

proc newAgentProxy*[T, U](): AgentProxy[T, U] =
  result = newSharedPtr(AgentProxyRaw[T, U])
  result[].inputs = newChan[AsyncMessage[T]]()
  result[].outputs = newChan[AsyncMessage[U]]()

proc send*[T, U](proxy: AgentProxy[T, U],
                 obj: Agent,
                 val: sink Isolated[T]) =
  let wref = obj.getId()
  proxy[].inputs.send( AsyncMessage[T](handle: wref, req: val.extract()) )

template send*[T, U](proxy: AgentProxy[T, U], obj: Agent, val: T) =
  send(proxy, obj, isolate(val))

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

