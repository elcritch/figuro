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

proc setOpen*[T](self: Dropdown[T], value: bool) {.slot.} =
  if value == (Open in self.userAttrs): return
  if value:
    self.fade.fadeOut()
  else:
    self.fade.fadeIn()
  self.setUserAttr(Open, value)
  emit self.doOpened(value)
  refresh(self)

proc toggleOpen*[T](self: Dropdown[T]) {.slot.} =
  echo "toggleOpen: ", Open in self.userAttrs
  self.setOpen(Open notin self.userAttrs)

proc clicked*[T](self: Dropdown[T], kind: EventKind, buttons: set[UiMouse]) {.slot.} =
  if MouseLeft in buttons and kind == Done:
    self.toggleOpen()
  elif MouseLeft in buttons and kind == Exit:
    self.setOpen(false)

proc itemClicked*[T](self: Dropdown[T], index: int, kind: EventKind, buttons: set[UiMouse]) {.slot.} =
  if MouseLeft in buttons and kind == Done:
    self.data.selectIndex(index)
    self.setOpen(false)

proc itemsSelected*[T](self: Dropdown[T], indexes: HashSet[int]) {.slot.} =
  # self.toggleOpen()
  refresh(self)

proc initialize*[T](self: Dropdown[T]) {.slot.} =
  self.data = SelectedElements[T]()
  connect(self.data, doSelected, self, itemsSelected)
  self.fade.setValue(self.fade.minMax.b)

proc fadeTick*[T](this: ComboboxList[T], val: tuple[amount, perc: float], finished: bool) {.slot.} =
  let self = this.queryParent(Dropdown[T]).get()
  if finished and Open notin self.userAttrs:
    echo "fade finished: ", this.getId
    this.setNodeAttr(NfInactive, true)
  refresh(self)

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
      connect(this, doMouseClick, self, clicked)

    Rectangle.new "menu":
      size 100'pp, 100'ux
      offset 0'ux, 100'pp
      clipContent true
      zlevel 10

      ComboboxList[T].new "combobox":
        size 100'pp-20'ux, 100'pp-10'ux
        this.data = self.data
        offset 10'ux, csPerc(-self.fade.amount)
        self.fade.addTarget(this, noRefresh = true)
        connect(self.fade, doFadeTick, this, fadeTick)
        if Open in self.userAttrs:
          this.setNodeAttr(NfInactive, false)