
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

proc draw*(self: Main) {.slot.} =
  withDraw(self):

    template setLabel(zlvl; left=false) =
      text "text":
        if left:
          box 3'pp, 30'pp, 30'pp, 22
        else:
          box 70'pp, 30'pp, 30'pp, 22
        fill blackColor
        setText({font: "zlevel " & $zlvl})

    rectangle "container":
      fill "#D0D0D0"
      box 3'pp, 10'pp, 30'pp, 80'pp
      cornerRadius 10.0
      text "text":
        box 10'pp, 10'ux, 70'pp, 22'ux
        fill blackColor
        setText({font: "not clipped"})

      button "btn":
        box 10'pp, 15'pp, 130'pp, 20'pp
        current.zlevel = 20.ZLevel
        setLabel(current.zlevel, left=true)

      button "btn":
        box 10'pp, 45'pp, 130'pp, 20'pp
        setLabel(current.zlevel, left=true)

      button "btn":
        box 10'pp, 75'pp, 130'pp, 20'pp
        current.zlevel = -5.ZLevel
        setLabel(current.zlevel)

    rectangle "container":
      fill "#D0D0D0"
      box 50'pp, 10'pp, 30'pp, 80'pp
      cornerRadius 10.0
      clipContent true
      text "text":
        box 10'pp, 10'ux, 70'pp, 22'ux
        fill blackColor
        setText({font: "clipped"})

      button "btn":
        box 10'pp, 15'pp, 130'pp, 20'pp
        current.zlevel = 20.ZLevel
        setLabel(current.zlevel, left=true)

      button "btn":
        box 10'pp, 45'pp, 130'pp, 20'pp
        setLabel(current.zlevel, left=true)

      button "btn":
        box 10'pp, 75'pp, 130'pp, 20'pp
        current.zlevel = -5.ZLevel
        setLabel(current.zlevel)

var main = Main.new()
connect(main, doDraw, main, Main.draw)

echo "main: ", main.listeners

app.width = 800
app.height = 400

startFiguro(main)
