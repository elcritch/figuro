import pkg/chronicles

import ../widget
import ../ui/animations

import cssgrid/prettyprints

type
  Slider*[T] = ref object of StatefulFiguro[T]
    min*, max*: T
    dragStart*: T
    sliderSize*: CssVarId

proc sliderDrag*[T](
    self: Slider[T],
    kind: EventKind,
    initial: Position,
    cursor: Position,
    overlaps: bool,
    selected: Figuro
) {.slot.} =
  trace "scrollBarDrag: ", name = self.name, kind = kind, initial = initial, cursor = cursor, overlaps = overlaps, selected = selected != self
  case kind:
  of Exit:
    self.dragStart = self.min
  of Init:
    self.dragStart = self.state
    discard
  of Done:
    let delta = initial.positionDiff(cursor)
    let bar = self.queryChild("bar").get()
    let offset = float(delta[dcol] / bar.box.w)
    self.state = clamp(self.dragStart + offset, self.min, self.max)
    # notice "slider:drag:", delta = delta, offset= offset, state= self.state, bar= bar.box.w

    refresh(self)

proc initialize*[T](self: Slider[T]) {.slot.} =
  let cssValues = self.frame[].theme.css.values
  self.sliderSize = cssValues.registerVariable("sliderSize", CssSize(20'ux))
  cssValues.setFunction(self.sliderSize) do (cs: ConstraintSize) -> ConstraintSize:
    csFixed(cs.coord / 2).value

  debug "slider:initialized", name = self.name, sliderSize = self.sliderSize, cssValues = cssValues.values, cssVariables = cssValues.variables

proc draw*[T](self: Slider[T]) {.slot.} =
  ## slider widget
  withWidget(self):
    printLayout(self, cmTerminal, self.frame[].theme.css.values)

    gridCols 10'ux ["left"] 1'fr ["right"] 10'ux
    gridRows 10'ux ["top"] 1'fr ["bottom"] 10'ux

    Rectangle.new "barFgTexture":
      gridArea 2 // 3, 2 // 3
      clipContent true

    Rectangle.new "bar":
      gridArea 2 // 3, 2 // 3
      let sliderWidth = csPerc(100 * self.state.float.clamp(self.min.float, self.max.float))
      let sliderSize = 20

      Rectangle.new "filling":
        # Draw the bar itself.
        fill css"#2B9FEA"
        size sliderWidth, 100'pp

      Rectangle.new "button":
        fill css"black" * 0.7
        size csVar(self.sliderSize), csVar(self.sliderSize)
        offset sliderWidth-csVar(self.sliderSize, self.sliderSize), 0'ux # use function with same id as our var
        cornerRadius UiScalar(sliderSize/2)
        uinodes.connect(this, doDrag, self, sliderDrag)
      
    WidgetContents()


