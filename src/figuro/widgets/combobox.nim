import pkg/chronicles

import ../widget
import ../ui/animations
import ./vertical
import ./button
import ./scrollpane

import cssgrid/prettyprints

type
  Combobox*[T] = ref object of StatefulFiguro[T]
    items*: seq[T]
    selectedIndex*: int
    isOpen*: bool
    buttonSize, halfSize, fillingSize: CssVarId

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
  for i, item in self.items:
    if item == value:
      self.selectedIndex = i
      break
  self.state = self.items[self.selectedIndex]
  refresh(self)
  emit self.doSelect(self.selected)

proc selectIndex*[T](self: Combobox[T], index: int) {.slot.} =
  if index < 0 or index >= self.items.len: return
  if self.selectedIndex == index: return
  self.selectedIndex = index
  self.state = self.items[index]
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
        for idx in 0 .. 15:
          capture idx:
            TextButton.new "button":
              size 100'pp, cx"auto"
              fill css"grey".lighten(0.2)
              this.label {defaultFont(): $idx}
