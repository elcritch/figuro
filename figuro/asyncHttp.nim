import threading/channels
import threading/smartptrs

import std/os
import std/options
import std/isolation
import std/uri
import std/asyncdispatch

import patty

import meta
import asyncs

export smartptrs
export uri
export asyncs


type
  HttpRequest* = object
    uri*: Uri
  HttpResult* = object
    data*: Option[string]

  HttpProxy* = AgentProxy[HttpRequest, HttpResult]

  HttpExecutor* = ref object of AsyncExecutor
    proxy*: AgentProxy[HttpRequest, HttpResult]

  ThreadAgent* = ref object of Agent

  HttpAgent* = ref object of ThreadAgent
    url: Uri

proc send*(proxy: HttpProxy, agent: Agent, uri: string) =
  let req = HttpRequest(uri: parseUri(uri))
  proxy.sendMsg(agent, isolate req)

proc newHttpExecutor*(proxy: HttpProxy): HttpExecutor =
  result = HttpExecutor()
  result.proxy = proxy

method setup*(ap: HttpExecutor) {.gcsafe.} =
  echo "setting up async http executor", " tid: ", getThreadId(), " trigger: ", ap.proxy[].trigger.repr 

  let cb = proc (fd: AsyncFD): bool {.closure.} =
    echo "\nrunning http executor event!"
    var msg: AsyncMessage[HttpRequest]
    if ap.proxy[].inputs.tryRecv(msg):
      echo "got message: ", msg
      let resp = HttpResult(data: some($msg.value.uri))
      let res = AsyncMessage[HttpResult](handle: msg.handle, value: resp)
      ap.proxy[].outputs.send(res)

  ap.proxy[].trigger.addEvent(cb)

proc receive*(proxy: HttpProxy, ap: Agent, data: HttpResult) {.gcsafe.} =
  echo "http executor receive: "

proc newHttpAgent*(url: Uri): HttpAgent =
  result = HttpAgent(url: url)

proc newHttpAgent*(url: string): HttpAgent =
  newHttpAgent(parseUri(url))

proc update*(req: HttpAgent, gotByts: int) {.signal.}
proc received*(req: HttpAgent, val: string) {.signal.}
