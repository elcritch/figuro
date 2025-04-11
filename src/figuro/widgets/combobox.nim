import pkg/chronicles

import ../widget
import ../ui/animations
import ./vertical
import ./button
import ./scrollpane

import cssgrid/prettyprints

type
  Combobox*[T] = ref object of StatefulFiguro[T]
    elements*: seq[T]
    selectedIndex*: int
    isOpen*: bool
    buttonSize, halfSize, fillingSize: CssVarId
    content*: proc(idx: int, item: T)

  ComboboxItem*[T] = ref object of StatefulFiguro[T]

proc doSelect*[T](self: Combobox[T], value: T) {.signal.}
proc doOpen*[T](self: Combobox[T], isOpen: bool) {.signal.}

proc open*[T](self: Combobox[T], value: bool) {.slot.} =
  if self.isOpen == value: return
  echo "combobox:open: ", value
  self.isOpen = value
  emit self.doOpen(self.isOpen)
  refresh(self)

proc selectItem*[T](self: Combobox[T], value: T) {.slot.} =
  if self.selected == value: return
  self.selected = value
  for i, item in self.elements:
    if item == value:
      self.selectedIndex = i
      break
  self.state = self.elements[self.selectedIndex]
  refresh(self)
  emit self.doSelect(self.selected)

proc selectIndex*[T](self: Combobox[T], index: int) {.slot.} =
  if index < 0 or index >= self.elements.len: return
  if self.selectedIndex == index: return
  self.selectedIndex = index
  self.state = self.elements[index]
  refresh(self)
  emit self.doSelect(self.selected)

proc itemClicked*[T](self: Combobox[T], index: int, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft notin buttons:
    return
  case kind:
  of Done:
    self.selectIndex(index)
    self.open(false)
  else:
    discard

proc initialize*[T](self: Combobox[T]) {.slot.} =
  let cssValues = self.frame[].theme.css.values

proc draw*[T](self: ComboboxItem[T]) {.slot.} =
  withWidget(self):
    discard

proc draw*[T](self: Combobox[T]) {.slot.} =
  ## dropdown widget
  withWidget(self):
    cornerRadius 10'ui
    fill css"grey"
    border 1'ui, css"black"

    ScrollPane.new "scroll":
      cornerRadius 7.0'ux
      offset 1'ux, 1'ux
      size 100'pp-2'ux, 100'pp-2'ux
      fill css"white"

      Vertical.new "vertical":
        size 100'pp, cx"max-content"
        contentHeight cx"min-content"
        # WidgetContents()

        for idx, citem in self.elements:
          capture idx, citem:
            ComboboxItem[(int, T)].new "item":
              this.state = (idx, citem)
              WidgetContents()

template comboboxItem*[T](box: Combobox[T]): ComboboxItem[(int, T)] =
  ComboboxItem[(int, T)](this.parent[])

template withContents*[T](self: Combobox[T], blk: untyped) =
  let combobox {.inject.} = this
  `blk`
