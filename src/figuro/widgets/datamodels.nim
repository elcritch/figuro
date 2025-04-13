import pkg/chronicles

import ../widget

type
  SelectedElements*[T] = ref object of Agent
    elements: seq[T]
    selected: HashSet[int]
    multiSelect: bool

proc setElements*[T](self: SelectedElements[T], elements: seq[T]) =
  echo "setElements: ", elements
  self.elements = elements
  self.selected.clear()

proc elements*[T](self: SelectedElements[T]): seq[T] =
  self.elements

proc isSelected*[T](self: SelectedElements[T], index: int): bool =
  index in self.selected

proc multiSelect*[T](self: SelectedElements[T], multiSelect: bool) =
  self.multiSelect = multiSelect

proc doSelect*[T](self: SelectedElements[T], index: int, value: T) {.signal.}

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
  emit self.doSelect(index, self.elements[index])

proc selectIndex*[T](self: SelectedElements[T], index: int, state: bool) {.slot.} =
  selectIndexImpl(self, index, state)
  emit self.doSelect(index, self.elements[index])

proc selectItem*[T](self: SelectedElements[T], value: T) {.slot.} =
  let index = findIndex(self, value)
  if index == -1: return
  selectIndexImpl(self, index, true)
  emit self.doSelect(index, value)

proc selectAll*[T](self: SelectedElements[T], state: bool) {.slot.} =
  for i in 0..<self.elements.len:
    selectIndexImpl(self, i, state)
    emit self.doSelect(i, self.elements[i])
