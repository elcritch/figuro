
import std/[macros, typetraits]


#include <QObject>

import figuro/meta/signals
import figuro/meta/slots

type

  Counter* = ref object of Agent
    value: int

# var router = newAgentRouter()

template emit*(call: untyped) =
  call

proc valueChanged*(tp: Counter, val: int) {.signal.}

proc setValue*(self: Counter, value: int) {.slot.} =
  self.value = value
  emit self.valueChanged(value)

proc value*(self: Counter): int =
  self.value

import pretty
# print router

# echo "router: ", router.listMethods()


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

    test "signal":

      counter.valueChanged(137)

      # connect(counter, valueChanged)

    test "signal connect":
      var
        a = Counter()
        b = Counter()
      
      # TODO: how to do this?
      connect(
        a, valueChanged,
        b, setValue,
      )
      
      let params = (value: 23)
      a.setValue(params)


