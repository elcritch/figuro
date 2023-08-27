
import figuro/meta
type
  Counter*[T] = ref object of Agent
    value: T
    avg: int

proc valueChanged*[T](tp: Counter[T], val: T) {.signal.}

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

  suite "agent slots":
    setup:
      var
        a {.used.} = Counter[uint]()
        b {.used.} = Counter[uint]()
        c {.used.} = Counter[uint]()
        d {.used.} = Counter[uint]()

    test "signal connect":
      # TODO: how to do this?
      connect(a, valueChanged,
              b, Counter.setValue)
      connect(a, valueChanged,
              c, Counter.setValue)
      
      check b.value == 0
      check c.value == 0
      check d.value == 0

      emit a.valueChanged(137)

      check a.value == 0
      check b.value == 137
      check c.value == 137
      check d.value == 0

    test "signal / slot types":
      check avgChanged.signalType() is (float, )
      check valueChanged.signalType() is (int, )
      check Counter.setValue.signalType() is (int, )


    test "signal connect":
      # TODO: how to do this?
      connect(a, valueChanged,
              b, Counter.setValue)
      connect(a, valueChanged,
              c, Counter.setValue)

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
                c, setValue))

