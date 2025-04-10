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
    allowTrack*: bool = true # determine if the track can be dragged
    buttonSize, halfSize: CssVarId

  TextSlider*[T] = ref object of Slider[T]
    labelText: seq[(UiFont, string)]

proc buttonDrag*[T](
    self: Slider[T],
    kind: EventKind,
    initial: Position,
    cursor: Position,
    overlaps: bool,
    selected: Figuro
) {.slot.} =
  trace "slider:buttonDrag: ", name = self.name, uid = self.getId, kind = kind, initial = initial, cursor = cursor, isTrack = self.isTrack, overlaps = overlaps, isSelected = self.selected
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
      self.isTrack = false
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
  self.buttonSize = cssValues.registerVariable("fig-slider-button-width", CssSize(20'ux))
  cssValues.setFunction(self.halfSize) do (cs: ConstraintSize) -> ConstraintSize:
    case cs.kind:
    of UiFixed:
      result = csFixed(cs.coord / 2).value
    else:
      result = cs

proc draw*[T](self: Slider[T]) {.slot.} =
  ## slider widget
  withWidget(self):
    Rectangle.new "bg": # this is mainly to avoid issues with sub-grids :/
      size 100'pp, 100'pp

      gridCols 0'ux ["left"] 1'fr ["right-btn"] csVar(self.buttonSize) ["right"]
      gridRows 1'fr ["top"] csVar(self.buttonSize) ["bottom"] 1'fr

      let sliderWidth = csPerc(100 * self.state.float.clamp(self.min.float, self.max.float))

      Rectangle.new "track":
        gridArea 2 // 4, 2 // 3
        if self.allowTrack:
          uinodes.connect(this, doDrag, self, buttonDrag)

        Rectangle.new "filling":
          fill css"#2B9FEA"
          size sliderWidth, 100'pp

      Rectangle.new "thumb-track":
        gridArea 2 // 3, 2 // 3

        Rectangle.new "thumb-bg":
          size csVar(self.buttonSize), 100'pp
          offset sliderWidth-csVar(self.buttonSize, self.halfSize), 0'ux

          Rectangle.new "thumb":
            fill css"black" * 0.3
            size 100'pp, 100'pp
            offset 10'ux, 0'ux
            uinodes.connect(this, doDrag, self, buttonDrag)

    WidgetContents()

proc label*[T](self: TextSlider[T], spans: openArray[(UiFont, string)]) {.slot.} =
  self.labelText.setLen(0)
  self.labelText.add spans

proc draw*[T](self: TextSlider[T]) {.slot.} =
  ## slider widget
  withWidget(self):
    draw(Slider[T](self))
    Text.new "slider2-text":
      justify Center
      align Middle
      zlevel 1
      size 40'ux, 10'ux
      offset 50'pp-20'ux, 50'pp-8'ux
      text self.labelText


