# Compile with nim c -d:ssl
import figuro/widgets/[button]
import figuro/widgets/[scrollpane, vertical, horizontal]
import figuro
import hnloader
import cssgrid/prettyprints

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
  self.hasHovered = kind == Init
  # echo "hover: ", kind
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):

    Rectangle.new "outer":
      with this:
        size 100'pp, 100'pp
        setGridCols 1'fr
        setGridRows ["top"] 70'ux \
                    ["items"] 1'fr \
                    ["bottom"] 40'ux \
                    ["end"] 0'ux
        setGridCols ["left"]  1'fr \
                    ["right"] 0'ux
        gridAutoFlow grRow
        justifyItems CxStretch
        alignItems CxStretch

      # setPrettyPrintMode(cmTerminal)
      # printLayout(this, cmTerminal)
      onSignal(doMouseClick) do(this: Figuro,
                    kind: EventKind,
                    buttons: UiButtonView):
        if kind == Done:
          printLayout(this.frame[].root, cmTerminal)

      Rectangle.new "top":
        gridRow "top" // "items"
        gridColumn "left" // "right"

        Button.new "Load":
          with this:
            size 50'pp, 50'ux
            offset 25'pp, 10'ux
          onSignal(doMouseClick) do(self: Main, kind: EventKind, buttons: UiButtonView):
            echo "Load clicked: ", kind
            if kind == Done and not self.loading:
              emit self.htmlLoad()
              self.loading = true
              refresh(self)

        Text.new "text":
          with this:
            size 100'pp, 100'pp
            foreground blackColor
          case self.loading:
          of false:
            with this:
              align Middle
              justify Center
              text({font: "Load"})
          of true:
            with this:
              align Middle
              justify Center
              text({font: "Loading..."})

      let lh = font.getLineHeight()

      Rectangle.new "pane":
        ## FIXME: there seems to be a bug with a scrollpane as a grid child
        with this:
          gridRow "items" // "bottom"
          gridColumn 1 // 2
          cornerRadius 7.0'ux
          size cx"auto", cx"none"

        ScrollPane.new "scroll":
          offset 0'pp, 0'pp
          cornerRadius 7.0'ux
          size 100'pp, 100'pp

          Vertical.new "items":
            with this:
              offset 0'ux, 0'ux
              size 100'pp-10'ux, cx"max-content"
              contentHeight cx"auto", 3'ui

            for idx, story in self.stories:
              # if idx > 6: break
              capture story, idx:
                Button[Submission].new "story":
                  this.state = story
                  # if idx == 0:
                  #   printLayout(this, cmTerminal)
                  onSignal(doRightClick) do(this: Button[Submission]):
                    printLayout(this, cmTerminal)
                  onSignal(doSingleClick) do(this: Button[Submission]):
                    echo "HN Story: "
                    echo this.state
                  size 1'fr, cx"auto"
                  this.cxPadOffset[drow] = 10'ux
                  this.cxPadSize[drow] = 10'ux

                  Text.new "text":
                    with this:
                      offset 10'ux, 0'ux
                      foreground blackColor
                      justify Left
                      align Middle
                      text({font: $story.link.title})

var main = Main(name: "main")
var frame = newAppFrame(main, size=(600'ui, 280'ui))
startFiguro(frame)
