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

    rectangle "outer":
      with this:
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
        with this:
          size 0.5'fr, 50'ux
          gridRow "top" // "items"
          gridColumn "left" // "right"
        onSignal(doMouseClick) do(self: Main, kind: EventKind, buttons: UiButtonView):
          echo "Load clicked: ", kind
          if kind == Done and not self.loading:
            emit self.htmlLoad()
            self.loading = true
            refresh(self)

        Text.new "text":
          with this:
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
          offset 2'pp, 2'pp
          cornerRadius 7.0'ux
          size 96'pp, 90'pp

        ScrollPane.new "scroll":
          offset 2'pp, 2'pp
          cornerRadius 7.0'ux
          size 96'pp, 90'pp
          echo "\n"
          # printLayout(this, cmTerminal)
          onSignal(doMouseClick) do(this: ScrollPane,
                        kind: EventKind,
                        buttons: UiButtonView):
            printLayout(this, cmTerminal)

          Vertical.new "items":
            with this:
              contentHeight cx"min-content", 3'ui

            for idx, story in self.stories:
              if idx > 3: break
              capture story, idx:
                Button.new "story" & $idx:
                  # if idx == 0:
                  #   printLayout(this, cmTerminal)
                  onSignal(doRightClick) do(this: Button[tuple[]]):
                    printLayout(this, cmTerminal)
                  with this:
                    size 1'fr, max(ux(1.0*lh.float), cx"max-content")

                  Text.new "text":
                    this.cxPadOffset[drow] = 10'ux
                    this.cxPadSize[drow] = 10'ux
                    with this:
                      # size 1'fr, ux(2*lh)
                      size cx"auto", cx"fit-content"
                      # size 1'fr, max(ux(1.5*lh.float), cx"min-content")
                      offset 10'ux, 0'ux
                      foreground blackColor
                      justify Left
                      align Middle
                      text({font: $story.link.title})

var main = Main(name: "main")
var frame = newAppFrame(main, size=(600'ui, 280'ui))
startFiguro(frame)
