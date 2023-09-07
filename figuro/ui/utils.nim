
from sugar import capture
import macros

macro captureArgs*(args, blk: untyped): untyped =
  echo "captureArgs: ", args.treeRepr
  echo "captureArgs: ", args.repr
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

import commons

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

template withDraw*[T](fig: T, blk: untyped): untyped =
  block:
    var parent {.inject, used.} = fig.parent
    var current {.inject, used.} = fig
    `blk`

macro widget*(p: untyped): untyped =
  ## implements a stateful widget template constructors where 
  ## the type and the name are taken from the template definition:
  ## 
  ##    template `name`*[`type`, T](id: string, value: T, blk: untyped) {.statefulWidget.}
  ## 
  echo "figuroWidget: ", p.treeRepr
  echo "figuroWidget: ", p.repr

  p.expectKind nnkTemplateDef
  let name = p.name()
  let genericParams = p[2]
  let typ = genericParams[0][0]
  echo "genericParams: ", genericParams.treeRepr
  echo "genericParams: ", genericParams[0][0].treeRepr
  p.params()[0].expectKind(nnkEmpty) # no return type
  if genericParams.len() > 1:
    error("incorrect generic types: " &
              repr(genericParams) & "; " &
              "Should be `[WidgetType, T]`",
          genericParams)
  if p.params()[1].repr() != "id: string":
    error("incorrect arguments: " &
              repr(p.params()[1]) & "; " &
              "Should be `id: string`",
          p.params()[1])
  echo "repr21: ", p.params()[2][1].repr(), " ", genericParams[0][1].repr
  if p.params()[2][1].repr() != genericParams[0][1].repr:
    error("incorrect arguments: `" &
              repr(p.params()[2][1]) & "`; " &
              "Should be `[WidgetType, T]`",
          p.params()[2][1])
  if p.params()[3][1].repr() != "untyped":
    error("incorrect arguments: " &
              repr(p.params()[3][1]) & "; " &
              "Should be `untyped`",
          p.params()[3][1])
  # echo "figuroWidget: ", " name: ", name, " typ: ", typ
  # echo "\n"
  # echo "doPostId: ", doPostId, " li: ", lineInfo(p.name())
  result = quote do:
    mkStatefulWidget(`typ`, `name`, doPostId)

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
