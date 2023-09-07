
import commons
import ../ui/utils

type
  StatefulWidget*[T] = ref object of Figuro
    state*: T

  Button*[T] = ref object of StatefulWidget[T]
    label*: string
    isActive*: bool
    disabled*: bool

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  # self.fill = parseHtmlColor "#9BDFFA"
  # echo "button hover!"
  echo "button:hovered: ", kind, " :: ", self.getId,
          " buttons: ", self.events.mouse
  # if kind == Enter:
  #   self.events.mouse.incl evHover
  # else:
  #   self.events.mouse.excl evHover
  # refresh(self)

proc clicked*[T](self: Button[T],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo nd(), "button:clicked: ", buttons,
              " kind: ", kind, " :: ", self.getId

  if not self.isActive:
    refresh(self)
  self.isActive = true

proc draw*[T](self: Button[T]) {.slot.} =
  ## button widget!
  withDraw(self):
    
    clipContent true
    cornerRadius 10.0

    if self.disabled:
      fill "#F0F0F0"
    else:
      fill "#2B9FEA"
      onHover:
        fill current.fill.spin(15)
        # this changes the color on hover!

import ../ui/utils

type
  State*[T] = object
  Captures*[V] = object
    val*: V

import macros

proc state*[T](tp: typedesc[T]): State[T] = discard

macro captures*(vals: varargs[untyped]): untyped = 
  echo "captures: ", vals.treeRepr
  var tpl = nnkTupleConstr.newNimNode()
  for val in vals:
    # echo "captures:val: ", val.getTypeInst.repr
    tpl.add val
  result = quote do:
    Captures[typeof(`tpl`)](val: `tpl`)
  echo "captures:res: ", result.repr

template button*[T; V](
    name: string,
    state: State[T],
    value: Captures[V],
    blk: untyped
) =
  block:
    var parent: Figuro = Figuro(current)
    var current {.inject.}: Button[T] = nil
    preNode(nkRectangle, name, current, parent)
    captureArgs value:
      current.postDraw = proc (widget: Figuro) =
        var current {.inject.}: Button[T] = Button[T](widget)
        if postDrawReady in widget.attrs:
          widget.attrs.excl postDrawReady
          `blk`
    postNode(Figuro(current))

template button*[V](name: string, value: Captures[V], blk: untyped) =
  button(name, state(void), value, blk)

template button*[T](name: string, state: State[T], blk: untyped) =
  button(name, state, captures(), blk)

template button*(name: string, blk: untyped) =
  button(name, state(void), void, blk)


# template button*[T](s: State[T] = state(void),
#                     name: string,
#                     blk: untyped) =
#   button(s, name, void, blk)

# template button*(name: string,
#                  value: untyped,
#                  blk: untyped) =
#   button(state(void), name, value, blk)

# template button*(name: string,
#                  blk: untyped) =
#   button(state(void), name, void, blk)

from sugar import capture
import macros
# macro button*(args: varargs[untyped]) =
#   echo "button:\n", args.treeRepr
#   # echo "do:\n", args[2].treeRepr
#   let id = args[0]
#   var stateArg: NimNode
#   var blk: NimNode
#   var capturedVals: NimNode
#   var isCaptured: bool

#   for arg in args:
#     if arg.kind == nnkExprEqExpr and arg[0].repr == "state":
#       arg[1].expectKind(nnkBracket)
#       assert arg[1].len() == 1
#       stateArg = arg[1][0]

#   if args[2].kind == nnkDo:
#     let doblk = args[2]
#     let pms = doblk.params()
#     blk = doblk[^1]
#     echo "pms:\n", pms.treeRepr

#     var vals = nnkBracket.newNimNode()
#     for arg in pms[1..^1]: vals.add arg[0]
#     capturedVals = vals
#     echo "vals: ", vals.repr
#     echo "state: ", stateArg.repr
#     isCaptured = true
#   else:
#     capturedVals = nnkBracket.newTree()
#     blk = args[^1]

#   let body = quote do:
#       current.postDraw = proc (widget: Figuro) =
#         var current {.inject.}: Button[`stateArg`] = Button[`stateArg`](widget)
#         if postDrawReady in widget.attrs:
#           widget.attrs.excl postDrawReady
#           `blk`

#   let outer = 
#     if isCaptured:
#       quote do:
#         capture `capturedVals`:
#           `body`
#     else:
#       quote do:
#         `body`

#   result = quote do:
#     block:
#       var parent: Figuro = Figuro(current)
#       var current {.inject.}: Button[`stateArg`] = nil
#       preNode(nkRectangle, `id`, current, parent)
#       `outer`
#       postNode(Figuro(current))

#   echo "button:result:\n", result.repr
  


# template button*[V](id: string, value: V, blk: untyped) =
# # template button*(id: string, blk: untyped) =
#   button[void, V](void, id, value, blk)
