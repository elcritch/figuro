import pkg/chronicles

import ../widget
import ../ui/animations
import ./vertical

import cssgrid/prettyprints

type
  Dropdown*[T] = ref object of StatefulFiguro[T]
    elements*: seq[T]
    selected*: HashSet[int]
    isOpen*: bool
    buttonSize, halfSize, fillingSize: CssVarId


proc doSelect*[T](self: Dropdown[T], value: T) {.signal.}
proc doOpen*[T](self: Dropdown[T], isOpen: bool) {.signal.}

proc open*[T](self: Dropdown[T], value: bool) {.slot.} =
  if self.isOpen == value:
    return
  self.isOpen = value
  emit self.doOpen(self.isOpen)
  refresh(self)

proc toggleOpen*[T](self: Dropdown[T]) {.slot.} =
  self.open(not self.isOpen)

proc clicked*[T](self: Dropdown[T], kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft notin buttons:
    return
  case kind:
  of Done:
    self.toggleOpen()
  else:
    discard

proc itemClicked*[T](self: Dropdown[T], index: int, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft notin buttons:
    return
  case kind:
  of Done:
    self.selectIndex(index)
    self.open(false)
  else:
    discard

proc initialize*[T](self: Dropdown[T]) {.slot.} =
  let cssValues = self.frame[].theme.css.values
  self.buttonSize = cssValues.registerVariable("fig-dropdown-button-width", CssSize(20'ux))
  self.halfSize = cssValues.registerVariable("figHalfSize", CssSize(10'ux))
  self.fillingSize = cssValues.registerVariable("fig-dropdown-filling-size", CssSize(20'ux))
  cssValues.setFunction(self.halfSize) do (cs: ConstraintSize) -> ConstraintSize:
    case cs.kind:
    of UiFixed:
      result = csFixed(cs.coord / 2).value
    else:
      result = cs

proc draw*[T](self: Dropdown[T]) {.slot.} =
  ## dropdown widget
  withWidget(self):

    WidgetContents()
