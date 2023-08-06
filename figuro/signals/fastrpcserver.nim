import mcu_utils/inettypes
import mcu_utils/inetqueues
import mcu_utils/timeutils

include mcu_utils/threads

import router
import ../servertypes
import ../serverutils
import ../socketserver

export router, servertypes, socketserver

import std/times

type 

  UdpClientOpts = object
    timeout: Millis
    ts: Millis

  FastRpcOpts* = ref object
    router*: FastRpcRouter
    bufferSize*: int
    prefixMsgSize*: bool
    # inetQueue*: seq[InetMsgQueue]
    task*: Thread[FastRpcRouter]
    udpRpcSubs*: Table[RpcSubId, UdpClientOpts]

## =================== Handle RPC Events =================== ##

proc findMatchingUdpSockets(
    srv: ServerInfo[FastRpcOpts],
    cid: InetClientHandle,
): seq[SocketHandle] =
  ## find matching sockets for a generic UDP subscription
  ## like multicast subs. A bit ugly, but works for now. 
  let cidDomain = 
    if cid[].host.family == IPv6: Domain.AF_INET6
    else: Domain.AF_INET
  for fid, receiver in srv.receivers:
    # check each receiver socket to find a matching UDP one
    if receiver.getProtocol() == Protocol.IPPROTO_UDP:
      if receiver.getDomain() == cidDomain:
        result.add(receiver.getFd())

proc fastRpcInetReplies*(
        srv: ServerInfo[FastRpcOpts],
        queue: InetMsgQueue,
      ) =
  logDebug("fastRpcEventHandler:eventHandler:")
  var item: InetMsgQueueItem
  while queue.tryRecv(item):
    logDebug("fastRpcEventHandler:item: ", repr(item))
    case item.cid[].kind:
    of clSocket:
      withReceiverSocket(sock, item.cid[].fd, "fasteventhandler"):
        var msg: MsgBuffer = item.data[]
        logDebug("fastRpcEventHandler:reply:tcp:", "sock:", repr(sock.getFd()))
        var lenBuf = newString(2)
        lenBuf.toStrBe16(msg.data.len().int16)
        sock.sendSafe(lenBuf & msg.data)
    of clAddress:
      logDebug("fastRpcEventHandler:reply:udp:", repr(item.cid))
      let cid = item.cid
      withReceiverSocket(sock, item.cid[].sfd, "fasteventhandler"):
        var msg: MsgBuffer = item.data[]
        logDebug("fastRpcEventHandler:reply:udp:", "sock:", repr(sock.getFd()))
        sock.sendTo(cid[].host, cid[].port, msg.data)
    of clCanBus:
      raise newException(Exception, "TODO: canbus sender")
    of clEmpty:
      raise newException(Exception, "empty inet handle")

proc fastRpcEventHandler*(
        srv: ServerInfo[FastRpcOpts],
        evt: SelectEvent,
      ) =
  logDebug("fastRpcEventHandler:eventHandler:")
  let router = srv.getOpts().router

  logDebug("fastRpcEventHandler:loop")

  if evt == router.outQueue.evt:
    # process outgoing inet replies 
    srv.fastRpcInetReplies(router.outQueue)
  elif evt == router.registerQueue.evt:
    # process inputs on the "register queue"
    # and add them to the sub-events table
    logDebug("fastRpcEventHandler:registerQueue: ", repr(evt))
    var item: InetQueueItem[RpcSubOpts]
    while router.registerQueue.tryRecv(item):
      logDebug("fastRpcEventHandler:regQueue:cid: ", repr item.cid)
      let opts = item.data
      let cidEvt = opts.evt
      var cid = item.cid
      case cid[].kind:
      of InetClientType.clSocket:
        router.subEventProcs[cidEvt].subs[cid] = opts.subId
      of InetClientType.clAddress:
        logDebug("fastRpcEventHandler:sub:registering")
        let udpopts = UdpClientOpts(timeout: opts.timeout, ts: millis())
        srv.getOpts().udpRpcSubs[opts.subid] = udpopts
        var fds = newSeq[SocketHandle]()
        if cid[].sfd == SocketHandle -1:
          fds.add srv.findMatchingUdpSockets(cid)
        else:
          fds.add cid[].sfd
        for fd in fds:
          let cidFd = newClientHandle(cid[].host, cid[].port, fd, cid[].protocol)
          logDebug("fastRpcEventHandler:sub:registering:cid: ", repr cidFd)
          router.subEventProcs[cidEvt].subs[cidFd] = opts.subId
      else:
        raise newException(ValueError, "unhandled cid subscription: " & repr(cid))
  elif evt in router.subEventProcs:
    logDebug("fastRpcEventHandler:subEventProcs: ", repr(evt))
    # get event serializer and run it to get back the ParamsBuffer 
    let subClient = router.subEventProcs[evt]
    let msg: FastRpcParamsBuffer = subClient.eventProc()
    # now wrap response msg for each subscriber client 
    for cid, subid in subClient.subs:
      let resp: FastRpcResponse =
        wrapResponse(subid.FastRpcId, msg, kind=Publish)
      var qmsg = resp.packResponse(msg.buf.data.len())
      discard router.outQueue.trySendMsg(cid, qmsg)
  else:
    raise newException(ValueError, "unknown queue event: " & repr(evt))

## =================== Read RPC Tasks =================== ##
proc fastRpcReadHandler*(
        srv: ServerInfo[FastRpcOpts],
        sock: Socket,
      ) =
  var
    buffer = newQMsgBuffer(srv.getOpts().bufferSize)
    host: IpAddress
    port: Port

  logDebug("server:fastRpcReadHandler:")
  var clientId: InetClientHandle

  # Get network data
  let fdkind = srv.selector.getData(sock.getFd())
  let stype: SockType = fdkind.getSockType().get()

  if stype == SockType.SOCK_STREAM:
    discard sock.recv(buffer[].data, srv.getOpts().bufferSize)
    if buffer[].data == "":
      raise newException(InetClientDisconnected, "")
    let
      msglen = buffer[].readUintBe16().int
    if buffer[].data.len() != 2 + msglen:
      raise newException(OSError, "invalid length: read: " &
                          $buffer[].data.len() & " expect: " & $(2 + msglen))
    clientId = newClientHandle(sock.getFd())
  elif stype == SockType.SOCK_DGRAM:
    discard sock.recvFrom(buffer[].data, buffer[].data.len(), host, port)
    clientId  = newClientHandle(host, port, sock.getFd())
  else:
    raise newException(ValueError, "unhandled socket type: " & $stype)

  # process rpc
  let router = srv.getOpts().router
  # var response = fastRpcExec(router, buffer, clientId)

  # logDebug("msg: data: ", repr(response))
  logDebug("readHandler:router: buffer: ", repr(buffer))

  let res = router.inQueue.trySendMsg(clientId, buffer)
  if not res:
    logInfo("readHandler:router:send: dropped ")
  logDebug("readHandler:router:inQueue: ", repr(router.inQueue.chan.peek()))

## =================== Execute RPC Tasks =================== ##
proc fastRpcExec*(router: FastRpcRouter, item: InetMsgQueueItem): bool =
  logDebug("readHandler:router: inQueue: ", repr(router.inQueue.chan.peek()))
  logDebug("fastrpcTask:item: ", repr(item))

  var response = router.callMethod(item.data[], item.cid)
  logDebug("fastrpcTask:sent:response: ", repr(response))
  result = router.outQueue.trySendMsg(item.cid, response)


proc fastRpcTask*(router: FastRpcRouter) {.thread.} =
  logInfo("Starting FastRpc Task")
  logDebug("fastrpcTask:inQueue:chan: ", repr(router.inQueue.chan.addr().pointer))

  var status = true
  while status:
    logDebug("fastrpcTask:loop: ")
    let item: InetMsgQueueItem = router.inQueue.recv()
    let res = router.fastRpcExec(item)
    logDebug("fastrpcTask:sent:res: ", repr(res))

proc postServerProcessor(srv: ServerInfo[FastRpcOpts], results: seq[ReadyKey]) =
  var item: InetMsgQueueItem 
  let router = srv.getOpts().router
  while router.inQueue.tryRecv(item):
    let res = router.fastRpcExec(item)
    logDebug("fastrpcProcessor:processed:sent:res: ", repr(res))
  
  # Cleanup (garbage collect) the receivers and Client ID's 
  for evt, subcli in router.subEventProcs.pairs():
    var removes = newSeq[InetClientHandle]()
    for cid, subid in subcli.subs:
      block cidCheck:
        case cid[].kind:
        of InetClientType.clSocket:
          for recFd, sock in srv.receivers:
            if recFd in cid:
              break cidCheck
        of InetClientType.clAddress:
          let uopts = srv.getOpts().udpRpcSubs[subid]
          let curr = millis()
          logDebug("fastrpcprocessor:cleanup:check:udp-subs:", repr uopts) 
          if uopts.timeout == Millis(0): # unlimited udp subscription
            break cidCheck
          elif uopts.ts <= curr and (curr - uopts.ts) < uopts.timeout:
            logInfo("fastrpcprocessor:cleanup:udp-subs:timeout:", repr uopts) 
            break cidCheck
        else:
          discard "unhandled"
        # otherwise remove it
        logInfo("fastrpcprocessor:cleanup:cid:", cid, "subid:", repr(subid))
        removes.add cid
    for cid in removes:
      subcli.subs.del(cid)
    logDebug("fastrpcprocessor:cleanup:subs:len:", subcli.subs.len())


## =================== Fast RPC Server Implementation =================== ##
proc newFastRpcServer*(router: FastRpcRouter,
                       bufferSize = 1400,
                       prefixMsgSize = false,
                       threaded = false,
                       udpTimeout = Millis(convert(Minutes, Milliseconds, 15)),
                       ): Server[FastRpcOpts] =
  new(result)
  result.readHandler = fastRpcReadHandler
  result.eventHandler = fastRpcEventHandler 
  result.writeHandler = nil 

  result.opts = FastRpcOpts(
    bufferSize: bufferSize,
    router: router,
    prefixMsgSize: prefixMsgSize,
  )

  # result.opts.inetQueue = @[outQueue]
  result.events = @[router.outQueue.evt,
                    router.registerQueue.evt] 
  for evt, subcli in router.subEventProcs:
    result.events.add evt

  logDebug("newFastRpcServer:registerQueue:evt: ", repr(router.registerQueue.evt))
  logDebug("newFastRpcServer:outQueue:evt: ", repr(router.outQueue.evt))
  logDebug("newFastRpcServer:inQueue:evt: ", repr(router.inQueue.evt))
  logDebug("newFastRpcServer:inQueue:chan: ", repr(router.inQueue.chan.addr().pointer))
  if threaded:
    # create n-threads
    createThread(result.opts.task, fastRpcTask, router)
  else:
    # use current thread to handle rpcs
    result.postProcessHandler = postServerProcessor 
