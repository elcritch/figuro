# Compile with nim c -d:ssl
import figuro/widgets/[button]
import figuro/widgets/[scrollpane, vertical, horizontal]
import figuro/widget
import figuro
import hnloader

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 18)

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    loader: AgentProxy[HtmlLoader]
    loading = false
    stories: seq[Submission]

proc htmlLoad*(tp: Main) {.signal.}

proc loadStories*(self: Main, stories: seq[Submission]) {.slot.} =
  echo "got stories"
  self.stories = stories
  self.loading = false
  refresh(self)

let thr = newSigilThread()

thr.start()

proc initialize*(self: Main) {.slot.} =
  echo "Setting up loading"
  var loader = HtmlLoader(url: "https://news.ycombinator.com")
  self.loader = loader.moveToThread(thr)
  threads.connect(self, htmlLoad, self.loader, HtmlLoader.loadPage())
  threads.connect(self.loader, htmlDone, self, Main.loadStories())

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  # echo "hover: ", kind
  refresh(self)

proc draw*(self: Main) {.slot.} =
  var node = self
  with node:
    fill css"#0000AA"

  rectangle "outer":
    with node:
      offset 10'ux, 10'ux
      setGridCols 1'fr
      setGridRows ["top"] 70'ux \
                  ["items"] 1'fr \
                  ["bottom"] 20'ux
      setGridCols ["left"]  1'fr \
                  ["right"] 0'ux
      gridColumn 1 // 1
      gridAutoFlow grRow
      justifyItems CxCenter
      alignItems CxStart

    Button.new "Load":
      with node:
        size 0.5'fr, 50'ux
        gridRow "top" // "items"
        gridColumn "left" // "right"
      proc clickLoad(self: Main,
                      kind: EventKind,
                      buttons: UiButtonView) {.slot.} =
        echo "Load clicked"
        if not self.loading:
          emit self.htmlLoad()
        self.loading = true
        refresh(self)
      connect(node, doClick, self, clickLoad)

      Text.new "text":
        with node:
          fill blackColor
          offset 0'ux, 10'ux
        case self.loading:
        of false:
          node.setText({font: "Load"}, Center, Middle)
        of true:
          node.setText({font: "Loading..."}, Center, Middle)

    ScrollPane.new "scroll":
      with node:
        gridRow "items" // "bottom"
        gridColumn 1 // 2
        offset 2'pp, 2'pp
        cornerRadius 7.0'ux
        size 96'pp, 90'pp

      Vertical.new "items":
        with node:
          itemHeight cx"max-content"

        for idx, story in self.stories:
          capture story:
            Button.new "story":
              with node:
                size 1'fr, 60'ux
              # connect(node, doHover, self, Main.hover)
              # echo "story: ", story.link.title
              Text.new "text":
                offset node, 10'ux, ux(18/2)
                node.setText({font: $story.link.title}, Left, Middle)
                fill node, blackColor

var main = Main(name: "main")
var frame = newAppFrame(main, size=(600'ui, 280'ui))
startFiguro(frame)
