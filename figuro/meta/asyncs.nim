
import threading/channels
import std/isolation

import ../meta
import std/uri

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
    url: Uri

proc newRequest*(url: Uri): HttpRequest =
  result = HttpRequest(url: url)
proc newRequest*(url: string): HttpRequest =
  newRequest(parseUri(url))

proc update*(req: HttpRequest, gotByts: int) {.signal.}
proc received*(req: HttpRequest, val: string) {.signal.}

