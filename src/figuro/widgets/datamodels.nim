import pkg/chronicles

import ../widget

type
  SelectedElements*[T] = ref object of Agent
    elements: seq[T]
    selected: HashSet[int]
    multiSelect: bool

proc clearElements*[T](self: SelectedElements[T]) =
  self.elements.setLen(0)
  self.selected.clear()

proc setElements*[T](self: SelectedElements[T], elements: seq[T]) =
  echo "setElements: ", elements
  self.elements = elements
  self.selected.clear()

proc addElement*[T](self: SelectedElements[T], element: T) =
  self.elements.add element

proc elements*[T](self: SelectedElements[T]): seq[T] =
  self.elements

proc selected*[T](self: SelectedElements[T]): lent HashSet[int] =
  self.selected

proc isSelected*[T](self: SelectedElements[T], index: int): bool =
  index in self.selected

proc multiSelect*[T](self: SelectedElements[T], multiSelect: bool) =
  self.multiSelect = multiSelect

proc doSelected*[T](self: SelectedElements[T], indexes: HashSet[int]) {.signal.}

proc toggleIndexImpl[T](self: SelectedElements[T], index: int) =
  if index < 0 or index >= self.elements.len: return
  if index in self.selected:
    self.selected.excl index
  else:
    if not self.multiSelect:
      self.selected.clear()
    self.selected.incl index

proc selectIndexImpl[T](self: SelectedElements[T], index: int, state: bool) =
  if state:
    self.selected.incl index
  else:
    self.selected.excl index

proc findIndex*[T](self: SelectedElements[T], value: T): int =
  for i, item in self.elements:
    if item == value:
      return i
  return -1

proc toggleIndex*[T](self: SelectedElements[T], index: int) {.slot.} =
  toggleIndexImpl(self, index)
  emit self.doSelected(self.selected)

proc selectIndex*[T](self: SelectedElements[T], index: int, state: bool) {.slot.} =
  selectIndexImpl(self, index, state)
  emit self.doSelected(self.selected)

proc selectItem*[T](self: SelectedElements[T], value: T) {.slot.} =
  let index = findIndex(self, value)
  if index == -1: return
  selectIndexImpl(self, index, true)
  emit self.doSelected(self.selected)

proc selectAll*[T](self: SelectedElements[T], state: bool) {.slot.} =
  for i in 0..<self.elements.len:
    selectIndexImpl(self, i, state)
  emit self.doSelected(self.selected)
