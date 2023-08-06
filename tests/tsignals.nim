
import std/[macros, typetraits]


#include <QObject>

import figuro/meta/signals
import figuro/meta/slots

type
  Widget* = ref object of RootObj

  Counter* = ref object of Widget
    value: int

var router = newAgentRouter()

template emit*(call: typed) =
  discard

proc value*(self: Counter): int =
  self.value

proc valueChanged*(val: int) {.signal.}

proc setValue*(self: Counter, value: int) {.slot.} =
  self.value = value
  # emit valueChanged(val)


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
        id: AgentId(0),
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
        id: AgentId(0),
        procName: "setValue",
        params: RpcParams(buf: newVariant((counter: counter, val: 5)))
      )

      let res = router.callMethod(req, ClientId(10))

      variantMatch case res.result.buf as u
      of AgentError:
        check false
      else:
        echo "unknown type"

