from sugar import capture
import macros
import commons

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
  # echo "parseWidgetArgs:args: ", args.treeRepr

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
        # arg[1].expectKind(nnkBracket)
        result.stateArg = arg[1]
      elif fname.repr == "captures":
        result.capturedVals = nnkBracket.newTree()
        result.capturedVals.add arg[1..^1]
      else:
        error("unexpected arguement: " & arg.repr, arg)
    else:
      echo "UNEXPECTED"
      error("unexpected arguement: " & arg.repr, arg)
  
  if result.stateArg.isNil:
    result.stateArg = ident"void"
  # echo "parseWidgetArgs:res: ", result.repr

proc generateBodies*(widget, kind: NimNode, wargs: WidgetArgs): NimNode =
  let (id, stateArg, capturedVals, blk) = wargs

  let body = quote do:
      current.postDraw = proc (widget: Figuro) =
        var current {.inject.}: `widget` = `widget`(widget)
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
      var current {.inject.}: `widget` = nil
      preNode(`kind`, `id`, current, parent)
      `outer`
      postNode(Figuro(current))

  # echo "Widget:result:\n", result.repr

proc generateGenericBodies*(widget, kind: NimNode,
                            wargs: WidgetArgs): NimNode {.compileTime.} =

  # echo "generateGenericBodies:widget: ", widget.treeRepr
  # echo "generateGenericBodies:widget: ", widget.getTypeImpl.treeRepr
  # echo "generateGenericBodies:widget: ", widget.getTypeInst.treeRepr
  # echo "generateGenericBodies:widget: ", widget.getImpl.treeRepr

  let (id, stateArg, capturedVals, blk) = wargs

  let body = quote do:
      current.postDraw = proc (widget: Figuro) =
        var current {.inject.} = `widget`[`stateArg`](widget)
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
      when not compiles(current.typeof):
        {.error: "missing `var current` in current scope!".}
      var parent {.inject.}: Figuro = Figuro(current)
      var current {.inject.}: `widget`[`stateArg`] = nil
      preNode(`kind`, `id`, current, parent)
      `outer`
      postNode(Figuro(current))

  # echo "Widget:result:\n", result.repr

template exportWidget*[T](name: untyped, class: typedesc[T]) =
  ## exports a template to use the widget
  macro `name`*(args: varargs[untyped]) =
    let widget = class.getTypeInst()
    let wargs = args.parseWidgetArgs()
    let impl = widget.getImpl()
    impl.expectKind(nnkTypeDef)
    let hasGeneric = impl[1].len() > 0
    echo "hasGeneric: ", hasGeneric
    if hasGeneric:
      result = generateGenericBodies(widget, ident "nkRectangle", wargs)
    else:
      result = generateBodies(widget, ident "nkRectangle", wargs)

import std/terminal

proc toString*(figs: HashSet[Figuro]): string =
  result.add "["
  for fig in figs:
    result.add $fig.getId
    result.add ","
  result.add "]"

var evtMsg: array[EventKinds, seq[(string, string)]]

template printNewEventInfo*() =
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

