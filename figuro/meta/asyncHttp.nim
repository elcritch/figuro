import threading/channels
import threading/smartptrs

import std/os
import std/options
import std/isolation
import std/uri
import std/asyncdispatch
import std/[asyncdispatch, httpclient]

import patty

import signals, slots
import asyncs

export smartptrs
export uri
export asyncs


type
  HttpRequest* = Uri
  HttpResult* = object
    uri*: Uri
    version*: string
    status*: string
    headers*: Table[string, seq[string]]
    body*: Option[string]

  HttpProxy* = AgentProxy[HttpRequest, HttpResult]

  HttpExecutor* = ref object of AsyncExecutor
    proxy*: HttpProxy

  HttpAgent* = ref object of AsyncAgent[HttpResult]
    proxy*: HttpProxy

proc newHttpExecutor*(proxy: HttpProxy): HttpExecutor =
  result = HttpExecutor()
  result.proxy = proxy

proc httpRequest(req: HttpRequest): Future[HttpResult] {.async.} =
  discard
  var client = newAsyncHttpClient()
  let ar = await client.request(req)

  result = HttpResult(
    uri: req,
    version: ar.version,
    status: ar.status,
    # headers: ar.headers,
    # body: ar.
  )

method setup*(ap: HttpExecutor) {.gcsafe.} =
  echo "setting up async http executor", " tid: ", getThreadId(), " trigger: ", ap.proxy[].trigger.repr 

  let cb = proc (fd: AsyncFD): bool {.closure.} =
    var msg: AsyncMessage[HttpRequest]
    if ap.proxy[].inputs.tryRecv(msg):

      let resp = httpRequest(msg.value)
      proc onResult() =
        let val = resp.read()
        let res = AsyncMessage[HttpResult](handle: msg.handle, value: val)
        ap.proxy[].outputs.send(res)
      resp.addCallback(onResult)

  ap.proxy[].trigger.addEvent(cb)

proc new*(tp: typedesc[HttpAgent], proxy: HttpProxy): HttpAgent =
  result = HttpAgent.new()
  result.proxy = proxy

# proc receive*(ha: HttpAgent, key: AsyncKey, data: HttpResult) {.slot.} =
#   echo "http executor receive: ", data
