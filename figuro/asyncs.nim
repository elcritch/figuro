
import threading/channels
import std/options
import std/isolation
import std/uri

import meta

type
  ThreadAgentMessage* = object
    handle*: WeakRef[Agent]
    req*: AgentRequest

  ThreadAgent* = ref object of Agent

  AgentProxy* = ref object of Agent
    agents*: Table[WeakRef[Agent], Agent]
    inputs*: Option[Chan[ThreadAgentMessage]]
    outputs*: Option[Chan[ThreadAgentMessage]]

proc newAgentProxy*(): AgentProxy =
  result = AgentProxy()
  result.inputs = newChan[ThreadAgentMessage]().some
  result.outputs = newChan[ThreadAgentMessage]().some
  result.agentId = nextAgentId()

# proc received*[T](proxy: AgentProxy[T], val: T) {.signal.}

# proc send*[T](proxy: AgentProxy, obj: Agent, val: sink T) {.slot.} =
#   let wref = obj.getId()
#   proxy.inputs.send( (wref, val) )

type
  HttpRequest* = ref object of ThreadAgent
    url: Uri

proc newHttpRequest*(url: Uri): HttpRequest =
  result = HttpRequest(url: url)
proc newHttpRequest*(url: string): HttpRequest =
  newHttpRequest(parseUri(url))

proc update*(req: HttpRequest, gotByts: int) {.signal.}
proc received*(req: HttpRequest, val: string) {.signal.}

