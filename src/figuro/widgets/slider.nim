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
    buttonSize, halfSize, fillingSize: CssVarId

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
      self.isTrack = false
      refresh(self)
  of Init:
    self.dragStart = self.state
    self.selected = not selected.isNil and selected.queryParent(Slider[T]).get() == self
    if self.selected:
      self.isTrack = if selected.isNil: false else: selected.name == "track"

    discard
  of Done:
    if not self.selected:
      return
    let track = self.queryDescendant("thumb-track").get()
    let delta =
      if self.isTrack:
        self.dragStart = self.min
        cursor.positionRelative(track) - uiPos(UiScalar(track.children[0].box.w / 2), 0'ui)
      else:
        initial.positionDiff(cursor)
    let offset = float(delta[dcol] / track.box.w)
    self.state = clamp(self.dragStart + offset, self.min, self.max)
    # notice "slider:drag:", delta = delta, offset= offset, state= self.state, bar= bar.box.w

    emit self.doUpdate(self.state)
    refresh(self)

proc initialize*[T](self: Slider[T]) {.slot.} =
  let cssValues = self.frame[].theme.css.values
  self.halfSize = cssValues.registerVariable("figHalfSize", CssSize(20'ux))
  self.buttonSize = cssValues.registerVariable("fig-slider-button-width", CssSize(20'ux))
  self.fillingSize = cssValues.registerVariable("fig-slider-filling-size", CssSize(20'ux))
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

      gridCols 0'ux ["left"] 0'ux 1'fr ["right-btn"] csVar(self.buttonSize) ["right"]
      gridRows 1'fr ["top"] csVar(self.fillingSize) ["bottom"] 1'fr

      let sliderWidth = csPerc(100 * self.state.float.clamp(self.min.float, self.max.float))

      Rectangle.new "track":
        gridArea 3 // 5, 2 // 3
        if self.allowTrack:
          uinodes.connect(this, doDrag, self, buttonDrag)

        Rectangle.new "filling":
          fill themeColor("fig-accent-color")
          size sliderWidth, 100'pp

      Rectangle.new "thumb-track":
        gridArea 3 // 4, 2 // 3

        Rectangle.new "thumb-bg":
          size csVar(self.buttonSize), 100'pp
          # offset sliderWidth-csVar(self.buttonSize, self.halfSize), 0'ux
          offset sliderWidth, 0'ux

          Rectangle.new "thumb":
            fill css"black" * 0.3
            size 100'pp, 100'pp
            uinodes.connect(this, doDrag, self, buttonDrag)

    WidgetContents()

proc label*[T](self: TextSlider[T], spans: openArray[(UiFont, string)]) {.slot.} =
  self.labelText.setLen(0)
  self.labelText.add spans

proc draw*[T](self: TextSlider[T]) {.slot.} =
  ## slider widget
  withWidget(self):
    draw(Slider[T](self))
    Text.new "text":
      justify Center
      align Middle
      zlevel 1
      size 100'pp, 100'pp
      text self.labelText


