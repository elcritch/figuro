
## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widget
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
  var node = current
  text "text":
    if left:
      box node, 3'pp, 30'pp, 30'pp, 22
    else:
      box node, 70'pp, 30'pp, 30'pp, 22
    fill node, blackColor
    setText(node, {font: "zlevel " & $zlvl})

proc draw*(self: Main) {.slot.} =
  var node = self

  rectangle "container":
    with node:
      fill css"#D0D0D0"
      box 3'pp, 10'pp, 30'pp, 80'pp
      cornerRadius 10.0
      clipContent false
    text "text":
      with node:
        box 10'pp, 10'ux, 70'pp, 22'ux
        fill blackColor
        setText({font: "not clipped"})

    Button.new "btn":
      with node:
        box 10'pp, 15'pp, 130'pp, 20'pp
        zlevel 20.ZLevel
        setLabel(node.zlevel, left=true)

    Button.new "btn":
      with node:
        box 10'pp, 45'pp, 130'pp, 20'pp
        setLabel(node.zlevel, left=true)

    Button.new "btn":
      with node:
        box 10'pp, 75'pp, 130'pp, 20'pp
        zlevel -5.ZLevel
        setLabel(node.zlevel)

  rectangle "container":
    with node:
      fill css"#D0D0D0"
      box 50'pp, 10'pp, 30'pp, 80'pp
      cornerRadius 10.0
      clipContent true
    text "text":
      with node:
        box 10'pp, 10'ux, 70'pp, 22'ux
        fill blackColor
        setText({font: "clipped"})

    Button.new "btn":
      with node:
        box 10'pp, 15'pp, 130'pp, 20'pp
        zlevel 20.ZLevel
        setLabel(node.zlevel, left=true)

    Button.new "btn":
      with node:
        box 10'pp, 45'pp, 130'pp, 20'pp
        setLabel(node.zlevel, left=true)

    Button.new "btn":
      with node:
        box 10'pp, 75'pp, 130'pp, 20'pp
        zlevel -5.ZLevel
        setLabel(node.zlevel)

var main = Main.new()
var frame = newAppFrame(main, size=(800'ui, 400'ui))
startFiguro(frame)
