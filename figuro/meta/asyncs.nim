
import threading/channels
import std/isolation

import ../meta
import std/uri

type
  AgentProxy*[T] = ref object of Agent
    chan*: Chan[(int, T)]

proc newAgentProxy*[T](): AgentProxy[T] =
  result = AgentProxy[T]()
  result.chan = newChan[(int, T)]()
  result.agentId = nextAgentId()

proc received*[T](proxy: AgentProxy[T], val: T) {.signal.}

proc send*[T](proxy: AgentProxy[T], obj: Agent, val: sink T) {.slot.} =
  let wref = obj.getId()
  proxy.chan.send( (wref, val) )

type
  HttpRequest* = ref object of Agent
    url: Uri

proc newHttpRequest*(url: Uri): HttpRequest =
  result = HttpRequest(url: url)
proc newHttpRequest*(url: string): HttpRequest =
  newHttpRequest(parseUri(url))

proc update*(req: HttpRequest, gotByts: int) {.signal.}
proc received*(req: HttpRequest, val: string) {.signal.}

