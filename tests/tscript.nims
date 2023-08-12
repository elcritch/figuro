
## This minimal example shows 5 blue squares.

import figuro/common/nodes/ui

# import figuro/ui/core

type
  Main* = ref object of Figuro
    value: float

import std/locks

when nimvm:
  discard
else:
  var l: Lock
  l.initLock()

  withLock(l):
    echo "true"
