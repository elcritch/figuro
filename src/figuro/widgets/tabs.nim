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
    data*: SelectedElements[string]
    buttonSize, halfSize, fillingSize: CssVarId

  Tab* = ref object of Figuro
    index*: int
    tabName*: string
    tabsContainer*: WeakRef[Tabs]

  TabItem* = ref object of Figuro
    index*: int

  TabsList* = ref object of Tabs

proc itemClicked*(self: Tabs, index: int, kind: EventKind, buttons: UiButtonView) {.slot.} =
  if MouseLeft in buttons and Done == kind:
    self.data.toggleIndex(index)

proc initialize*(self: Tabs) {.slot.} =
  self.data = SelectedElements[string]()
  let cssValues = self.frame[].theme.cssValues
  connect(self.data, doSelected, self, Figuro.refresh(), acceptVoidSlot = true)

proc draw*(self: Tab) {.slot.} =
  withWidget(self):
    border 1'ui, css"black"
    focusable true

    onInit:
      onSignal(doSingleClick) do(this: Tab):
        let tabs = this.queryParent(Tabs).get()
        tabs.data.toggleIndex(this.index)
    
    Rectangle.new "tabs-label-bg":
      # mostly for extra styling purposes
      size 100'pp, 100'pp
      this.cxMax = [cx"max-content", cx"max-content"] # TODO: important! Improve this?

      Text.new "tab-label":
        size 100'pp, 100'pp
        justify Center
        align Middle
        text {defaultFont(): self.tabName}

proc draw*(self: TabItem) {.slot.} =
  withWidget(self):
    size 100'pp, 100'pp
    let tabs = self.queryParent(Tabs).get()
    let selected = tabs.data.isSelected(self.index)
    self.setUserAttr(Hidden, not selected)
    WidgetContents()

proc draw*(self: Tabs) {.slot.} =
  ## dropdown widget
  withWidget(self):
    cornerRadius 7.0'ux
    offset 1'ux, 1'ux
    size 100'pp-2'ux, 100'pp-2'ux
    fill themeColor("fig-widget-background-color")

    Horizontal.new "tabs-list":
      size 100'pp, themeSize("fig-widget-tab-height")
      contentWidth cx"max-content"

      for idx, elem in self.data.elements:
        capture idx, elem:
          Tab.new toAtom("tab" & $idx):
            # size cx"auto", 100'pp
            let selected = self.data.isSelected(idx)
            this.setUserAttr(Selected, selected)
            this.cxMax = [cx"max-content", cx"max-content"] # TODO: important! Improve this?
            this.index = idx
            this.tabName = elem
      
    Rectangle.new "tabs-area":
      offset 0'ux, themeSize("fig-widget-tab-height")
      size 100'pp, 100'pp-themeSize("fig-widget-tab-height")
      fill css"darkgrey"
      WidgetContents()

      self.data.clearElements()
      for idx, child in this.children:
        if child of TabItem:
          let tabItem = TabItem(child)
          tabItem.index = idx
          self.data.addElement($child.name)
      
