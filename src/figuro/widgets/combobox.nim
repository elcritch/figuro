import pkg/chronicles

import ../widget
import ../ui/animations
import ./vertical
import ./button
import ./scrollpane

import cssgrid/prettyprints

type
  Combobox*[T] = ref object of Figuro
    elements: seq[T]
    selected: HashSet[int]
    buttonSize, halfSize, fillingSize: CssVarId
    multiSelect: bool

  ComboboxItem*[T] = ref object of Figuro
    index*: int
    value*: T
    selected*: bool
    combobox*: WeakRef[Combobox[T]]

  ComboboxList*[T] = ref object of Combobox[T]

proc setElements*[T](self: Combobox[T], elements: seq[T]) =
  echo "setElements: ", elements
  self.elements = elements
  self.selected.clear()

proc multiSelect*[T](self: Combobox[T], multiSelect: bool) =
  self.multiSelect = multiSelect

proc doSelect*[T](self: Combobox[T], index: int, value: T) {.signal.}

proc toggleIndex*[T](self: Combobox[T], index: int) =
  if index < 0 or index >= self.elements.len: return
  if index in self.selected:
    self.selected.excl index
  else:
    if not self.multiSelect:
      self.selected.clear()
    self.selected.incl index
  emit self.doSelect(index, self.elements[index])

proc selectItem*[T](self: Combobox[T], value: T) {.slot.} =
  if self.selected == value: return
  self.selected = value
  for i, item in self.elements:
    if item == value:
      return self.selectIndex(i)

proc selectIndex*[T](self: Combobox[T], index: int) {.slot.} =
  toggleIndex(self, index)
  refresh(self)

proc itemClicked*[T](self: Combobox[T], index: int, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft notin buttons:
    return
  case kind:
  of Done:
    self.toggleIndex(index)
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

    echo "combobox:draw: ", self.elements

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
              this.selected = idx in self.selected
              this.value = elem
              this.combobox = self.unsafeWeakRef()
              WidgetContents()
              onSignal(doMouseClick) do(this: ComboboxItem[T], kind: EventKind, buttons: UiButtonView):
                echo "item clicked: ", kind, " ", buttons
                if kind == Done and MouseLeft in buttons:
                  # this.selected = not this.selected
                  let combobox = this.queryParent(Combobox[T]).get()
                  combobox.selectIndex(this.index)

template getComboboxItem*(): auto =
  ComboboxItem[typeof(combobox.elements[0])](this.parent[])

template ComboboxItems*[T](self: Combobox[T], blk: untyped) =
  let combobox {.inject.} = this
  `blk`

proc draw*[T](self: ComboboxList[T]) {.slot.} =
  withWidget(self):
      ComboboxItems(self):
        TextButton.new "button":
          let item = getComboboxItem()
          size 100'pp, 30'ux
          fill css"grey".lighten(0.2)
          if item.selected:
            fill css"#2B9FEA"
          this.label {defaultFont(): "Click me! " & repr item.value}
          bubble(doMouseClick)
      
      draw(Combobox[T](self))
