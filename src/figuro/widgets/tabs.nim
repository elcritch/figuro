import pkg/chronicles

import ../widget
import ../ui/animations
import ./horizontal
import ./button
import ./scrollpane
import ./datamodels
import cssgrid/prettyprints

export datamodels
export horizontal

type
  Tabs* = ref object of Figuro
    data*: SelectedElements[int]
    buttonSize, halfSize, fillingSize: CssVarId

  Tab* = ref object of Figuro
    index*: int
    tabsContainer*: WeakRef[Tabs]

  TabItem* = ref object of Figuro
    index*: int

  TabsList* = ref object of Tabs

proc itemClicked*(self: Tabs, index: int, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft in buttons and Done == kind:
    self.data.toggleIndex(index)

proc initialize*(self: Tabs) {.slot.} =
  self.data = SelectedElements[int]()
  let cssValues = self.frame[].theme.cssValues
  connect(self.data, doSelected, self, Figuro.refresh(), acceptVoidSlot = true)

proc draw*(self: Tab) {.slot.} =
  withWidget(self):
    border 1'ui, css"black"
    setUserAttr(Focusable, true)

    onInit:
      onSignal(doSingleClick) do(this: Tab):
        let tabs = this.queryParent(Tabs).get()
        tabs.data.toggleIndex(this.index)

proc draw*(self: TabItem) {.slot.} =
  withWidget(self):
    discard

proc draw*(self: Tabs) {.slot.} =
  ## dropdown widget
  withWidget(self):
    cornerRadius 7.0'ux
    offset 1'ux, 1'ux
    size 100'pp-2'ux, 100'pp-2'ux
    fill themeColor("fig-widget-background-color")

    Horizontal.new "tabs-list":
      size 100'pp, cx"max-content"
      contentWidth cx"min-content"

      for idx, elem in self.data.elements:
        capture idx, elem:
          Tab.new toAtom("tab" & $idx):
            this.index = idx

    WidgetContents()

    this.data.clearElements()
    for idx, child in self.children:
      if child of TabItem:
        let tabItem = TabItem(child)
        tabItem.index = idx
        this.data.addElement(tabItem.index)


