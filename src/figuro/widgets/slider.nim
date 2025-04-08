import pkg/chronicles

import ../widget
import ../ui/animations

import cssgrid/prettyprints

type
  Slider*[T] = ref object of StatefulFiguro[T]
    min*, max*: T
    dragStart*: T
    buttonSize*, fillingSize*, halfSize*, sliderSides*: CssVarId

proc buttonDrag*[T](
    self: Slider[T],
    kind: EventKind,
    initial: Position,
    cursor: Position,
    overlaps: bool,
    selected: Figuro
) {.slot.} =
  debug "slider:buttonDrag: ", name = self.name, kind = kind, initial = initial, cursor = cursor, overlaps = overlaps, selected = selected != self
  case kind:
  of Exit:
    self.dragStart = self.min
    if initial == cursor:
      let bar = self.queryChild("bar").get()
      let rel = initial.positionRelative(bar)
      let offset = float(rel[dcol] / bar.box.w)
      self.state = clamp(self.dragStart + offset, self.min, self.max)
      emit self.doUpdate(self.state)
      refresh(self)
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
  self.buttonSize = cssValues.registerVariable("fig-slider-button-size", CssSize(20'ux))
  self.fillingSize = cssValues.registerVariable("fig-slider-filling-size", CssSize(5'ux))
  self.sliderSides = cssValues.registerVariable("fig-slider-sides", CssSize(10'ux))
  cssValues.setFunction(self.halfSize) do (cs: ConstraintSize) -> ConstraintSize:
    case cs.kind:
    of UiFixed:
      result = csFixed(cs.coord / 2).value
    else:
      result = cs


  debug "slider:initialized", name = self.name, buttonSize = self.buttonSize, fillingSize = self.fillingSize, cssValues = cssValues.values, cssVariables = cssValues.variables

proc draw*[T](self: Slider[T]) {.slot.} =
  ## slider widget
  withWidget(self):
    printLayout(self, cmTerminal, self.frame[].theme.css.values)
    debug "slider:draw", name = self.name, buttonSize = self.buttonSize, fillingSize = self.fillingSize, cssValues = self.frame[].theme.css.values.values, cssVariables = self.frame[].theme.css.values.variables

    gridCols csVar(self.sliderSides) ["left"] 1'fr ["right"] csVar(self.sliderSides)
    gridRows 1'fr ["top"] csVar(self.buttonSize) ["bottom"] 1'fr

    let sliderWidth = csPerc(100 * self.state.float.clamp(self.min.float, self.max.float))

    Rectangle.new "bar":
      gridArea 2 // 3, 2 // 3
      uinodes.connect(this, doDrag, self, buttonDrag)

      Rectangle.new "filling":
        # Draw the bar itself.
        fill css"#2B9FEA"
        size sliderWidth, csVar(self.fillingSize)
        offset 0'ux, csVar(self.buttonSize, self.halfSize) - csVar(self.fillingSize, self.halfSize)

      Rectangle.new "button-bg":
        size csVar(self.buttonSize), csVar(self.buttonSize)
        offset sliderWidth-csVar(self.buttonSize, self.halfSize), 0'ux

        Rectangle.new "button":
          fill css"black" * 0.7
          size 100'pp, 100'pp
          offset 10'ux, 0'ux
          uinodes.connect(this, doDrag, self, buttonDrag)

    WidgetContents()


