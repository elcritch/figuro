import pkg/chronicles

import ../widget
import ../ui/animations
import ./vertical

import cssgrid/prettyprints

type
  Dropdown*[T] = ref object of StatefulFiguro[T]
    items*: seq[T]
    selectedIndex*: int
    isOpen*: bool
    buttonSize, halfSize, fillingSize: CssVarId


proc doSelect*[T](self: Dropdown[T], value: T) {.signal.}
proc doOpen*[T](self: Dropdown[T], isOpen: bool) {.signal.}

proc open*[T](self: Dropdown[T], value: bool) {.slot.} =
  if self.isOpen == value: return
  echo "dropdown:open: ", value
  self.isOpen = value
  emit self.doOpen(self.isOpen)
  refresh(self)

proc selectItem*[T](self: Dropdown[T], value: T) {.slot.} =
  if self.selected == value: return
  self.selected = value
  for i, item in self.items:
    if item == value:
      self.selectedIndex = i
      break
  self.state = self.items[self.selectedIndex]
  refresh(self)
  emit self.doSelect(self.selected)

proc selectIndex*[T](self: Dropdown[T], index: int) {.slot.} =
  if index < 0 or index >= self.items.len: return
  if self.selectedIndex == index: return
  self.selectedIndex = index
  self.state = self.items[index]
  refresh(self)
  emit self.doSelect(self.selected)

proc toggleOpen*[T](self: Dropdown[T]) {.slot.} =
  self.open(not self.isOpen)

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
    self.selectIndex(index)
    self.open(false)
  else:
    discard

proc initialize*[T](self: Dropdown[T]) {.slot.} =
  let cssValues = self.frame[].theme.css.values
  self.buttonSize = cssValues.registerVariable("fig-dropdown-button-width", CssSize(20'ux))
  self.halfSize = cssValues.registerVariable("figHalfSize", CssSize(10'ux))
  self.fillingSize = cssValues.registerVariable("fig-dropdown-filling-size", CssSize(20'ux))
  cssValues.setFunction(self.halfSize) do (cs: ConstraintSize) -> ConstraintSize:
    case cs.kind:
    of UiFixed:
      result = csFixed(cs.coord / 2).value
    else:
      result = cs

proc draw*[T](self: Dropdown[T]) {.slot.} =
  ## dropdown widget
  withWidget(self):
    cornerRadius 5'ui
    fill css"grey"
    border 1'ui, css"grey"

    Rectangle.new "header":
      size 100'pp, csVar(self.fillingSize)
      
      Rectangle.new "selected-item":
        size 100'pp - csVar(self.buttonSize), 100'pp
        
        Text.new "selected-text":
          size 100'pp, 100'pp
          let value = if self.items.len > 0 and self.selectedIndex >= 0 and self.selectedIndex < self.items.len:
                        $self.items[self.selectedIndex]
                      else:
                        "Select..."
          text {defaultFont(): value}
          align Middle
    
    if self.isOpen:
      Rectangle.new "dropdown-list":
        echo "dropdown-list: ", self.isOpen

        size 100'pp, cx"auto"
        offset 0'ux, csVar(self.fillingSize)
        fill css"white"
        border 1'ui, css"grey"
        
        Vertical.new "widgets-vert":
          size this, 100'pp-20'ux, cx"min-content"
          contentHeight this, cx"min-content", gap = 20'ui
          border this, 3'ui, css"green"
          alignItems CxStart
          cornerRadius 10.0'ui
          
          for i, item in self.items:
            capture i, item:
              Rectangle.new toAtom("item-" & $i):
                size 100'pp, csVar(self.fillingSize)
                if i == self.selectedIndex:
                  fill css"#2B9FEA" * 0.3
                else:
                  fill css"white"
                
                Text.new "item-text":
                  size 100'pp, 100'pp
                  text {defaultFont(): $item}
                  align Middle
                  foreground if i == self.selectedIndex: css"black" else: css"black" * 0.8
    else:
      Rectangle.new "dropdown-button":
        size csVar(self.buttonSize), 100'pp
        offset 100'pp - csVar(self.buttonSize), 0'ux

    WidgetContents()
