import figuro/widgets/button
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 16)

type
  Counter* = object

  Main* = ref object of Figuro
    mainRect: Figuro

proc draw(self: Main) {.slot.} =
  setName self, "main"
  fill self, css"#9F2B00"
  box self, 0'ux, 0'ux, 400'ux, 300'ux

  let node = self
  let childPreDraw = proc (c: Figuro) =
    let node {.inject.} = Button[int](c)
    box node, 40'ux, 30'ux, 80'ux, 80'ux
    fill node, css"#2B9F2B"
    let childPreDraw = proc (c: Figuro) =
      let node {.inject.} = Text(c)
      box node, 10'ux, 10'ux, 80'pp, 80'pp
      fill node, blackColor
      setText(node, [(font, "testing")], Center, Middle)
    widgetRegisterImpl[Text](nkText, "btnText", node, childPreDraw)

  # same as: widgetRegisterImpl[Button[int]](nkRectangle, "btn", node, childPreDraw)
  let fc = FiguroContent(name: "btn", childInit: nodeInitRect[Button[int]], childPreDraw: childPreDraw)
  node.contents.add(fc)


var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 140'ui))
startFiguro(frame)
