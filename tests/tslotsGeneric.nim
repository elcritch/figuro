
import figuro/meta
type
  Counter*[T] = ref object of Agent
    value: T
    avg: int


proc valueChanged*[T](tp: Counter[T], val: T) {.signal.}

proc someChange*[T](tp: Counter[T]) {.signal.}

proc avgChanged*[T](tp: Counter[T], val: float) {.signal.}

proc setValue*[T](self: Counter[T], value: T) {.slot.} =
  echo "setValue! ", value
  if self.value != value:
    self.value = value
  emit self.valueChanged(value)

proc value*(self: Counter): int =
  self.value

when isMainModule:
  import unittest
  import typetraits

  suite "agent slots":
    setup:
      var
        a {.used.} = Counter[uint]()
        b {.used.} = Counter[uint]()
        c {.used.} = Counter[uint]()
        d {.used.} = Counter[uint]()

    test "signal connect":
      # TODO: how to do this?
      let tgtProc = Counter[uint].setValue
      echo "tgtProc:type: ", tgtProc.typeof.repr
      echo "tgtProc: ", tgtProc.repr
      # tgtProc(a, 3.uint)
      echo "check:sig: ", a.valueChanged(3.uint).typeof is (Agent, AgentRequest)
      echo "check:slot: ", compiles(b.setValue(3.uint))
      echo "check:src: ", genericParams(a.typeof).typeof is tuple
      # a.setValue(3.uint)
      # echo "check:AGENT: ", agentSlotsetValue(Counter[uint]).typeof.repr

      connect(a, valueChanged,
              b, Counter[uint].setValue)
      connect(a, valueChanged,
              c, Counter[uint].setValue)
      check b.value == 0
      check c.value == 0
      check d.value == 0
      emit a.valueChanged(137)

      check a.value == 0
      check b.value == 137
      check c.value == 137
      check d.value == 0

      emit a.someChange()

    # test "signal / slot types":
    #   check avgChanged.signalType() is (float, )
    #   check valueChanged.signalType() is (int, )
    #   check Counter.setValue.signalType() is (int, )


    test "signal connect":
      # TODO: how to do this?
      connect(a, valueChanged,
              b, Counter[uint].setValue)
      connect(a, valueChanged,
              c, Counter[uint].setValue)

      check a.value == 0
      check b.value == 0
      check c.value == 0

      a.setValue(42)

      check a.value == 42
      check b.value == 42
      check c.value == 42

    test "connect type errors":
      check not compiles(
        connect(a, avgChanged,
                c, Counter.setValue))

