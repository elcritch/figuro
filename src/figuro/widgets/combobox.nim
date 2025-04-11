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
    selected*: int
    buttonSize, halfSize, fillingSize: CssVarId
    content*: proc(idx: int, item: T)

  ComboboxItem*[T] = ref object of Figuro
    index*: int
    value*: T
    selected*: bool


proc doSelect*[T](self: Combobox[T], index: int, value: T) {.signal.}

proc selectIndex*[T](self: Combobox[T], index: int) {.slot.} =
  if index < 0 or index >= self.elements.len: return
  if self.selected == index: return
  self.selected = index
  self.state = self.elements[index]
  refresh(self)
  emit self.doSelect(index, self.elements[index])

proc selectItem*[T](self: Combobox[T], value: T) {.slot.} =
  if self.selected == value: return
  self.selected = value
  for i, item in self.elements:
    if item == value:
      return self.selectIndex(i)


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

        for idx, elem in self.elements:
          capture idx, elem:
            ComboboxItem[T].new "item":
              this.index = idx
              this.value = elem
              WidgetContents()
              onSignal(doMouseClick) do(this: ComboboxItem[T], kind: EventKind, buttons: UiButtonView):
                echo "item clicked: ", kind, " ", buttons
                if kind == Done and MouseLeft in buttons:
                  let combobox = this.queryParent(Combobox[T]).get()
                  combobox.selectIndex(this.index)

template comboboxItem*(): auto =
  ComboboxItem[typeof(combobox.elements[0])](this.parent[])

template withContents*[T](self: Combobox[T], blk: untyped) =
  let combobox {.inject.} = this
  `blk`
