
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro

let
  typeface = defaultTypeface()
  font = UiFont(typefaceId: typeface, size: 22'ui)
  smallFont = UiFont(typefaceId: typeface, size: 12'ui)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc setLabel(current: Figuro, left=false) =
  var this = current
  Text.new "text":
    if left:
      box this, 3'pp, 30'pp, 30'pp, 22
    else:
      box this, 70'pp, 30'pp, 30'pp, 22
    foreground this, blackColor
    text(this, {font: "zlevel " & $this.zlevel})

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    onInit:
      self.size 1024'ux, 1024'ux

    Rectangle.new "container":
      fill css"#D0D0D0"
      box 3'pp, 10'pp, 30'pp, 80'pp
      cornerRadius 10.0'ui
      clipContent false

      Text.new "text":
        box 10'pp, 10'ux, 70'pp, 22'ux
        foreground blackColor
        text({font: "not clipped"})

      Button.new "btn":
        box 10'pp, 15'pp, 130'pp, 20'pp
        zlevel 20.ZLevel
        this.setLabel(left=true)

      Button.new "btn":
        box 10'pp, 45'pp, 130'pp, 20'pp
        this.setLabel(left=true)

      Button.new "btn":
        box 10'pp, 75'pp, 130'pp, 20'pp
        zlevel -5.ZLevel
        this.setLabel()

    Rectangle.new "container":
      fill css"#D0D0D0"
      box 50'pp, 10'pp, 30'pp, 80'pp
      cornerRadius 10.0'ui
      clipContent true
      Text.new "text":
        box 10'pp, 10'ux, 70'pp, 22'ux
        foreground blackColor
        text({font: "clipped"})

      Button.new "btn":
        box 10'pp, 15'pp, 130'pp, 20'pp
        zlevel 20.ZLevel
        this.setLabel(left=true)

      Button.new "btn":
        box 10'pp, 45'pp, 130'pp, 20'pp
        this.setLabel(left=true)

      Button.new "btn":
        box 10'pp, 75'pp, 130'pp, 20'pp
        zlevel -5.ZLevel
        this.setLabel()

var main = Main.new()
var frame = newAppFrame(main, size=(800'ui, 400'ui))
startFiguro(frame)
