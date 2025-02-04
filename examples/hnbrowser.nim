# Compile with nim c -d:ssl
import figuro/widgets/[button]
import figuro/widgets/[scrollpane, vertical, horizontal]
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
  self.hasHovered = kind == Init
  # echo "hover: ", kind
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    with this:
      fill css"#0000AA"

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
        proc clickLoad(self: Main,
                        kind: EventKind,
                        buttons: UiButtonView) {.slot.} =
          echo "Load clicked"
          if kind == Init and not self.loading:
            emit self.htmlLoad()
          self.loading = true
          refresh(self)
        this.connect(doMouseClick, self, clickLoad)

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

      ScrollPane.new "scroll":
        with this:
          gridRow "items" // "bottom"
          gridColumn 1 // 2
          offset 2'pp, 2'pp
          cornerRadius 7.0'ux
          size 96'pp, 90'pp

        Vertical.new "items":
          with this:
            contentHeight cx"max-content"

          for idx, story in self.stories:
            capture story:
              Button.new "story":
                with this:
                  size 1'fr, 60'ux
                  fill blueColor.lighten(0.2)
                # connect(node, doHover, self, Main.hover)
                # echo "story: ", story.link.title
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
