# Compile with nim c -d:ssl
import figuro/widgets/[button]
import figuro/widgets/[scrollpane, vertical, horizontal]
import figuro/widgets/[input]
import figuro
import cssgrid/prettyprints
import std/terminal

import webhelpers/hnloader

let
  typeface = defaultTypeface()
  font = UiFont(typefaceId: typeface, size: 18)
  smallFont = UiFont(typefaceId: typeface, size: 15)

type
  StoryStatus* = enum
    ssNone
    ssLoading
    ssLoaded
    ssError

  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    loader: AgentProxy[HtmlLoader]
    loading = false
    stories: seq[Submission]
    currentStory: Submission
    markdownStories: Table[Submission, (StoryStatus, string)]


proc htmlLoad*(tp: Main, url: string) {.signal.}
proc markdownLoad*(tp: Main, url: string) {.signal.}

proc loadStories*(self: Main, stories: seq[Submission]) {.slot.} =
  echo "got stories"
  self.stories = stories
  self.loading = false
  refresh(self)

proc loadStoryMarkdown*(self: Main, url: string, markdown: string) {.slot.} =
  echo "got markdown, length: ", markdown.len, " for url: ", url
  for story in self.stories:
    if story.link.href == url:
      self.markdownStories[story] = (ssLoaded, markdown)
      break
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

proc selectNextStory*(self: Main) =
  echo "selectNextStory"
  if self.currentStory == nil:
    self.currentStory = self.stories[0]
    refresh(self)
  else:
    let idx = self.stories.find(self.currentStory)
    self.currentStory = self.stories[clamp(idx + 1, 0, self.stories.len - 1)]
    refresh(self)

proc selectPrevStory*(self: Main) =
  echo "selectPrevStory"
  if self.currentStory == nil:
    self.currentStory = self.stories[0]
    refresh(self)
  else:
    let idx = self.stories.find(self.currentStory)
    self.currentStory = self.stories[clamp(idx - 1, 0, self.stories.len - 1)]
    refresh(self)

proc doKeyPress*(self: Main, pressed: UiButtonView, down: UiButtonView) {.slot.} =
  # echo "\nMain:doKeyCommand: ", " pressed: ", $pressed, " down: ", $down

  if KeyJ in down:
    # echo "J pressed"
    selectNextStory(self)
  elif KeyK in down:
    # echo "K pressed"
    selectPrevStory(self)
  elif KeyEnter in down:
    # echo "Enter pressed"
    if self.currentStory notin self.markdownStories:
      emit self.markdownLoad(self.currentStory.link.href)
      self.markdownStories[self.currentStory] = (ssLoading, "")
    refresh(self)
  else:
    echo "other key pressed: ", $pressed, " ", $down

proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    size 100'pp, 100'pp
    this.listens.signals.incl {evKeyPress}
    connect(this, doKeyPress, self, Main.doKeyPress())

    Rectangle.new "outer":
      with this:
        size 100'pp, 100'pp
        setGridCols ["left"] min(500'ux, 25'pp) \
                    ["middle"] 5'fr \
                    ["right"] 0'ux
        setGridRows ["top"] 70'ux \
                    ["items"] auto \
                    ["bottom"] 40'ux \
                    ["end"] 0'ux
        gridAutoFlow grRow
        justifyItems CxStretch
        alignItems CxStretch

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
            justifyItems CxStretch
            alignItems CxStretch

            for idx, story in self.stories:
              # if idx < 2: continue
              # if idx > 2: break
              capture story, idx:
                Button[Submission].new "story":
                  # size cx"auto", cx"auto"
                  paddingTB 5'ux, 5'ux
                  if self.currentStory == this.state:
                    this.userAttrs.incl Focus
                  else:
                    this.userAttrs.excl Focus

                  this.state = story
                  onSignal(doRightClick) do(this: Button[Submission]):
                    printLayout(this, cmTerminal)

                  onSignal(doSingleClick) do(this: Button[Submission]):
                    echo "HN Story: "
                    echo repr this.state
                    let self = this.queryParent(Main).get()
                    self.currentStory = this.state
                    if self.currentStory notin self.markdownStories:
                      emit self.markdownLoad(self.currentStory.link.href)
                      self.markdownStories[self.currentStory] = (ssLoading, "")
                    refresh(self)

                  Vertical.new "story-fields":
                    contentHeight cx"auto"
                    justifyItems CxStretch
                    alignItems CxStretch

                    Rectangle.new "title-box":
                      # paddingTB 0'ux, 5'ux
                      # paddingLR 0'ux, 20'ux

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
                          setGridCols 20'ux ["upvotes"] 2'fr 5'ux \
                                            ["comments"] 2'fr 5'ux \
                                            ["user"] 2'fr \
                                            ["info"] 15'ux 5'ux
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

                        Text.new "info":
                          gridColumn "info" // span "info"
                          gridRow 1
                          foreground css"black"
                          justify Left
                          align Middle
                          let res = self.markdownStories.getOrDefault(story, (ssNone, ""))
                          case res[0]:
                          of ssNone:
                            text({font: ""})
                          of ssLoading:
                            text({font: "..."})
                          of ssError:
                            text({font: "!"})
                          of ssLoaded:
                            text({font: "+"})

      Rectangle.new "panel":
        gridRow "items" // "bottom"
        gridColumn "middle" // "right"
        cornerRadius 7.0'ux
        # size cx"auto", cx"none"

        Rectangle.new "story-pane":
          size 100'pp, 100'pp
          fill css"black"
          paddingLR 3'ux, 3'ux

          ScrollPane.new "story-scroll":
            offset 0'pp, 0'pp
            cornerRadius 7.0'ux
            size 100'pp, 100'pp
            let scrollPane = this

            Rectangle.new "story-pane-inner":
              fill css"black"
              size 100'pp-scrollPane.settings.size[dcol], cx"max-content"
              paddingLR 10'ux, 20'ux

              Text.new "story-text":
                this.cxSize[dcol] = 100'pp
                # foreground css"white"
                justify Left
                align Top
                let res = self.markdownStories.getOrDefault(self.currentStory, (ssLoading, ""))
                if res[0] == ssLoading:
                  text({font: "..."})
                elif res[0] == ssError:
                  text({font: "!"})
                else:
                  text({font: res[1]})


var main = Main()
var frame = newAppFrame(main, size=(600'ui, 280'ui))
startFiguro(frame)
