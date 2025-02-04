
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22'ui)
  smallFont = UiFont(typefaceId: typeface, size: 12'ui)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc setLabel(current: Figuro, zlvl: ZLevel; left=false) =
  var this = current
  Text.new "text":
    if left:
      box this, 3'pp, 30'pp, 30'pp, 22
    else:
      box this, 70'pp, 30'pp, 30'pp, 22
    foreground this, blackColor
    text(this, {font: "zlevel " & $zlvl})

proc draw*(self: Main) {.slot.} =
  withWidget(self):
    rectangle "container":
      with this:
        fill css"#D0D0D0"
        box 3'pp, 10'pp, 30'pp, 80'pp
        cornerRadius 10.0
        clipContent false
      Text.new "text":
        with this:
          box 10'pp, 10'ux, 70'pp, 22'ux
          foreground blackColor
          text({font: "not clipped"})

      Button.new "btn":
        with this:
          box 10'pp, 15'pp, 130'pp, 20'pp
          zlevel 20.ZLevel
          setLabel(this.zlevel, left=true)

      Button.new "btn":
        with this:
          box 10'pp, 45'pp, 130'pp, 20'pp
          setLabel(this.zlevel, left=true)

      Button.new "btn":
        with this:
          box 10'pp, 75'pp, 130'pp, 20'pp
          zlevel -5.ZLevel
          setLabel(this.zlevel)

    rectangle "container":
      with this:
        fill css"#D0D0D0"
        box 50'pp, 10'pp, 30'pp, 80'pp
        cornerRadius 10.0
        clipContent true
      Text.new "text":
        with this:
          box 10'pp, 10'ux, 70'pp, 22'ux
          foreground blackColor
          text({font: "clipped"})

      Button.new "btn":
        with this:
          box 10'pp, 15'pp, 130'pp, 20'pp
          zlevel 20.ZLevel
          setLabel(this.zlevel, left=true)

      Button.new "btn":
        with this:
          box 10'pp, 45'pp, 130'pp, 20'pp
          setLabel(this.zlevel, left=true)

      Button.new "btn":
        with this:
          box 10'pp, 75'pp, 130'pp, 20'pp
          zlevel -5.ZLevel
          setLabel(this.zlevel)

var main = Main.new()
var frame = newAppFrame(main, size=(800'ui, 400'ui))
startFiguro(frame)
