import pkg/chronicles

import ../widget
import ../ui/animations
import ./combobox
import ./datamodels
import ./button
import ../ui/layout
import cssgrid/prettyprints

type
  Dropdown*[T] = ref object of Figuro
    data*: SelectedElements[T]
    fade* = Fader(minMax: 0.0..100.0,
                     inTimeMs: 160, outTimeMs: 160)

proc doSelect*[T](self: Dropdown[T], value: T) {.signal.}
proc doOpened*[T](self: Dropdown[T], isOpen: bool) {.signal.}

proc open*[T](self: Dropdown[T], value: bool) {.slot.} =
  if value == (Open in self.userAttrs): return
  if value:
    self.fade.fadeOut()
  else:
    self.fade.fadeIn()
  self.setUserAttr(Open, value)
  emit self.doOpened(value)
  refresh(self)

proc toggleOpen*[T](self: Dropdown[T]) {.slot.} =
  self.open(Open notin self.userAttrs)

proc clicked*[T](self: Dropdown[T], kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft in buttons and Done == kind:
    self.toggleOpen()

proc itemClicked*[T](self: Dropdown[T], index: int, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft in buttons and Done == kind:
    self.data.selectIndex(index)
    self.open(false)

proc itemsSelected*[T](self: Dropdown[T], indexes: HashSet[int]) {.slot.} =
  self.toggleOpen()

proc initialize*[T](self: Dropdown[T]) {.slot.} =
  self.data = SelectedElements[T]()
  connect(self.data, doSelected, self, itemsSelected)
  self.fade.setValue(self.fade.minMax.b)

proc draw*[T](self: Dropdown[T]) {.slot.} =
  ## dropdown widget
  withWidget(self):
    WidgetContents()

    TextButton.new "button":
      size 100'pp, 100'pp
      if self.data.selected.len > 0:
        let item = self.data.selected.toSeq()[0]
        label this, {defaultFont(): $self.data.elements[item]}
      else:
        label this, {defaultFont(): "Dropdown"}
      onSignal(doSingleClick) do(self: Dropdown[T]):
        self.toggleOpen()
      this.shadow[DropShadow] = Shadow( blur: 4.0'ui, spread: 1.0'ui, x: 1.0'ui, y: 1.0'ui, color: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.3))

    Rectangle.new "menu":
      size 100'pp, 100'ux
      offset 0'ux, 100'pp
      clipContent true
      zlevel 10

      ComboboxList[T].new "combobox":
        size 100'pp, 100'pp
        this.data = self.data
        self.fade.addTarget(this)
        offset 0'ux, csPerc(-self.fade.amount)
        # refreshLayout(this.parent[])
        # this.shadow[DropShadow] = Shadow(blur: 4.0'ui, spread: 1.0'ui, x: 1.0'ui, y: 1.0'ui, color: Color(r: 0.0, g: 0.0, b: 0.0, a: 0.7))

