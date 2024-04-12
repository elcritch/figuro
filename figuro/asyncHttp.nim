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
  HttpRequest* = Uri
  HttpResult* = object
    uri*: Uri
    data*: Option[string]

  HttpProxy* = AgentProxy[HttpRequest, HttpResult]

  HttpExecutor* = ref object of AsyncExecutor
    proxy*: AgentProxy[HttpRequest, HttpResult]

  HttpAgent* = ref object of AsyncAgent[HttpResult]
    proxy*: HttpProxy

proc newHttpExecutor*(proxy: HttpProxy): HttpExecutor =
  result = HttpExecutor()
  result.proxy = proxy

method setup*(ap: HttpExecutor) {.gcsafe.} =
  echo "setting up async http executor", " tid: ", getThreadId(), " trigger: ", ap.proxy[].trigger.repr 

  let cb = proc (fd: AsyncFD): bool {.closure.} =
    var msg: AsyncMessage[HttpRequest]
    if ap.proxy[].inputs.tryRecv(msg):
      let resp = HttpResult(data: some($msg.value))
      let res = AsyncMessage[HttpResult](handle: msg.handle, value: resp)
      ap.proxy[].outputs.send(res)

  ap.proxy[].trigger.addEvent(cb)

proc new*(tp: typedesc[HttpAgent], proxy: HttpProxy): HttpAgent =
  result = HttpAgent.new()
  result.proxy = proxy

# proc receive*(ha: HttpAgent, key: AsyncKey, data: HttpResult) {.slot.} =
#   echo "http executor receive: ", data
