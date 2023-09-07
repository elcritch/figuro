from sugar import capture
import macros
import commons

macro captureArgs*(args, blk: untyped): untyped =
  ## helper to wrap the actual capture args
  # echo "captureArgs: ", args.treeRepr
  # echo "captureArgs: ", args.repr
  result = nnkCommand.newTree(bindSym"capture")
  if args.kind in [nnkSym, nnkIdent]:
    if args.strVal != "void":
      result.add args
  elif args.kind == nnkObjConstr:
    for arg in args[1][^1][^1]:
      echo "arg add: ", arg.repr
      if arg.strVal != "void":
        result.add arg
  else:
    for arg in args:
      echo "arg add: ", arg.repr
      if arg.strVal != "void":
        result.add arg
  echo "captured: ", result.treeRepr
  if result.len() > 1:
    result.add nnkStmtList.newTree(blk)
  else:
    result = nnkStmtList.newTree()
    result.add blk
  echo "captured: ", result.repr

macro statefulWidgetProc*(): untyped =
  ident(repr(genSym(nskProc, "doPost")))

template withDraw*[T](fig: T, blk: untyped): untyped =
  block:
    var parent {.inject, used.} = fig.parent
    var current {.inject, used.} = fig
    `blk`

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
    capturedVals: NimNode,
    blk: NimNode
  ]

proc parseWidgetArgs*(args: NimNode): WidgetArgs =
  ## Parses widget args looking for options:
  ## - `state(int)` 
  ## - `captures(i, x)` 
  ## 
  args.expectKind(nnkArgList)

  result.id = args[0]
  result.blk = args[^1]

  for arg in args[0..^2]:
    ## iterate through the widget args looking for 
    ## `state(int)` or `captures(i, x)` 
    ## 
    if arg.kind == nnkCall:
      let fname = arg[0]
      if fname.repr == "state":
        if arg.len() != 2:
          error "only one type var allowed"
        # arg[1].expectKind(nnkBracket)
        result.stateArg = arg[1]
      elif fname.repr == "captures":
        result.capturedVals = nnkBracket.newTree()
        result.capturedVals.add arg[1..^1]

proc generateBodies*(widget: NimNode, wargs: WidgetArgs): NimNode =
  let (id, stateArg, capturedVals, blk) = wargs

  let body = quote do:
      current.postDraw = proc (widget: Figuro) =
        var current {.inject.}: `widget`[`stateArg`] = `widget`[`stateArg`](widget)
        if postDrawReady in widget.attrs:
          widget.attrs.excl postDrawReady
          `blk`

  let outer =
    if capturedVals.isNil:
      quote do:
        `body`
    else:
      quote do:
        capture `capturedVals`:
          `body`

  result = quote do:
    block:
      var parent: Figuro = Figuro(current)
      var current {.inject.}: `widget`[`stateArg`] = nil
      preNode(nkRectangle, `id`, current, parent)
      `outer`
      postNode(Figuro(current))

  echo "Widget:result:\n", result.repr

template exportWidget*[T](name: untyped, class: typedesc[T]) =
  ## exports a helper 
  macro `name`*(args: varargs[untyped]) =
    let widget = ident(repr `class`)
    let wargs = args.parseWidgetArgs()
    result = widget.generateBodies(wargs)

import std/terminal

proc toString*(figs: HashSet[Figuro]): string =
  result.add "["
  for fig in figs:
    result.add $fig.getId
    result.add ","
  result.add "]"

var evtMsg: array[MouseEventKinds, seq[(string, string)]]

template printNewEventInfo*() =
  for ek in MouseEventKinds:
    let evts = captured.mouse[ek]
    let targets = evts.targets

    if evts.flags != {} and
      ek in evts.flags and
      # evts.flags != {evHover} and
      # not uxInputs.keyboard.consumed and
      true:
      
      var emsg: seq[(string, string)] = @[
                  ("ek: ", $ek),
                  ("tgt: ", targets.toString()),
                  # ("evts: ", $evts.flags),
                  ("btnsP: ", $uxInputs.buttonPress),
                  ("btnsR: ", $uxInputs.buttonRelease),
                  # (" consumed: ", $uxInputs.mouse.consumed),
                  # ( " ", $app.frameCount),
                  ]
      if ek == evClick:
        emsg.add ("pClick: ", $prevClicks.toString())
      if ek == evHover:
        emsg.add ("pHover: ", $prevHovers.toString())

      if emsg != evtMsg[ek]:
        evtMsg[ek] = emsg
        stdout.styledWrite({styleDim}, fgWhite, "mouse events: ")
        for (n, v) in emsg.items():
          stdout.styledWrite({styleBright}, " ", fgBlue, n, fgGreen, v)
        stdout.styledWriteLine(fgWhite, "")

