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

proc toggleIndex*[T](self: SelectedElements[T], index: int) =
  if index < 0 or index >= self.elements.len: return
  if index in self.selected:
    self.selected.excl index
  else:
    if not self.multiSelect:
      self.selected.clear()
    self.selected.incl index
  emit self.doSelect(index, self.elements[index])

proc selectIndex*[T](self: SelectedElements[T], index: int) {.slot.} =
  toggleIndex(self, index)

proc selectItem*[T](self: SelectedElements[T], value: T) {.slot.} =
  if self.selected == value: return
  self.selected = value
  for i, item in self.elements:
    if item == value:
      return self.selectIndex(i)