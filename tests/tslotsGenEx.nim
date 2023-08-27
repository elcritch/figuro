import figuro/meta
import macros

macro test() =
  let res = quote do:

    type
      Counter[T] = ref object of Agent
        value: T
        avg: int

    proc valueChanged[T](obj: Counter[T]; val: T): (Agent, AgentRequest) =
      let args = (val: val)
      let sig = AgentRequest(kind: Request, id: AgentId(0),
                                    procName: "valueChanged",
                                    params: rpcPack(args))
      result = (obj, sig)

    proc avgChanged[T](obj: Counter[T]; val: float): (Agent, AgentRequest) =
      let args = (val: val)
      let sig = AgentRequest(kind: Request, id: AgentId(0),
                                    procName: "avgChanged",
                                    params: rpcPack(args))
      result = (obj, sig)

    type
      RpcTypesetValue[T] = tuple[value: T]
    proc setValue_1056964731[T](self: Counter[T]; value: T) =
      echo "setValue! ", value
      if self.value != value:
        self.value = value
      emit self.valueChanged(value)

    proc setValue[T](self: Counter[T]; value: T) =
      setValue_1056964731(self, value)

    proc agentSlotsetValue_1056964731[T](context: Agent;
                                          params: RpcParams) {.nimcall.} =
      if context == nil:
        raise newException(ValueError, "bad value")
      let obj = Counter[T](context)
      if obj == nil:
        raise newException(ConversionError, "bad cast")
      var args: RpcTypesetValue
      rpcUnpack(args, params)
      let obj = Counter[T](context)
      var value: T = args.value
      setValue(obj, value)

    template setValue[T](tp: typedesc[Counter[T]]): untyped =
      setValue_1056964731[T]

    template agentSlotsetValue[T](tp: typedesc[Counter[T]]): AgentProc =
      agentSlotsetValue_1056964731[T]
  echo "res: ", res.treeRepr

test()
# when isMainModule:
#   import unittest
#   suite "agent slots":
#     setup:
#       var
#         a {.used.} = Counter[uint]()
#         b {.used.} = Counter[uint]()
#         c {.used.} = Counter[uint]()
#         d {.used.} = Counter[uint]()
#     test "signal connect":
#       # TODO: how to do this?
#       # let x = typeof( proc (obj: Counter[T]; val: T): (Agent, AgentRequest) )
#       # echo "proc type: ", x
#       let tgtProc = Counter[uint].setValue
#       echo "tgtProc:type: ", tgtProc.typeof.repr
#       echo "tgtProc: ", tgtProc.repr
#       tgtProc(a, 3.uint)
#       # a.addAgentListeners(name, b, AgentProc(toSlot(Counter[uint].setValue)))
#       # connect(a, valueChanged,
#       #         b, Counter[uint].setValue)
