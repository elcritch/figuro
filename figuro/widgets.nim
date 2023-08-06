
import std/[macros, typetraits]


#include <QObject>


type
  Widget* = ref object of RootObj

  Counter* = ref object of Widget
    value: int

macro slot(p) =
  echo "## slot: "
  echo p.treeRepr

macro signal(p) =
  echo "## slot: "
  echo p.treeRepr

proc value*(self: Counter): int =
  self.value

proc setValue*(self: Counter, value: int) {.slot.} =
  self.value = value

proc valueChanged(val: int) {.signal.}

