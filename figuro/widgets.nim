
import std/[macros, typetraits]


#include <QObject>

import meta/signals
import meta/slots

type
  Widget* = ref object of RootObj

  Counter* = ref object of Widget
    value: int

var router = newFastRpcRouter()

# macro slot(p) =
#   echo "## slot: "
#   echo p.treeRepr

macro signal(p) =
  echo "## slot: "
  echo p.treeRepr

proc value*(self: Counter): int =
  self.value

proc setValue*(self: Counter, value: int) {.slot.} =
  self.value = value

proc valueChanged(val: int) {.signal.}

proc add(a: int, b: int): int {.slot.} =
  echo "add: ", 1 + a + b

import pretty
print router
