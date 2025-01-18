
# Compile with nim c -d:ssl
# List text found between HTML tags on the target website.
import std/httpclient
import std/os
import std/strutils
import chame/minidom

## This minimal example shows 5 blue squares.
import figuro/widgets/button
import figuro/widgets/scrollpane
import figuro/widgets/vertical
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type HtmlLoader* = ref object of Agent
  period*: Duration

proc htmlLoaded*(tp: HtmlLoader, cssRules: seq[CssBlock]) {.signal.}

proc loadHnPage() =
  if paramCount() != 1:
    echo "Usage: " & paramStr(0) & " [URL]"
    quit(1)
  let client = newHttpClient()
  let res = client.get(paramStr(1))
  let document = parseHTML(res.bodyStream)
  var stack = @[Node(document)]
  while stack.len > 0:
    let node = stack.pop()
    if node of minidom.Text:
      let s = minidom.Text(node).data.strip()
      if s != "":
        echo s
    for i in countdown(node.childList.high, 0):
      stack.add(node.childList[i])

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    loader: AgentProxy[HtmlLoader]

proc clickLoad(self: Main,
                kind: EventKind,
                buttons: UiButtonView) {.slot.} =
  discard

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  # echo "hover: ", kind
  refresh(self)

proc buttonItem(self, node: Figuro, idx: int) =
  Button.new "button":
    # current.gridItem = nil
    with node:
      size 1'fr, 50'ux
      fill rgba(66, 177, 44, 197).to(Color).spin(idx.toFloat*50)
    connect(node, doHover, self, Main.hover)

proc draw*(self: Main) {.slot.} =
  var node = self
  with node:
    fill css"#0000AA"

  Vertical.new "outer":
    Button.new "Load":
      with node:
        size 0.5'fr, 50'ux
      connect(node, doClick, self, Main.clickLoad())
      ui.Text.new "text":
        with node:
          fill blackColor
          setText({font: "Load"}, Center, Middle)

    ScrollPane.new "scroll":
      with node:
        offset 2'pp, 2'pp
        cornerRadius 7.0'ux
        size 96'pp, 90'pp
      node.settings.size.y = 20'ui
      contents "children":
        Vertical.new "items":
          # Setup CSS Grid Template
          with node:
            offset 10'ux, 10'ux
            itemHeight cx"max-content"
          for idx in 0 .. 1:
            buttonItem(self, node, idx)

var main = Main.new()
var frame = newAppFrame(main, size=(600'ui, 480'ui))
startFiguro(frame)
