import threading/channels
import threading/smartptrs

import std/os
import std/options
import std/isolation
import std/uri
import std/asyncdispatch

import patty

import meta
import asyncProc

export smartptrs
export uri
export asyncProc


type
  HttpRequest* = object
    uri*: Uri
  HttpResult* = object
    data*: Option[string]

  HttpExecutor* = ref object of AsyncExecutor
    proxy*: AgentProxy[HttpRequest, HttpResult]


  ThreadAgent* = ref object of Agent

  HttpAgent* = ref object of ThreadAgent
    url: Uri

proc send*(proxy: AgentProxy[HttpRequest, HttpResult],
           agent: Agent, uri: string) =
  let req = HttpRequest(uri: parseUri(uri))
  proxy.sendMsg(agent, isolate req)

proc newHttpExecutor*(proxy: AgentProxy[HttpRequest, HttpResult]): HttpExecutor =
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

proc receive*(ap: HttpExecutor, maxCnt = 20) {.gcsafe.} =
  var cnt = maxCnt
  var msg: AsyncMessage[HttpResult]
  while ap.proxy[].outputs.tryRecv(msg) and cnt > 0:
    let agent = ap.proxy[].agents[msg.handle]
    if not msg.continued:
      ap.proxy[].agents.del(msg.handle)

proc newHttpAgent*(url: Uri): HttpAgent =
  result = HttpAgent(url: url)

proc newHttpAgent*(url: string): HttpAgent =
  newHttpAgent(parseUri(url))

proc update*(req: HttpAgent, gotByts: int) {.signal.}
proc received*(req: HttpAgent, val: string) {.signal.}
