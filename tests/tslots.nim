
import std/[macros, typetraits]


#include <QObject>

import figuro/meta

type

  Counter* = ref object of Agent
    value: int
    avg: int

proc valueChanged*(tp: Counter, val: int) {.signal.}

proc avgChanged*(tp: Counter, val: float) {.signal.}

proc setValue*(self: Counter, value: int) {.slot.} =
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
        a {.used.} = Counter()
        b {.used.} = Counter()
        c {.used.} = Counter()
        d {.used.} = Counter()

    test "signal connect":
      # TODO: how to do this?
      connect(a, valueChanged,
              b, setValue)
      connect(a, valueChanged,
              c, setValue)
      
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
      check setValue.signalType() is (int, )

    test "signal connect":
      # TODO: how to do this?
      connect(a, valueChanged,
              b, setValue)
      connect(a, valueChanged,
              c, setValue)
    

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

