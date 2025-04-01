
#
#
#                                    Nim's Runtime Library
#        (c) Copyright 2021 Andreas Prell, Mamy André-Ratsimbazafy & Nim Contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
# This Channel implementation is a shared memory, fixed-size, concurrent queue using
# a circular buffer for data. Based on channels implementation[1]_ by
# Mamy André-Ratsimbazafy (@mratsim), which is a C to Nim translation of the
# original[2]_ by Andreas Prell (@aprell)
#
# .. [1] https://github.com/mratsim/weave/blob/5696d94e6358711e840f8c0b7c684fcc5cbd4472/unused/channels/channels_legacy.nim
# .. [2] https://github.com/aprell/tasking-2.0/blob/master/src/channel_shm/channel.c

## This module works only with one of `--mm:arc` / `--mm:atomicArc` / `--mm:orc`
## compilation flags.
##
## .. warning:: This module is experimental and its interface may change.
##
## This module implements multi-producer multi-consumer channels - a concurrency
## primitive with a high-level interface intended for communication and
## synchronization between threads. It allows sending and receiving typed, isolated
## data, enabling safe and efficient concurrency.
##
## The `RChan` type represents a generic fixed-size channel object that internally manages
## the underlying resources and synchronization. It has to be initialized using
## the `newChan` proc. Sending and receiving operations are provided by the
## blocking `send` and `recv` procs, and non-blocking `trySend` and `tryRecv`
## procs. For ring buffer behavior, use the `push` proc rather than `send`.
## Send operations add messages to the channel, receiving operations remove them,
## while `push` adds a message or overwrites the oldest message if the channel is full.
##
##
## See also:
## * [std/isolation](https://nim-lang.org/docs/isolation.html)
##
## The following is a simple example of two different ways to use channels:
## blocking and non-blocking.

runnableExamples("--threads:on --gc:orc"):
  import std/os

  # In this example a channel is declared at module scope.
  # Channels are generic, and they include support for passing objects between
  # threads.
  # Note that isolated data passed through channels is moved around.
  var RChan = newChan[string]()

  block example_blocking:
    # This proc will be run in another thread.
    proc basicWorker() =
      RChan.send("Hello World!")

    # Launch the worker.
    var worker: Thread[void]
    createThread(worker, basicWorker)

    # Block until the message arrives, then print it out.
    var dest = ""
    dest = RChan.recv()
    assert dest == "Hello World!"

    # Wait for the thread to exit before moving on to the next example.
    worker.joinThread()

  block example_non_blocking:
    # This is another proc to run in a background thread. This proc takes a while
    # to send the message since it first sleeps for some time.
    proc slowWorker(delay: Natural) =
      # `delay` is a period in milliseconds
      sleep(delay)
      RChan.send("Another message")

    # Launch the worker with a delay set to 2 seconds (2000 ms).
    var worker: Thread[Natural]
    createThread(worker, slowWorker, 2000)

    # This time, use a non-blocking approach with tryRecv.
    # Since the main thread is not blocked, it could be used to perform other
    # useful work while it waits for data to arrive on the channel.
    var messages: seq[string]
    while true:
      var msg = ""
      if RChan.tryRecv(msg):
        messages.add msg # "Another message"
        break
      messages.add "Pretend I'm doing useful work..."
      # For this example, sleep in order not to flood the sequence with too many
      # "pretend" messages.
      sleep(400)

    # Wait for the second thread to exit before cleaning up the channel.
    worker.joinThread()

    # Thread exits right after receiving the message
    assert messages[^1] == "Another message"
    # At least one non-successful attempt to receive the message had to occur.
    assert messages.len >= 2

  block example_non_blocking_overwrite:
    var chanRingBuffer = newChan[string](elements = 1)
    chanRingBuffer.push("Hello")
    chanRingBuffer.push("World")
    var msg = ""
    assert chanRingBuffer.tryRecv(msg)
    assert msg == "World"

when not (defined(gcArc) or defined(gcOrc) or defined(gcAtomicArc) or defined(nimdoc)):
  {.error: "This module requires one of --mm:arc / --mm:atomicArc / --mm:orc compilation flags".}

import std/[locks, isolation, atomics]

# Channel
# ------------------------------------------------------------------------------

type
  ChannelRaw = ptr ChannelObj
  ChannelObj = object
    lock: Lock
    spaceAvailableCV, dataAvailableCV: Cond
    slots: int         ## Number of item slots in the buffer
    head: Atomic[int]  ## Write/enqueue/send index
    tail: Atomic[int]  ## Read/dequeue/receive index
    atomicCounter: Atomic[int]
    buffer: ptr UncheckedArray[byte]

# ------------------------------------------------------------------------------

proc getTail(RChan: ChannelRaw, order: MemoryOrder = moRelaxed): int {.inline.} =
  RChan.tail.load(order)

proc getHead(RChan: ChannelRaw, order: MemoryOrder = moRelaxed): int {.inline.} =
  RChan.head.load(order)

proc setTail(RChan: ChannelRaw, value: int, order: MemoryOrder = moRelaxed) {.inline.} =
  RChan.tail.store(value, order)

proc setHead(RChan: ChannelRaw, value: int, order: MemoryOrder = moRelaxed) {.inline.} =
  RChan.head.store(value, order)

proc setAtomicCounter(RChan: ChannelRaw, value: int, order: MemoryOrder = moRelaxed) {.inline.} =
  RChan.atomicCounter.store(value, order)

proc numItems(RChan: ChannelRaw): int {.inline.} =
  result = RChan.getHead() - RChan.getTail()
  if result < 0:
    inc(result, 2 * RChan.slots)

  assert result <= RChan.slots

template isFull(RChan: ChannelRaw): bool =
  abs(RChan.getHead() - RChan.getTail()) == RChan.slots

template isEmpty(RChan: ChannelRaw): bool =
  RChan.getHead() == RChan.getTail()

# Channels memory ops
# ------------------------------------------------------------------------------

proc allocChannel(size, n: int): ChannelRaw =
  result = cast[ChannelRaw](allocShared(sizeof(ChannelObj)))

  # To buffer n items, we allocate for n
  result.buffer = cast[ptr UncheckedArray[byte]](allocShared(n*size))

  initLock(result.lock)
  initCond(result.spaceAvailableCV)
  initCond(result.dataAvailableCV)

  result.slots = n
  result.setHead(0)
  result.setTail(0)
  result.setAtomicCounter(0)

proc freeChannel(RChan: ChannelRaw) =
  if RChan.isNil:
    return

  if not RChan.buffer.isNil:
    deallocShared(RChan.buffer)

  deinitLock(RChan.lock)
  deinitCond(RChan.spaceAvailableCV)
  deinitCond(RChan.dataAvailableCV)

  deallocShared(RChan)

# MPMC Channels (Multi-Producer Multi-Consumer)
# ------------------------------------------------------------------------------

template incrWriteIndex(RChan: ChannelRaw) =
  atomicInc(RChan.head)
  if RChan.getHead() == 2 * RChan.slots:
    RChan.setHead(0)

template incrReadIndex(RChan: ChannelRaw) =
  atomicInc(RChan.tail)
  if RChan.getTail() == 2 * RChan.slots:
    RChan.setTail(0)

proc channelSend(RChan: ChannelRaw, data: pointer, size: int, blocking: static bool, overwrite: bool): bool =
  assert not RChan.isNil
  assert not data.isNil

  when not blocking:
    if RChan.isFull() and not overwrite: return false

  acquire(RChan.lock)

  # check for when another thread was faster to fill
  when blocking:
    if RChan.isFull():
      if overwrite:
        incrReadIndex(RChan)
      else:
        while RChan.isFull():
          wait(RChan.spaceAvailableCV, RChan.lock)
  else:
    if RChan.isFull():
      release(RChan.lock)
      return false

  assert not RChan.isFull()

  let writeIdx =
    if RChan.getHead() < RChan.slots:
      RChan.getHead()
    else:
      RChan.getHead() - RChan.slots

  copyMem(RChan.buffer[writeIdx * size].addr, data, size)

  incrWriteIndex(RChan)

  signal(RChan.dataAvailableCV)
  release(RChan.lock)
  result = true

proc channelReceive(RChan: ChannelRaw, data: pointer, size: int, blocking: static bool): bool =
  assert not RChan.isNil
  assert not data.isNil

  when not blocking:
    if RChan.isEmpty(): return false

  acquire(RChan.lock)

  # check for when another thread was faster to empty
  when blocking:
    while RChan.isEmpty():
      wait(RChan.dataAvailableCV, RChan.lock)
  else:
    if RChan.isEmpty():
      release(RChan.lock)
      return false

  assert not RChan.isEmpty()

  let readIdx =
    if RChan.getTail() < RChan.slots:
      RChan.getTail()
    else:
      RChan.getTail() - RChan.slots

  copyMem(data, RChan.buffer[readIdx * size].addr, size)

  incrReadIndex(RChan)

  signal(RChan.spaceAvailableCV)
  release(RChan.lock)
  result = true

# Public API
# ------------------------------------------------------------------------------

type
  RChan*[T] = object ## Typed channel
    d: ChannelRaw

template frees(c) =
  if c.d != nil:
    # this `fetchSub` returns current val then subs
    # so count == 0 means we're the last
    if c.d.atomicCounter.fetchSub(1, moAcquireRelease) == 0:
      freeChannel(c.d)

when defined(nimAllowNonVarDestructor):
  proc `=destroy`*[T](c: RChan[T]) =
    frees(c)
else:
  proc `=destroy`*[T](c: var RChan[T]) =
    frees(c)

proc `=wasMoved`*[T](x: var RChan[T]) =
  x.d = nil

proc `=dup`*[T](src: RChan[T]): RChan[T] =
  if src.d != nil:
    discard fetchAdd(src.d.atomicCounter, 1, moRelaxed)
  result.d = src.d

proc `=copy`*[T](dest: var RChan[T], src: RChan[T]) =
  ## Shares `Channel` by reference counting.
  if src.d != nil:
    discard fetchAdd(src.d.atomicCounter, 1, moRelaxed)
  `=destroy`(dest)
  dest.d = src.d

proc trySend*[T](c: RChan[T], src: sink Isolated[T]): bool {.inline.} =
  ## Tries to send the message `src` to the channel `c`.
  ##
  ## The memory of `src` will be moved if possible.
  ## Doesn't block waiting for space in the channel to become available.
  ## Instead returns after an attempt to send a message was made.
  ##
  ## .. warning:: In high-concurrency situations, consider using an exponential
  ##    backoff strategy to reduce contention and improve the success rate of
  ##    operations.
  ##
  ## Returns `false` if the message was not sent because the number of pending
  ## messages in the channel exceeded its capacity.
  result = channelSend(c.d, src.addr, sizeof(T), false, false)
  if result:
    wasMoved(src)

template trySend*[T](c: RChan[T], src: T): bool =
  ## Helper template for `trySend <#trySend,RChan[T],sinkIsolated[T]>`_.
  ##
  ## .. warning:: For repeated sends of the same value, consider using the
  ##    `tryTake <#tryTake,RChan[T],Isolated[T]>`_ proc with a pre-isolated
  ##    value to avoid unnecessary copying.
  mixin isolate
  trySend(c, isolate(src))

proc tryTake*[T](c: RChan[T], src: var Isolated[T]): bool {.inline.} =
  ## Tries to send the message `src` to the channel `c`.
  ##
  ## The memory of `src` is moved directly. Be careful not to reuse `src` afterwards.
  ## This proc is suitable when `src` cannot be copied.
  ##
  ## Doesn't block waiting for space in the channel to become available.
  ## Instead returns after an attempt to send a message was made.
  ##
  ## .. warning:: In high-concurrency situations, consider using an exponential
  ##    backoff strategy to reduce contention and improve the success rate of
  ##    operations.
  ##
  ## Returns `false` if the message was not sent because the number of pending
  ## messages in the channel exceeded its capacity.
  result = channelSend(c.d, src.addr, sizeof(T), false, false)
  if result:
    wasMoved(src)

proc tryRecv*[T](c: RChan[T], dst: var T): bool {.inline.} =
  ## Tries to receive a message from the channel `c` and fill `dst` with its value.
  ##
  ## Doesn't block waiting for messages in the channel to become available.
  ## Instead returns after an attempt to receive a message was made.
  ##
  ## .. warning:: In high-concurrency situations, consider using an exponential
  ##    backoff strategy to reduce contention and improve the success rate of
  ##    operations.
  ##
  ## Returns `false` and does not change `dist` if no message was received.
  channelReceive(c.d, dst.addr, sizeof(T), false)

proc send*[T](c: RChan[T], src: sink Isolated[T]) {.inline.} =
  ## Sends the message `src` to the channel `c`.
  ## This blocks the sending thread until `src` was successfully sent.
  ##
  ## The memory of `src` is moved, not copied.
  ##
  ## If the channel is already full with messages this will block the thread until
  ## messages from the channel are removed.
  when defined(gcOrc) and defined(nimSafeOrcSend):
    GC_runOrc()
  discard channelSend(c.d, src.addr, sizeof(T), true, false)
  wasMoved(src)

template send*[T](c: RChan[T]; src: T) =
  ## Helper template for `send`.
  mixin isolate
  send(c, isolate(src))

proc push*[T](c: RChan[T], src: sink Isolated[T]) {.inline.} =
  ## Pushes the message `src` to the channel `c`.
  ## This is a non-blocking operation that overwrites the oldest message if the channel is full.
  ##
  ## The memory of `src` is moved, not copied.
  when defined(gcOrc) and defined(nimSafeOrcSend):
    GC_runOrc()
  discard channelSend(c.d, src.addr, sizeof(T), true, overwrite=true)
  wasMoved(src)

template push*[T](c: RChan[T]; src: T) =
  ## Helper template for `push`.
  mixin isolate
  push(c, isolate(src))

proc recv*[T](c: RChan[T], dst: var T) {.inline.} =
  ## Receives a message from the channel `c` and fill `dst` with its value.
  ##
  ## This blocks the receiving thread until a message was successfully received.
  ##
  ## If the channel does not contain any messages this will block the thread until
  ## a message get sent to the channel.
  discard channelReceive(c.d, dst.addr, sizeof(T), true)

proc recv*[T](c: RChan[T]): T {.inline.} =
  ## Receives a message from the channel.
  ## A version of `recv`_ that returns the message.
  discard channelReceive(c.d, result.addr, sizeof(T), true)

proc recvIso*[T](c: RChan[T]): Isolated[T] {.inline.} =
  ## Receives a message from the channel.
  ## A version of `recv`_ that returns the message and isolates it.
  discard channelReceive(c.d, result.addr, sizeof(T), true)

proc peek*[T](c: RChan[T]): int {.inline.} =
  ## Returns an estimation of the current number of messages held by the channel.
  numItems(c.d)

proc newRChan*[T](elements: Positive = 30): RChan[T] =
  ## An initialization procedure, necessary for acquiring resources and
  ## initializing internal state of the channel.
  ##
  ## `elements` is the capacity of the channel and thus how many messages it can hold
  ## before it refuses to accept any further messages.
  result = RChan[T](d: allocChannel(sizeof(T), elements))
