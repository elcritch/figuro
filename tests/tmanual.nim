import figuro/widgets/button
import figuro

let
  typeface = defaultTypeface()
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
      let this {.inject.} = Text(c)
      box this, 0'ux, 0'ux, 100'pp, 100'pp
      foreground this, blackColor
      justify this, Center
      align this, Middle
      text(this, {font: "testing"})
    widgetRegisterImpl[Text](atom"btnText", node, childPreDraw)

  # same as: widgetRegisterImpl[Button[int]](nkRectangle, "btn", node, childPreDraw)
  let fc = FiguroContent(name: atom"btn", childInit: nodeInit[Button[int]], childPreDraw: childPreDraw)
  node.contents.add(fc)


var main = Main.new()
var frame = newAppFrame(main, size=(400'ui, 140'ui))
startFiguro(frame)
