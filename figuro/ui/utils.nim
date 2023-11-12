from sugar import capture
import std/sets
import macros
import commons

type
  State*[T] = object
  Captures*[V] = object
    val*: V

proc state*[T](tp: typedesc[T]): State[T] =
  ## represents the state
  discard

macro captures*(vals: varargs[untyped]): untyped = 
  ## represents the captures
  var tpl = nnkTupleConstr.newNimNode()
  for val in vals:
    # echo "captures:val: ", val.getTypeInst.repr
    tpl.add val
  result = quote do:
    Captures[typeof(`tpl`)](val: `tpl`)

type
  WidgetArgs* = tuple[
    id: NimNode,
    stateArg: NimNode,
    bindsArg: NimNode,
    capturedVals: NimNode,
    blk: NimNode
  ]

proc parseWidgetArgs*(args: NimNode): WidgetArgs =
  ## Parses widget args looking for options:
  ## - `state(int)` 
  ## - `captures(i, x)` 
  args.expectKind(nnkArgList)

  # echo "parseWidgetArgs: ", args.treeRepr
  result.id = args[0]
  result.id.expectKind(nnkStrLit)
  result.blk = args[^1]

  for arg in args[1..^2]:
    ## iterate through the widget args looking for 
    ## `state(int)` or `captures(i, x)` 
    ## 
    if arg.kind == nnkCall:
      let fname = arg[0]
      if fname.repr == "state":
        if arg.len() != 2:
          error "only one type var allowed"
        result.stateArg = arg[1]
      elif fname.repr == "expose":
        if arg.len() > 2:
          error "only no arg or a single name allowed"
        result.bindsArg = newLit(true)
      elif fname.repr == "captures":
        result.capturedVals = nnkBracket.newTree()
        result.capturedVals.add arg[1..^1]
      else:
        error("unexpected arguement: " & arg.repr, arg)
    else:
      error("unexpected arguement: " & arg.repr, arg)

  if result.stateArg.isNil:
    result.stateArg = ident"void"
  # echo "parseWidgetArgs:res: ", result.repr

template wrapCaptures*(hasCaptures, capturedVals, body: untyped): untyped =
  when hasCaptures:
    capture `capturedVals`:
      `body`
  else:
    `body`

import std/terminal

proc `$`*(figs: HashSet[Figuro]): string =
  result.add "["
  for fig in figs:
    result.add $fig.getId
    result.add ","
  result.add "]"

var evtMsg: array[EventKinds, seq[(string, string)]]

template printNewEventInfo*() =
  when defined(debugEvents):
    for ek in EventKinds:
      let evts = captured[ek]
      let targets = evts.targets

      if evts.flags != {} and
        ek in evts.flags and
        # evts.flags != {evHover} and
        # not uxInputs.keyboard.consumed and
        true:
        
        var emsg: seq[(string, string)] = @[
                    ("ek: ", $ek),
                    ("tgt: ", $targets),
                    # ("evts: ", $evts.flags),
                    ("btnsP: ", $uxInputs.buttonPress),
                    ("btnsR: ", $uxInputs.buttonRelease),
                    # (" consumed: ", $uxInputs.mouse.consumed),
                    # ( " ", $app.frameCount),
                    ]
        if ek == evClick:
          emsg.add ("pClick: ", $prevClicks)
        if ek == evHover:
          emsg.add ("pHover: ", $prevHovers)
        if ek == evKeyboardInput:
          emsg.add ("pKeyInput: ", $uxInputs.keyboard.rune)

        if emsg != evtMsg[ek]:
          evtMsg[ek] = emsg
          stdout.styledWrite({styleDim}, fgWhite, "events: ")
          for (n, v) in emsg.items():
            stdout.styledWrite({styleBright}, " ", fgBlue, n, fgGreen, v)
          stdout.styledWriteLine(fgWhite, "")

const fieldSetNames = block:
    var names: HashSet[string]
    for item in FieldSet:
      let name = $item
      names.incl name[2..^1].toLowerAscii()
    echo "FSN: ", names
    names

macro withOptional*(node, blk: untyped) =
  ## Optionally sets any fields in `SetField` enum such as
  ## `fill` and `cornerRadius`.
  ## 
  ## Use this in reusable widgets to enable setting "default"
  ## fields which only get set if the user hasn't already 
  ## set the value. 
  ## 
  ## This is required because the user supplied actions
  ## run *before* the widget draw slot.
  ## 
  result = newStmtList()
  for st in blk:
    if st.kind in [nnkCommand, nnkCall] and
        st[0].kind == nnkIdent and
        st[0].strVal.toLowerAscii() in fieldSetNames:
      let fsName = ident "fs" & st[0].strVal
      result.add quote do:
        if `fsName` notin node.userSetFields:
          with `node`:
            `st`
    else:
      result.add st
  # echo "OPTIONALS:\n", result.repr
