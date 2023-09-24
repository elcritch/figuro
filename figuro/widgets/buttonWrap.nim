
import commons
import ../ui/utils

type
  Button*[T] = ref object of StatefulFiguro[T]
    label*: string
    isActive*: bool
    disabled*: bool

proc hover*[T](self: Button[T], kind: EventKind) {.slot.} =
  echo "button:hovered: ", kind, " :: ", self.getId,
          " buttons: ", self.events.mouse
  

proc clicked*[T](self: Button[T],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo nd(), "button:clicked: ", buttons,
              " kind: ", kind, " :: ", self.getId

  if not self.isActive:
    refresh(self)
  self.isActive = true

import macros

{.hint[Name]:off.}
template TemplateContents*[T](fig: T): untyped =
  if fig.contentsDraw != nil:
    fig.contentsDraw(current, Figuro(fig))
{.hint[Name]:on.}

macro contents*(args: varargs[untyped]): untyped =
  # echo "contents:\n", args.treeRepr
  let wargs = args.parseWidgetArgs()
  let (id, stateArg, capturedVals, blk) = wargs
  let hasCaptures = newLit(not capturedVals.isNil)
  echo "id: ", id
  echo "stateArg: ", stateArg.repr
  echo "captured: ", capturedVals.repr
  echo "blk: ", blk.repr

  result = quote do:
    block:
      when not compiles(current.typeof):
        {.error: "missing `var current` in current scope!".}
      let parentWidget = current
      echo "contents DRAW: pwidget: ", parentWidget.typeof, " ", parentWidget.getId 
      wrapCaptures(`hasCaptures`, `capturedVals`):
        current.contentsDraw = proc (c, w: Figuro) =
          var current {.inject.} = c
          var widget {.inject.} = typeof(parentWidget)(w)
          if contentsDrawReady in widget.attrs:
            widget.attrs.excl contentsDrawReady
            `blk`

  echo "contents: ", result.repr

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
    rectangle "btnBody":
      TemplateContents(self)


exportWidget(button, Button)
