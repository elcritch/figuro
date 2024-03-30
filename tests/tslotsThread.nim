
import figuro/meta

type
  Counter* = ref object of Agent
    value: int
    avg: int

proc valueChanged*(tp: Counter, val: int) {.signal.}

proc someChange*(tp: Counter) {.signal.}

proc avgChanged*(tp: Counter, val: float) {.signal.}

proc setValue*(self: Counter, value: int) {.slot.} =
  echo "setValue! ", value
  if self.value != value:
    self.value = value
  emit self.valueChanged(value)

proc setSomeValue*(self: Counter, value: int) =
  echo "setValue! ", value
  if self.value != value:
    self.value = value
  emit self.valueChanged(value)

proc someAction*(self: Counter) {.slot.} =
  echo "action"

proc value*(self: Counter): int =
  self.value

import unittest
import std/sequtils

import threading/channels
import std/isolation

suite "threaded agent slots":

  setup:
    var
      a {.used.} = Counter.new()
      b {.used.} = Counter.new()
      c {.used.} = Counter.new()

  teardown:
    GC_fullCollect()

  test "simple threading test":
    var agentResults = newChan[(WeakRef[Agent], AgentRequest)]()

    connect(a, valueChanged,
            b, setValue)
    connect(a, valueChanged,
            c, Counter.setValue)
    connect(a, valueChanged,
            c, setValue Counter)

    let wa: WeakRef[Counter] = a.unsafeWeakRef()
    emit wa.valueChanged(137)
    check typeof(wa.valueChanged(137)) is (WeakRef[Agent], AgentRequest)

    check wa[].value == 0
    check b.value == 137
    check c.value == 137

    proc threadTestProc(aref: WeakRef[Counter]) {.thread.} =
      var res = aref.valueChanged(1337)
      agentResults.send(unsafeIsolate(res))
      echo "Thread Done"
    
    var thread: Thread[WeakRef[Counter]]
    createThread(thread, threadTestProc, wa)
    thread.joinThread()
    let resp = agentResults.recv()
    echo "RESP: ", resp
    emit resp

    check b.value == 1337
    check c.value == 1337

type
  Proxy*[T] = ref object of Agent
    value: int

suite "threaded agent proxy":

  setup:
    var
      a {.used.} = Counter.new()
      b {.used.} = Counter.new()
      c {.used.} = Counter.new()

    test "simple threading test":
      var agentResults = newChan[(WeakRef[Agent], AgentRequest)]()

      var ex1 = newChan[SignalTypes.avgChanged(Counter)]()
      echo "EX1: ", ex1.typeof

      connect(a, valueChanged,
              b, setValue)

      let wa: WeakRef[Counter] = a.unsafeWeakRef()
      emit wa.valueChanged(137)
      check typeof(wa.valueChanged(137)) is (WeakRef[Agent], AgentRequest)

      check wa[].value == 0
      check b.value == 137

      proc threadTestProc(aref: WeakRef[Counter]) {.thread.} =
        var res = aref.valueChanged(1337)
        agentResults.send(unsafeIsolate(res))
        echo "Thread Done"
      
      var thread: Thread[WeakRef[Counter]]
      createThread(thread, threadTestProc, wa)
      thread.joinThread()
      let resp = agentResults.recv()
      echo "RESP: ", resp
      emit resp

      check b.value == 1337
      check c.value == 1337