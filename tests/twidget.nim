
## This minimal example shows 5 blue squares.
import figuro/widgets/[button, vertical, slider, input, toggle, horizontal, checkbox, dropdown, combobox]
import figuro/widgets/scrollpane
import figuro
import cssgrid/prettyprints

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool = false
    hoveredAlpha: float = 0.0


proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    size 100'pp, 100'pp
    cornerRadius 10.0'ui
    fill css"lightgrey"
    border 3'ui, blackColor
    padding 10'ux
    
    Vertical.new "widgets-vert":
      size this, 100'pp-20'ux, cx"min-content"
      contentHeight this, cx"min-content", gap = 20'ui
      # border this, 3'ui, css"green"
      alignItems CxStart
      cornerRadius 10.0'ui

      Rectangle.new "filler":
        size 10'ux, 40'ux

      TextButton.new "slider1":
        size 80'pp, 60'ux
        this.label({defaultFont(): "Click me!"})
        cornerRadius 10.0'ui

      Slider[float].new "slider1":
        size 80'pp, 60'ux
        fill css"white".darken(0.3)
        this.min = 0.0
        this.max = 1.0
        onInit:
          this.state = 0.5

      TextSlider[float].new "slider2":
        size 80'pp, 60'ux
        fill css"white".darken(0.3)
        this.min = 0.0
        this.max = 1.0
        this.label {defaultFont(): $(this.state.round(2))}

      GridChild.new "child":
        size 100'pp, 30'ux

        Horizontal.new "toggle-row":
          # size cx"min-content", 30'ux
          size cx"auto", 30'ux
          contentWidth this, 70'ux
          justifyItems CxCenter

          Toggle.new "toggle1":
            size 30'ux, 30'ux
            fill css"white".darken(0.3)

          Rectangle.new "filler":
            size 10'ux, 100'pp

          TextToggle.new "toggle2":
            offset 0'ux, 0'ux
            size 80'ux, 30'ux
            # this.enabled true
            this.label {defaultFont(): $(if this.isEnabled: "On" else: "Off")}

          Checkbox.new "checkbox1":
            size 30'ux, 100'pp
            fill css"white".darken(0.3)

          TextCheckbox.new "checkbox2":
            size 30'ux, 100'pp
            fill css"white".darken(0.3)
            # onInit:
            #   this.enabled true
            this.label {defaultFont(): $(if this.isEnabled: "On" else: "Off")}

      Dropdown[int].new "dropdown1":
        size 80'pp, 30'ux
        fill css"white".darken(0.3)
        this.items = @[1, 2, 3, 4, 5]
        onInit:
          this.selectedIndex = 0

      ComboboxList[string].new "combobox1":
        size 80'pp, 200'ux
        fill css"white".darken(0.3)
        this.elements = @["one", "two", "three", "four", "five"]
        onInit:
          this.selected = @[0]

        withContents(this):
          TextButton.new "button":
            let item = comboboxItem()
            size 100'pp, 30'ux
            fill css"grey".lighten(0.2)
            if item.selected:
              fill css"#2B9FEA"
            this.label {defaultFont(): "Click me! " & repr item.value}
            bubble(doMouseClick)

      Rectangle.new "filler":
        size 10'ux, 40'ux

      onSignal(doMouseClick) do(self: Main, kind: EventKind, buttons: UiButtonView):
        if kind == Done and MouseRight in buttons:
          printLayout(self, cmTerminal)

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 640'ui))
startFiguro(frame)
