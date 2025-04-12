import pkg/chronicles

import ../widget
import ../ui/animations
import ./vertical

import cssgrid/prettyprints

type
  Dropdown*[T] = ref object of Figuro


proc doSelect*[T](self: Dropdown[T], value: T) {.signal.}
proc doOpened*[T](self: Dropdown[T], isOpen: bool) {.signal.}

proc open*[T](self: Dropdown[T], value: bool) {.slot.} =
  self.setUserAttr({Open}, value)
  emit self.doOpened(value)
  refresh(self)

proc toggleOpen*[T](self: Dropdown[T]) {.slot.} =
  self.open(Open notin self.userAttrs)

proc setElements*[T](self: Dropdown[T], elements: seq[T]) =
  self.elements = elements
  self.selected.clear()

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

proc draw*[T](self: Dropdown[T]) {.slot.} =
  ## dropdown widget
  withWidget(self):

    WidgetContents()
