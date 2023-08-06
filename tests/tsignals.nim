
import std/[macros, typetraits]


#include <QObject>

import meta/signals
import meta/slots

type
  Widget* = ref object of RootObj

  Counter* = ref object of Widget
    value: int

var router = newAgentRouter()

# macro slot(p) =
#   echo "## slot: "
#   echo p.treeRepr

macro signal(p) =
  echo "## slot: "
  # echo p.treeRepr

proc value*(self: Counter): int =
  self.value

proc setValue(self: Counter, value: int) {.slot.} =
  self.value = value

proc valueChanged(val: int) {.signal.}

proc add(a: int, b: int): int {.slot.} =
  echo "add: ", 1 + a + b

import pretty
# print router

echo "router: ", router.listMethods()

var counter = Counter()


when isMainModule:
  import unittest

  suite "agent slots":

    test "slot bad call":
      let req = AgentRequest(
        kind: Request,
        id: AgentId(1),
        procName: "setValue",
        params: RpcParams(buf: newVariant((val: 5)))
      )

      let res = router.callMethod(req, ClientId(10))

      variantMatch case res.result.buf as u
      of AgentError:
        echo "u is AgentError"
        print u
      else:
        check false

    test "slot good call":
      let req = AgentRequest(
        kind: Request,
        id: AgentId(1),
        procName: "setValue",
        params: RpcParams(buf: newVariant((counter: counter, val: 5)))
      )

      let res = router.callMethod(req, ClientId(10))

      variantMatch case res.result.buf as u
      of AgentError:
        check false
      else:
        echo "unknown type"

