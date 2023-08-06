import tables, strutils, macros

import datatypes

export datatypes
# import router
# export router

proc makeProcName(s: string): string =
  result = ""
  for c in s:
    if c.isAlphaNumeric: result.add c

proc hasReturnType(params: NimNode): bool =
  if params != nil and params.len > 0 and params[0] != nil and
     params[0].kind != nnkEmpty:
    result = true

proc firstArgument(params: NimNode): (string, string) =
  if params != nil and
      params.len > 0 and
      params[1] != nil and
      params[1].kind == nnkIdentDefs:
    result = (params[1][0].strVal, params[1][1].repr)
  else:
    result = ("", "")

iterator paramsIter(params: NimNode): tuple[name, ntype: NimNode] =
  for i in 1 ..< params.len:
    let arg = params[i]
    let argType = arg[^2]
    for j in 0 ..< arg.len-2:
      yield (arg[j], argType)

proc mkParamsVars(paramsIdent, paramsType, params: NimNode): NimNode =
  ## Create local variables for each parameter in the actual RPC call proc
  if params.isNil: return

  result = newStmtList()
  var varList = newSeq[NimNode]()
  for paramid, paramType in paramsIter(params):
    varList.add quote do:
      var `paramid`: `paramType` = `paramsIdent`.`paramid`
  result.add varList
  # echo "paramsSetup return:\n", treeRepr result

proc mkParamsType*(paramsIdent, paramsType, params: NimNode): NimNode =
  ## Create a type that represents the arguments for this rpc call
  ## 
  ## Example: 
  ## 
  ##   proc multiplyrpc(a, b: int): int {.rpc.} =
  ##     result = a * b
  ## 
  ## Becomes:
  ##   proc multiplyrpc(params: RpcType_multiplyrpc): int = 
  ##     var a = params.a
  ##     var b = params.b
  ##   
  ##   proc multiplyrpc(params: RpcType_multiplyrpc): int = 
  ## 
  if params.isNil: return

  var tup = quote do:
    type `paramsType` = tuple[]
  for paramIdent, paramType in paramsIter(params):
    # processing multiple variables of one type
    tup[0][2].add newIdentDefs(paramIdent, paramType)
  result = tup

macro rpcImpl*(p: untyped, publish: untyped, qarg: untyped): untyped =
  ## Define a remote procedure call.
  ## Input and return parameters are defined using proc's with the `rpc` 
  ## pragma. 
  ## 
  ## For example:
  ## .. code-block:: nim
  ##    proc methodname(param1: int, param2: float): string {.rpc.} =
  ##      result = $param1 & " " & $param2
  ##    ```
  ## 
  ## Input parameters are automatically marshalled from fast rpc binary 
  ## format (msgpack) and output parameters are automatically marshalled
  ## back to the fast rpc binary format (msgpack) for transport.
  
  let
    path = $p[0]
    params = p[3]
    pragmas = p[4]
    body = p[6]

  result = newStmtList()
  var
    parameters = params

  let
    # determine if this is a "system" rpc method
    isSignal = publish.kind == nnkStrLit and publish.strVal == "signal"
    syspragma = not pragmas.findChild(it.repr == "system").isNil

    # rpc method names
    pathStr = $path
    signalName = pathStr.strip(false, true, {'*'})
    procNameStr = pathStr.makeProcName()
    isPublic = pathStr.endsWith("*")

    # public rpc proc
    procName = ident(procNameStr & "Func")
    rpcMethod = ident(procNameStr)

    ctxName = ident("context")

    # parameter type name
    paramsIdent = genSym(nskParam, "args")
    paramTypeName = ident("RpcType_" & procNameStr)

    firstArg = params.firstArgument()

  var
    # process the argument types
    paramSetups = mkParamsVars(paramsIdent, paramTypeName, parameters)
    paramTypes = mkParamsType(paramsIdent, paramTypeName, parameters)
    procBody =  if body.kind == nnkStmtList: body
                elif body.kind == nnkEmpty: body
                else: body.body

  let ContextType = ident "RpcContext"

  proc makePublic(procDef: NimNode) =
      procDef[0] = nnkPostfix.newTree(newIdentNode("*"), rpcMethod)

  # Create the proc's that hold the users code 
  if not isSignal:

    result.add quote do:
      `paramTypes`

      proc `procName`(`paramsIdent`: `paramTypeName`,
                      `ctxName`: `ContextType`
                      ) =
          `paramSetups`
          `procBody`

    # Create the rpc wrapper procs
    result.add quote do:
      proc `rpcMethod`(params: RpcParams,
                        context: `ContextType`
                      ) {.gcsafe, nimcall.} =
        var obj: `paramTypeName`
        obj.rpcUnpack(params)

        `procName`(obj, context)

    if isPublic: result[1].makePublic()

    if syspragma:
      result.add quote do:
        sysRegister(router, `signalName`, `rpcMethod`)
    else:
      result.add quote do:
        register(router, `signalName`, `rpcMethod`)
    echo "slots: "
    echo result.repr

  elif isSignal:

    result.add quote do:
      proc `rpcMethod`(): AgentRequest {.nimcall.} =
        discard
        
    if isPublic: result[0].makePublic()
    result[0][3] = parameters
    echo "signal: "
    echo result.treeRepr
    echo ""
    echo result.repr
    echo "\nparameters: ", treeRepr parameters 


macro rpcOption*(p: untyped): untyped =
  result = p

macro rpcSetter*(p: untyped): untyped =
  result = p
macro rpcGetter*(p: untyped): untyped =
  result = p

template slot*(p: untyped): untyped =
  rpcImpl(p, nil, nil)

# template rpcPublisher*(args: static[Duration], p: untyped): untyped =
#   rpcImpl(p, args, nil)

template rpcThread*(p: untyped): untyped =
  `p`

template signal*(p: untyped): untyped =
  # rpcImpl(p, "thread", qarg)
  # static: echo "RPCSERIALIZER:\n", treeRepr p
  rpcImpl(p, "signal", nil)

macro DefineRpcs*(name: untyped, args: varargs[untyped]) =
  ## annotates that a proc is an `rpcRegistrationProc` and
  ## that it takes the correct arguments. In particular 
  ## the first parameter must be `router: var AgentRouter`. 
  ## 
  let
    params = if args.len() >= 2: args[0..^2]
             else: newSeq[NimNode]()
    pbody = args[^1]

  # if router.repr != "var AgentRouter":
  #   error("Incorrect definition for a `rpcNamespace`." &
  #   "The first parameter to an rpc registration namespace must be named `router` and be of type `var AgentRouter`." &
  #   " Instead got: `" & treeRepr(router) & "`")
  let rname = ident("router")
  result = quote do:
    proc `name`*(`rname`: var AgentRouter) =
      `pbody`
  
  var pArgs = result[3]
  for param in params:
    let parg = newIdentDefs(param[0], param[1])
    pArgs.add parg
  echo "PARGS: ", pArgs.treeRepr

macro registerRpcs*(router: var AgentRouter,
                    registerClosure: untyped,
                    args: varargs[untyped]) =
  result = quote do:
    `registerClosure`(`router`, `args`) # 

macro registerDatastream*[T,O,R](
              router: var AgentRouter,
              name: string,
              serializer: RpcStreamSerializer[T],
              reducer: RpcStreamTask[T, TaskOption[O]],
              queue: EventQueue[T],
              option: O,
              optionRpcs: R) =
  echo "registerDatastream: T: ", repr(T)
  result = quote do:
    let serClosure: RpcStreamSerializerClosure =
            `serializer`(`queue`)
    `optionRpcs`(`router`)
    router.register(`name`, `queue`.evt, serClosure)

  echo "REG:DATASTREAM:\n", result.repr
  echo ""

                      
proc getUpdatedOption*[T](chan: TaskOption[T]): Option[T] =
  # chan.tryRecv()
  return some(T())
proc getRpcOption*[T](chan: TaskOption[T]): T =
  # chan.tryRecv()
  return T()

template rpcReply*(value: untyped): untyped =
  rpcReply(context, value, Publish)

template rpcPublish*(arg: untyped): untyped =
  rpcReply(context, arg, Publish)