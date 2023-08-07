
import std/[macros, typetraits]


#include <QObject>

import figuro/meta/signals
import figuro/meta/slots

type

  Counter* = ref object of Agent
    value: int

proc valueChanged*(tp: Counter, val: int) {.signal.}

proc setValue*(self: Counter, value: int) {.slot.} =
  echo "setValue!"
  self.value = value
  emit self.valueChanged(value)

proc value*(self: Counter): int =
  self.value

when isMainModule:
  import unittest

  suite "agent slots":
    setup:
      var
        a = Counter()
        b = Counter()
        c = Counter()
        d = Counter()

    test "signal connect":
      # TODO: how to do this?
      connect(a, valueChanged,
              b, setValue)
      connect(a, valueChanged,
              c, setValue)
      
      check b.value == 0
      check c.value == 0
      check d.value == 0

      a.valueChanged(137)

      check a.value == 0
      check b.value == 137
      check c.value == 137
      check d.value == 0


    test "signal connect":
      # TODO: how to do this?
      connect(a, valueChanged,
              b, setValue)
      connect(a, valueChanged,
              c, setValue)

      check b.value == 0
      check c.value == 0
      check d.value == 0

      when false:
        a.setValue(137)

      check a.value == 0
      check b.value == 137
      check c.value == 137
      check d.value == 0



