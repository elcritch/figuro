import pkg/chronicles

import ../widget
import ../ui/animations

import cssgrid/prettyprints

type
  Slider*[T] = ref object of StatefulFiguro[T]
    min*, max*: T
    dragStart*: T
    buttonSize*, fillingSize*, halfSize*: CssVarId

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

    emit self.doUpdate(self.state)
    refresh(self)

proc initialize*[T](self: Slider[T]) {.slot.} =
  let cssValues = self.frame[].theme.css.values
  self.halfSize = cssValues.registerVariable("figHalfSize", CssSize(20'ux))
  self.buttonSize = cssValues.registerVariable("figSliderButtonSize", CssSize(20'ux))
  self.fillingSize = cssValues.registerVariable("figSliderFillingSize", CssSize(20'ux))
  cssValues.setFunction(self.halfSize) do (cs: ConstraintSize) -> ConstraintSize:
    csFixed(cs.coord / 2).value

  debug "slider:initialized", name = self.name, buttonSize = self.buttonSize, fillingSize = self.fillingSize, cssValues = cssValues.values, cssVariables = cssValues.variables

proc draw*[T](self: Slider[T]) {.slot.} =
  ## slider widget
  withWidget(self):
    printLayout(self, cmTerminal, self.frame[].theme.css.values)
    debug "slider:draw", name = self.name, buttonSize = self.buttonSize, fillingSize = self.fillingSize, cssValues = self.frame[].theme.css.values.values, cssVariables = self.frame[].theme.css.values.variables

    gridCols csVar(self.buttonSize, self.halfSize) ["left"] 1'fr ["right"] csVar(self.buttonSize, self.halfSize)
    gridRows 1'fr ["top"] csVar(self.buttonSize) ["bottom"] 1'fr

    let sliderWidth = csPerc(100 * self.state.float.clamp(self.min.float, self.max.float))

    Rectangle.new "bar":
      gridArea 2 // 3, 2 // 3

      Rectangle.new "filling":
        # Draw the bar itself.
        fill css"#2B9FEA"
        size sliderWidth, csVar(self.buttonSize)

      Rectangle.new "button":
        fill css"black" * 0.7
        size csVar(self.buttonSize), csVar(self.buttonSize)
        offset sliderWidth-csVar(self.buttonSize, self.halfSize), 0'ux
        uinodes.connect(this, doDrag, self, sliderDrag)
      
    WidgetContents()


