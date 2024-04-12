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
    proxy: HttpProxy

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

proc submit*(agent: HttpAgent, uri: Uri): AsyncKey {.discardable.} =
  let req = HttpRequest(uri: uri)
  agent.proxy.sendMsg(agent, isolate req)


proc newHttpAgent*(proxy: HttpProxy): HttpAgent =
  result = HttpAgent(proxy: proxy)

proc received*(tp: HttpAgent, key: AsyncKey, value: HttpResult) {.signal.}

proc receive*(proxy: HttpProxy, ap: Agent, data: HttpResult) {.gcsafe.} =
  echo "http executor receive: ", data, " tp: ", ap is HttpAgent


