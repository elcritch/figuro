
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

      TextButton.new "button2":
        size 80'pp, 60'ux
        label this, {defaultFont(): "Click me!"}
        cornerRadius 10.0'ui
        onSignal(doMouseClick) do(self: Main, kind: EventKind, buttons: UiButtonView):
          echo "clicked: ", kind, " :: ", buttons

      Slider[float].new "slider1":
        size 80'pp, 60'ux
        fill css"white".darken(0.3)
        this.minMax = 0.0..1.0
        onInit:
          this.state = 0.5

      TextSlider[float].new "slider2":
        size 80'pp, 60'ux
        fill css"white".darken(0.3)
        this.minMax = 0.0..1.0
        label this, {defaultFont(): $(this.state.round(2))}

      Dropdown[string].new "dropdown1":
        size 80'pp, 30'ux
        fill themeColor("fig-widget-background-color")
        onInit:
          setElements this.data, @["one", "two", "three", "four", "five"]

      Dropdown[string].new "dropdown2":
        size 80'pp, 30'ux
        fill themeColor("fig-widget-background-color")
        onInit:
          setElements this.data, @["one", "two", "three", "four", "five"]

      GridChild.new "child":
        size 100'pp, 30'ux

        Horizontal.new "toggle-row":
          size cx"auto", 30'ux
          contentWidth this, 70'ux
          justifyItems CxCenter

          Toggle.new "toggle1":
            size 30'ux, 30'ux
            fill css"white".darken(0.3)
            onInit:
              checked this, true

          TextToggle.new "toggle2":
            offset 0'ux, 0'ux
            size 80'ux, 30'ux
            onInit:
              checked this, true
            label this, {defaultFont(): $(if Checked in this: "On" else: "Off")}

          Checkbox.new "checkbox1":
            size 30'ux, 100'pp
            onInit:
              checked this, true
              this.userAttrs.incl FocusWithin
            fill themeColor("fig-widget-background-color")

          TextCheckbox.new "checkbox2":
            size 30'ux, 100'pp
            fill themeColor("fig-widget-background-color")
            onInit:
              checked this, true
            label this, {defaultFont(): $(if Checked in this: "On" else: "Off")}

      ComboboxList[string].new "combobox1":
        size 80'pp, 100'ux
        fill themeColor("fig-widget-background-color").darken(0.3)
        onInit:
          setElements this.data, @["one", "two", "three", "four", "five"]
          multiSelect this.data, true
          toggleIndex this.data, 1
        # echo "COMBO: ", this.name, " :: ", this.screenBox

      Rectangle.new "filler":
        size 100'pp, 100'ux
        border 3'ui, css"green"
        image "img1.png"

      Rectangle.new "filler":
        size 10'ux, 40'ux

      onSignal(doMouseClick) do(self: Main, kind: EventKind, buttons: UiButtonView):
        if kind == Done and MouseRight in buttons:
          printLayout(self, cmTerminal)

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 640'ui))
startFiguro(frame)
