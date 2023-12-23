
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

    test "signal / slot types":
      check SignalTypes.avgChanged(Counter[uint]) is (float, )
      check SignalTypes.valueChanged(Counter[uint]) is (uint, )
      check SignalTypes.setValue(Counter[uint]) is (uint, )

    test "signal connect":
      connect(a, valueChanged,
              b, Counter[uint].setValue())
      connect(a, valueChanged,
              c, Counter[uint].setValue())
      check b.value == 0
      check c.value == 0
      check d.value == 0
      emit a.valueChanged(137)

      check a.value == 0
      check b.value == 137
      check c.value == 137
      check d.value == 0

      emit a.someChange()

    test "signal connect in generic proc":
      proc setup[T]() =
        connect(a, valueChanged,
                b, Counter[uint].setValue)
        setup[uint]()

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
                c, Counter[uint].setValue))

      # connect(a, avgChanged,
      #         c, Counter[uint].setValue)
