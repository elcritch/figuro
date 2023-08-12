
import std/isolation
# import threading/smartptrs
# import threading/channels

export isolation
export channels, smartptrs

type
  ClientId* = int64

  Event* = distinct int64

  InetQueueItem*[T] = ref object
    ## Queue item to allow passing data and an network address
    ## as an atomic pointer so it's thread safe. 
    ## 
    ## This helps reduce bookkeeping for keeping around
    ## things like UDP addresses.
    cid*: ClientId
    data*: T

type
  EventQueue*[T] = ref object
    ## Queue that uses a channel for passing data with
    ## the a SelectEvent in order to notify a `std/selector`
    ## based system of new data.
    evt*: Event # eventfds
    chan*: Chan[T]

var eventCnts = 0
proc newEvent*(): Event =
  eventCnts.inc()
  Event(eventCnts)
proc `$`*(evt: Event): string {.borrow.}
proc `==`*(a,b: Event): bool {.borrow.}
proc trigger*(evt: Event) =
  echo "fake event! ", $evt

proc newInetQueueItem*[T](cid: ClientId, data: sink T): InetQueueItem[T] =
  new(result)
  result.cid = cid
  result.data = move data

proc init*[T](x: typedesc[InetQueueItem[T]], cid: ClientId, data: sink T): InetQueueItem[T] =
  result = newInetQueueItem[T](cid, data)

proc newEventQueue*[T](size: int): EventQueue[T] =
  new(result)
  result.evt = newEvent()
  result.chan = newChan[T](size)

proc init*[T](x: typedesc[EventQueue[T]], size: int): EventQueue[T] =
  result = newEventQueue[T](size)

proc getEvent*[T](q: EventQueue[T]): Event =
  result = q.evt

proc send*[T](rq: EventQueue[T], item: sink Isolated[T], trigger=true) =
  rq.chan.send(item)
  if trigger:
    rq.evt.trigger()

proc trigger*[T](rq: EventQueue[T]) =
  rq.evt.trigger()

template send*[T](rq: EventQueue[T], item: T, trigger=true) =
  send(rq, isolate(item), trigger)

proc trySend*[T](rq: EventQueue[T], item: var Isolated[T], trigger=true): bool =
  let res: bool = channels.trySend(rq.chan, item)
  if res and trigger:
    rq.evt.trigger()
  res

template trySend*[T](rq: EventQueue[T], item: T, trigger=true): bool =
  var isoItem = isolate(item)
  rq.trySend(isoItem, trigger)

proc recv*[T](rq: EventQueue[T]): T =
  channels.recv(rq.chan, result)

template tryRecv*[T](rq: EventQueue, item: var T): bool =
  rq.chan.tryRecv(item)

