
import threading/channels
import std/isolation

import ../meta

type
  AgentProxy*[T] = ref object of Agent
    chan*: Chan[(int, T)]

proc received*[T](proxy: AgentProxy[T], val: T) {.signal.}

proc send*[T](proxy: AgentProxy[T], obj: Agent, val: sink T) {.slot.} =
  let wref = obj.getId()
  proxy.chan.send( (wref, val) )
  discard

type
  HttpRequest* = ref object of Agent
    url: string

proc newRequest*(url: string): HttpRequest =
  result = HttpRequest(url: url)

proc update*(req: HttpRequest, gotByts: int) {.signal.}
proc received*(req: HttpRequest, val: string) {.signal.}

