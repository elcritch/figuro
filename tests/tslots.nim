
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

when isMainModule:
  import unittest

  suite "agent slots":
    setup:
      var
        a {.used.} = Counter.new()
        b {.used.} = Counter.new()
        c {.used.} = Counter.new()
        d {.used.} = Counter.new()

    teardown:
      GC_fullCollect()

    test "signal / slot types":
      check SignalTypes.avgChanged(Counter) is (float, )
      check SignalTypes.valueChanged(Counter) is (int, )
      echo "someChange: ", SignalTypes.someChange(Counter).typeof.repr
      check SignalTypes.someChange(Counter) is tuple[]
      check SignalTypes.setValue(Counter) is (int, )

    test "signal connect":
      echo "Counter.setValue: ", Counter.setValue().repr
      connect(a, valueChanged,
              b, setValue)
      connect(a, valueChanged,
              c, Counter.setValue)
      static:
        echo "NOT COMPILES:"
      # check not(compiles(
      connect(a, valueChanged,
              c, setValue Counter)
      check not(compiles(
        connect(a, someAction,
                c, Counter.setValue)))

      check b.value == 0
      check c.value == 0
      check d.value == 0

      emit a.valueChanged(137)

      check a.value == 0
      check b.value == 137
      check c.value == 137
      check d.value == 0


      emit a.someChange()
      connect(a, someChange,
              c, Counter.someAction)

    test "basic signal connect":
      # TODO: how to do this?
      echo "done"
      connect(a, valueChanged,
              b, setValue)
      connect(a, valueChanged,
              c, Counter.setValue)

      check a.value == 0
      check b.value == 0
      check c.value == 0

      a.setValue(42)
      check a.value == 42
      check b.value == 42
      check c.value == 42
      echo "TEST REFS: ", " aref: ", cast[pointer](a).repr, " ", addr(a[]).pointer.repr, " agent: ", addr(Agent(a)).pointer.repr
      check a.unsafeWeakRef().pointer == cast[pointer](a)
      check a.unsafeWeakRef().pointer == addr(a[]).pointer

    test "connect type errors":
      check not compiles(
        connect(a, avgChanged,
                c, setValue))

    test "signal connect reg proc":
      # TODO: how to do this?
      static:
        echo "\n\n\nREG PROC"
      # let sv: proc (self: Counter, value: int) = Counter.setValue
      check not compiles(
        connect(a, valueChanged,
              b, setSomeValue)
      )

    test "empty signal conversion":
      # TODO: how to do this?

      connect(a, valueChanged,
              c, someAction, acceptVoidSlot = true)

      a.setValue(42)

  suite "agent weak refs":
    setup:
      var
        a {.used.} = Counter.new()
        b {.used.} = Counter.new()

    test "signal connect":
      echo "Counter.setValue: "
      # connect(a, valueChanged,
      #         b, setValue)

      # check b.value == 0
      # emit a.valueChanged(137)

      # check a.value == 0
      # check b.value == 137
