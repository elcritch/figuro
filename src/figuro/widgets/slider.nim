import pkg/chronicles

import ../widget
import ../ui/animations

import cssgrid/prettyprints

type
  Slider*[T] = ref object of StatefulFiguro[T]
    min*, max*: T
    dragStart*: T
    selected*: bool
    isTrack*: bool
    buttonSize*, fillingSize*, halfSize*: CssVarId

proc buttonDrag*[T](
    self: Slider[T],
    kind: EventKind,
    initial: Position,
    cursor: Position,
    overlaps: bool,
    selected: Figuro
) {.slot.} =
  debug "slider:buttonDrag: ", name = self.name, uid = self.getId, kind = kind, initial = initial, cursor = cursor, overlaps = overlaps, isSelected = self.selected

  case kind:
  of Exit:
    if not self.selected:
      return
    self.dragStart = self.min
    self.selected = false
    if self.isTrack:
      let track = self.queryDescendant("track").get()
      let rel = cursor.positionRelative(track)
      let offset = float(rel[dcol] / track.box.w)
      self.state = clamp(self.dragStart + offset, self.min, self.max)
      emit self.doUpdate(self.state)
      refresh(self)
  of Init:
    self.dragStart = self.state
    self.selected = not selected.isNil and selected.queryParent(Slider[T]).get() == self
    if self.selected:
      self.isTrack = if selected.isNil: false else: selected.name == "track"

    discard
  of Done:
    if not self.selected or self.isTrack:
      return
    let delta = initial.positionDiff(cursor)
    let track = self.queryDescendant("track").get()
    let offset = float(delta[dcol] / track.box.w)
    self.state = clamp(self.dragStart + offset, self.min, self.max)
    # notice "slider:drag:", delta = delta, offset= offset, state= self.state, bar= bar.box.w

    emit self.doUpdate(self.state)
    refresh(self)

proc initialize*[T](self: Slider[T]) {.slot.} =
  let cssValues = self.frame[].theme.css.values
  self.halfSize = cssValues.registerVariable("figHalfSize", CssSize(20'ux))
  self.buttonSize = cssValues.registerVariable("fig-slider-button-size", CssSize(20'ux))
  self.fillingSize = cssValues.registerVariable("fig-slider-filling-size", CssSize(5'ux))
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
    Rectangle.new "bg": # this is mainly to avoid issues with sub-grids :/
      size 100'pp, 100'pp

      gridCols 0'ux ["left"] 1'fr ["right"] 0'ux
      gridRows 1'fr ["top"] csVar(self.buttonSize) ["bottom"] 1'fr

      let sliderWidth = csPerc(100 * self.state.float.clamp(self.min.float, self.max.float))

      Rectangle.new "track":
        gridArea 2 // 3, 2 // 3
        uinodes.connect(this, doDrag, self, buttonDrag)

        Rectangle.new "filling":
          # Draw the bar itself.
          fill css"#2B9FEA"
          size sliderWidth, csVar(self.fillingSize)
          offset 0'ux, csVar(self.buttonSize, self.halfSize) - csVar(self.fillingSize, self.halfSize)

        Rectangle.new "thumb-bg":
          size csVar(self.buttonSize), csVar(self.buttonSize)
          offset sliderWidth-csVar(self.buttonSize, self.halfSize), 0'ux

          Rectangle.new "thumb":
            fill css"black" * 0.7
            size 100'pp, 100'pp
            offset 10'ux, 0'ux
            uinodes.connect(this, doDrag, self, buttonDrag)

    WidgetContents()


