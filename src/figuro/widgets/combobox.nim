import pkg/chronicles

import ../widget
import ../ui/animations
import ./vertical
import ./button
import ./scrollpane
import ./datamodels
import cssgrid/prettyprints

export datamodels

type
  Combobox*[T] = ref object of Figuro
    data*: SelectedElements[T]
    buttonSize, halfSize, fillingSize: CssVarId

  ComboboxItem*[T] = ref object of Figuro
    index*: int
    value*: T
    combobox*: WeakRef[Combobox[T]]

  ComboboxList*[T] = ref object of Combobox[T]

proc itemClicked*[T](self: Combobox[T], index: int, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft in buttons and Done == kind:
    self.toggleIndex(index)
    self.open(false)

proc initialize*[T](self: Combobox[T]) {.slot.} =
  self.data = SelectedElements[T]()
  let cssValues = self.frame[].theme.css.values
  connect(self.data, doSelected, self, Figuro.refresh(), acceptVoidSlot = true)

proc draw*[T](self: ComboboxItem[T]) {.slot.} =
  withWidget(self):
    discard

proc draw*[T](self: Combobox[T]) {.slot.} =
  ## dropdown widget
  withWidget(self):
    cornerRadius 10'ui

    ScrollPane.new "scroll":
      cornerRadius 7.0'ux
      offset 1'ux, 1'ux
      size 100'pp-2'ux, 100'pp-2'ux
      fill themeColor("fig-widget-background-color")
      # this.shadow[DropShadow] = Shadow(
      #     blur: 4.0'ui,
      #     spread: 1.0'ui,
      #     x: 1.0'ui,
      #     y: 1.0'ui,
      #     color: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.3))

      Vertical.new "vertical":
        size 100'pp, cx"max-content"
        contentHeight cx"min-content"

        for idx, elem in self.data.elements:
          capture idx, elem:
            ComboboxItem[T].new "item":
              this.index = idx
              this.setUserAttr(Selected, self.data.isSelected(idx))
              this.value = elem
              this.combobox = self.unsafeWeakRef()
              WidgetContents()
              onSignal(doMouseClick) do(this: ComboboxItem[T], kind: EventKind, buttons: UiButtonView):
                if kind == Done and MouseLeft in buttons:
                  # this.selected = not this.selected
                  let combobox = this.queryParent(Combobox[T]).get()
                  combobox.data.toggleIndex(this.index)

template getComboboxItem*(): auto =
  ComboboxItem[typeof(combobox.data.elements[0])](this.parent[])

template ComboboxItems*[T](self: Combobox[T], blk: untyped) =
  let combobox {.inject.} = this
  `blk`

proc draw*[T](self: ComboboxList[T]) {.slot.} =
  withWidget(self):
    ComboboxItems(self):
      TextButton.new "button":
        let item = getComboboxItem()
        size 100'pp, 30'ux
        fill themeColor("fig-widget-background-color")
        if Selected in item:
          fill themeColor("fig-accent-color")
        label this, {defaultFont(): "Click me! " & repr item.value}
        bubble(doMouseClick)
  
    draw(Combobox[T](self))
