# Compile with nim c -d:ssl
import figuro/widgets/[button]
import figuro/widgets/[scrollpane, vertical, horizontal]
import figuro
import hnloader
import std/os
import cssgrid/prettyprints

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 18)
  smallFont = UiFont(typefaceId: typeface, size: 15)

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
        setGridRows ["top"] 70'ux \
                    ["items"] 1'fr \
                    ["bottom"] 40'ux \
                    ["end"] 0'ux
        setGridCols ["left"]  3'fr \
                    ["middle"] 5'fr \
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
            foreground css"black"
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

      Rectangle.new "stories":
        ## FIXME: there seems to be a bug with a scrollpane as a grid child
        gridRow "items" // "bottom"
        gridColumn "left" // "middle"
        cornerRadius 7.0'ux

        ScrollPane.new "scroll":
          offset 0'pp, 0'pp
          cornerRadius 7.0'ux
          size 100'pp, 100'pp

          Vertical.new "items":
            offset 0'ux, 0'ux
            size 100'pp, cx"max-content"
            contentHeight cx"auto", 3'ui

            for idx, story in self.stories:
              # if idx < 2: continue
              # if idx > 2: break
              capture story, idx:
                Button[Submission].new "story":
                  # size cx"auto", cx"auto"
                  paddingXY 5'ux, 5'ux

                  this.state = story
                  onSignal(doRightClick) do(this: Button[Submission]):
                    printLayout(this, cmTerminal)
                  onSignal(doSingleClick) do(this: Button[Submission]):
                    echo "HN Story: "
                    echo repr this.state

                  Vertical.new "story-fields":
                    contentHeight cx"auto"

                    Rectangle.new "title-box":
                      # size 100'pp, cx"max-content"
                      paddingXY 0'ux, 5'ux
                      Text.new "id":
                        offset 5'ux, 0'ux
                        foreground css"black"
                        justify Left
                        align Middle
                        text({font: $story.rank})

                      Text.new "title":
                        # printLayout(this.parent[].parent[].parent[], cmTerminal)
                        offset 40'ux, 0'ux
                        foreground css"black"
                        justify Left
                        align Middle
                        text({font: $story.link.title})

                    Rectangle.new "info-box-outer":
                      size 100'pp, cx"none"

                      Rectangle.new "info-box":
                        size 100'pp, cx"none"
                        with this:
                          setGridCols 40'ux ["upvotes"] 2'fr 10'ux \
                                      ["comments"] 2'fr 10'ux \
                                      ["user"] 2'fr
                          setGridRows 1'fr
                          # gridAutoFlow grColumn
                          justifyItems CxStretch
                          alignItems CxStretch

                        Text.new "upvotes":
                          gridColumn "upvotes" // span "upvotes"
                          gridRow 1
                          foreground css"black"
                          justify Left
                          align Middle
                          text({smallFont: "$1 upvotes" % $story.subText.votes})

                        Text.new "comments":
                          gridColumn "comments" // span "comments"
                          gridRow 1
                          foreground css"black"
                          justify Left
                          align Middle
                          text({smallFont: "$1 comments" % $story.subText.comments})

      Rectangle.new "panel":
        gridRow "items" // "bottom"
        gridColumn "middle" // "right"
        cornerRadius 7.0'ux
        # size cx"auto", cx"none"

        Rectangle.new "panel-inner":
          # size 100'pp, 100'pp
          fill css"red"
          border 3, css"red"

          Text.new "upvotes":
            foreground css"black"
            justify Left
            align Middle
            text({font: "hello world"})


var main = Main()
var frame = newAppFrame(main, size=(600'ui, 280'ui))
startFiguro(frame)
