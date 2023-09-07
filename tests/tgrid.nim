import std/[math, strformat]

import cssgrid
import figuro/widgets/button
import figuro/widget
import figuro

type
  GridApp = ref object of Figuro
    ## this creates a new ref object type name using the
    ## capitalized proc name which is `ExampleApp` in this example. 
    ## This will be customizable in the future. 
    count: int
    value: float

proc draw*(self: GridApp) {.slot.} =
  # echo "\n\n=================================\n"
  withDraw(self):
    rectangle "main":
      # setWindowBounds(vec2(400, 200), vec2(800, 600))
      fill "#F7F7F9"
      cornerRadius 10
      # box 10, 10, 40, 40

      # Setup CSS Grid Template
      gridTemplateRows  ["edge-t"] auto \
                        ["header"] 70'ux \
                        ["top"]    70'ux \
                        ["middle-top"] 30'ux \ 
                        ["middle"] 30'ux \ 
                        ["bottom"] 1'fr \ 
                        ["footer"] auto \
                        ["edge-b"]

      gridTemplateColumns ["edge-l"]  40'ux \
                          ["button-la", "outer-l"] 150'ux \
                          ["button-lb"] 1'fr \
                          ["inner-m"] 1'fr \
                          ["button-ra"] 150'ux \
                          ["button-rb", "outer-r"] 40'ux \
                          ["edge-r"]

      rectangle "bar":
        gridRow "top" // "middle-top"
        gridColumn "outer-l" // "outer-r"
        fill "#00A0A0"
        # self.value = (self.count.toFloat * 0.10) mod 1.0001
        # box 10, 10, 40, 40

        # ProgressBar:
        #   value: self.value

      rectangle "btn":
        # box 10, 10, 40, 40
        # currently rendering sub-text with css grids
        # is a bit broken due to the order constraints
        # are computed. There's a fix for this 
        # that should simplify this. 
        fill "#0000A0"
        gridRow "middle" // "bottom"
        gridColumn "button-la" // "button-lb"

        button "btn":
          # box 10, 10, 40, 40
          # label fmt"Clicked1: {self.count:4d}"
          # size csAuto(), csAuto()
          fill "#A00000"
          echo "cssize: ", current.cxSize.repr
          # current.cxSize[dcol] = csAuto()
          # current.cxSize[drow] = csAuto()

          # onClick:
          #   self.count.inc()

      button "grid":
        # box 10, 10, 40, 40
        gridRow "middle" // "bottom"
        gridColumn "button-ra" // "button-rb"
        fill "#00A000"
        # label fmt"Clicked2: {self.count:4d}"
        # onClick: self.count.inc()

      gridTemplateDebugLines true

var fig = GridApp.new()

connect(fig, onDraw, fig, GridApp.draw)
connect(fig, onTick, fig, GridApp.tick)

app.width = 480
app.height = 300

startFiguro(fig)
