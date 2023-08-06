
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

proc valueChanged*(tp: typedesc[Counter], val: int) {.signal.}

proc setValue*(self: Counter, value: int) {.slot.} =
  self.value = value
  # emit valueChanged(val)


import pretty
# print router

echo "router: ", router.listMethods()


when isMainModule:
  import unittest

  suite "agent slots":

    setup:
      var counter = Counter()
      var req = AgentRequest(
        kind: Request,
        id: AgentId(0),
        procName: "setValue",
        params: RpcParams(buf: newVariant(0))
      )

    test "slot bad call":
      req.params.buf = newVariant((wrongArg: 12, val: 5))
      let res = router.callMethod(counter, req, ClientId(10))

      variantMatch case res.result.buf as u
      of AgentError:
        echo "u is AgentError"
        print u
        check counter.value == 0
      else:
        check false

    test "slot good call":
      req.params.buf = newVariant((val: 42))
      let res = router.callMethod(counter, req, ClientId(10))
      variantMatch case res.result.buf as u
      of AgentError:
        print u
        check false
      else:
        check counter.value == 42

    test "signal":
      var val = Counter.valueChanged(137)
      print val
      val.procName = "setValue"

      # connect(counter, valueChanged)

      let res = router.callMethod(counter, val, ClientId(10))
      variantMatch case res.result.buf as u
      of AgentError:
        print u
        check false
      else:
        check counter.value == 137

