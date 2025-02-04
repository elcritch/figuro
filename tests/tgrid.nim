import std/[math, strformat]

import figuro/widgets/button
import figuro

type
  GridApp = ref object of Figuro
    ## this creates a new ref object type name using the
    ## capitalized proc name which is `ExampleApp` in this example. 
    ## This will be customizable in the future. 
    count: int
    value: float

proc draw*(self: GridApp) {.slot.} =
  withWidget(self):
    with this:
      fill clearColor
    rectangle "main":
      # echo "windowSize: ", self.frame[].windowSize
      with this:
        fill css"#D7D7D9"
        cornerRadius 10
        box 10'pp, 10'pp, 80'pp, 80'pp

        # Setup CSS Grid Template
        setGridRows ["edge-t"] 1'fr \
                    ["header"] 70'ux \
                    ["top"]    70'ux \
                    ["middle-top"] 30'ux \
                    ["middle"] 30'ux \
                    ["bottom"] 2'fr \
                    ["footer"] auto \
                    ["edge-b"]

        setGridCols ["edge-l"]  40'ux \
                    ["button-la", "outer-l"] 150'ux \
                    ["button-lb"] 1'fr \
                    ["inner-m"] 1'fr \
                    ["button-ra"] 150'ux \
                    ["button-rb", "outer-r"] 40'ux \
                    ["edge-r"]

      rectangle "bar":
        with this:
          fill css"#1010D0"
          gridRow "top" // "middle-top"
          gridColumn "outer-l" // "outer-r"

      rectangle "btn":
        with this:
          # currently rendering sub-text with css grids
          # is a bit broken due to the order constraints
          # are computed. There's a fix for this 
          # that should simplify this. 
          fill css"#000FC0"
          gridRow "middle" // "bottom"
          gridColumn "button-la" // "button-lb"

        Button.new "btn":
          with this:
            # label fmt"Clicked1: {self.count:4d}"
            # size 100'ux, 30'ux
            size 50'pp, 100'pp
            fill css"#A00000"

          # onClick:
          #   self.count.inc()

      Button.new "grid":
        with this:
          gridRow "middle" // "bottom"
          gridColumn "button-ra" // "button-rb"
          fill css"#00D000"
        # label fmt"Clicked2: {self.count:4d}"
        # onClick: self.count.inc()

      # gridTemplateDebugLines true

var fig = GridApp.new()

fig.cxSize[dcol] = csAuto()
fig.cxSize[drow] = csAuto()
fig.box = initBox(0, 0, 480, 300)

var frame = newAppFrame(fig, size=(480'ui, 300'ui))
startFiguro(frame)
