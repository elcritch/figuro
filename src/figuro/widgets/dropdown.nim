import pkg/chronicles

import ../widget
import ../ui/animations
import ./combobox
import ./datamodels
import ./button

import cssgrid/prettyprints

type
  Dropdown*[T] = ref object of Figuro
    data*: SelectedElements[T]

proc doSelect*[T](self: Dropdown[T], value: T) {.signal.}
proc doOpened*[T](self: Dropdown[T], isOpen: bool) {.signal.}

proc open*[T](self: Dropdown[T], value: bool) {.slot.} =
  self.setUserAttr(Open, value)
  emit self.doOpened(value)
  refresh(self)

proc toggleOpen*[T](self: Dropdown[T]) {.slot.} =
  self.open(Open notin self.userAttrs)

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
    self.data.selectIndex(index)
    self.open(false)
  else:
    discard

proc itemsSelected*[T](self: Dropdown[T], indexes: HashSet[int]) {.slot.} =
  echo "itemsSelected: ", indexes
  self.toggleOpen()

proc initialize*[T](self: Dropdown[T]) {.slot.} =
  self.data = SelectedElements[T]()
  connect(self.data, doSelected, self, itemsSelected)

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

    ComboboxList[T].new "combobox":
        this.data = self.data
        size 100'pp, 100'ux
        zlevel 10
        this.setUserAttr(Hidden, Open notin self)
        # if Open notin self:
        #   this.flags.incl(NfInactive)
        # else:
        #   this.flags.excl(NfInactive)
