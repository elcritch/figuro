# Compile with nim c -d:ssl
import figuro/widgets/[button]
import figuro/widgets/[scrollpane, vertical, horizontal]
import figuro
import hnloader
import std/os
import cssgrid/prettyprints
import std/terminal

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
    currentStory: Submission
    currentStoryMarkdown: string

proc htmlLoad*(tp: Main, url: string) {.signal.}
proc markdownLoad*(tp: Main, url: string) {.signal.}

proc loadStories*(self: Main, stories: seq[Submission]) {.slot.} =
  echo "got stories"
  self.stories = stories
  self.loading = false
  refresh(self)

proc loadStoryMarkdown*(self: Main, markdown: string) {.slot.} =
  echo "got markdown", markdown.len
  self.currentStoryMarkdown = markdown
  refresh(self)


let thr = newSigilThread()

thr.start()

proc initialize*(self: Main) {.slot.} =
  echo "Setting up loading"
  var loader = HtmlLoader()
  self.loader = loader.moveToThread(thr)
  threads.connect(self, htmlLoad, self.loader, HtmlLoader.loadPage())
  threads.connect(self.loader, htmlDone, self, Main.loadStories())
  
  threads.connect(self, markdownLoad, self.loader, HtmlLoader.loadPageMarkdown())
  threads.connect(self.loader, markdownDone, self, Main.loadStoryMarkdown())

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
                    ["items"] auto \
                    ["bottom"] 40'ux \
                    ["end"] 0'ux
        setGridCols ["left"]  3'fr \
                    ["middle"] 5'fr \
                    ["right"] 0'ux
        gridAutoFlow grRow
        justifyItems CxStretch
        alignItems CxStretch

      # onSignal(doMouseClick) do(this: Figuro,
      #               kind: EventKind,
      #               buttons: UiButtonView):
      #   if kind == Done:
      #     printLayout(this.frame[].root, cmTerminal)

      Rectangle.new "top":
        gridRow "top" // "items"
        gridColumn "left" // "right"

        Button.new "Load":
          size 50'pp, 50'ux
          offset 25'pp, 10'ux

          onSignal(doMouseClick) do(self: Main, kind: EventKind, buttons: UiButtonView):
            echo "Load clicked: ", kind
            if kind == Done and not self.loading:
              emit self.htmlLoad("https://news.ycombinator.com")
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
          fill css"grey"
          let scrollPane = this

          Vertical.new "items":
            offset 0'ux, 0'ux
            size 100'pp-scrollPane.settings.size[dcol], cx"max-content"
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
                    let self = this.findParent(Main)
                    if not self.isNil:
                      self.currentStory = this.state
                      emit self.markdownLoad(self.currentStory.link.href)
                      refresh(self)

                  Vertical.new "story-fields":
                    contentHeight cx"auto"

                    Rectangle.new "title-box":
                      # size 100'pp, cx"max-content"
                      paddingXY 0'ux, 5'ux
                      when false: #Text.new "id":
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

                      when false: #Rectangle.new "info-box":
                        size 100'pp, cx"none"
                        with this:
                          setGridCols 40'ux ["upvotes"] 1'fr 5'ux \
                                      ["comments"] 1'fr 5'ux \
                                      ["user"] 1'fr
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

        Rectangle.new "story-pane":
          size 100'pp, 100'pp
          fill css"black"
          paddingWH 3'ux, 3'ux

          ScrollPane.new "story-scroll":
            offset 0'pp, 0'pp
            cornerRadius 7.0'ux
            size 100'pp, 100'pp
            let scrollPane = this

            Rectangle.new "story-pane-inner":
              fill css"black"
              size 100'pp-scrollPane.settings.size[dcol], cx"max-content"
              paddingWH 10'ux, 20'ux

              Text.new "story-text":
                this.cxSize[dcol] = 100'pp
                # foreground css"white"
                justify Left
                align Top
                if self.currentStoryMarkdown != "":
                  text({font: $self.currentStoryMarkdown})
                else:
                  text({font: "..."})


var main = Main()
var frame = newAppFrame(main, size=(600'ui, 280'ui))
startFiguro(frame)
