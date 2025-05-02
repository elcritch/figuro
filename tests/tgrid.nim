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
  withRootWidget(self):
    size 100'pp, 100'pp
    fill clearColor
    Rectangle.new "main":
      # echo "windowSize: ", self.frame[].windowSize
      fill css"#D7D7D9"
      cornerRadius 10
      box 10'pp, 10'pp, 80'pp, 80'pp

      # Setup CSS Grid Template
      gridRows ["edge-t"] 1'fr \
                  ["header"] 70'ux \
                  ["top"]    70'ux \
                  ["middle-top"] 30'ux \
                  ["middle"] 30'ux \
                  ["bottom"] 2'fr \
                  ["footer"] auto \
                  ["edge-b"]

      gridCols ["edge-l"]  40'ux \
                  ["button-la", "outer-l"] 150'ux \
                  ["button-lb"] 1'fr \
                  ["inner-m"] 1'fr \
                  ["button-ra"] 150'ux \
                  ["button-rb", "outer-r"] 40'ux \
                  ["edge-r"]

      Rectangle.new "bar":
        fill css"#1010D0"
        gridRow "top" // "middle-top"
        gridColumn "outer-l" // "outer-r"

      Rectangle.new "btn":
        fill css"#000FC0"
        gridRow "middle" // "bottom"
        gridColumn "button-la" // "button-lb"

        Button.new "btn":
          size 50'pp, 100'pp
          fill css"#A00000"

      Button.new "grid":
        gridRow "middle" // "bottom"
        gridColumn "button-ra" // "button-rb"
        fill css"#00D000"

      # gridTemplateDebugLines true

var fig = GridApp.new()

fig.cxSize[dcol] = csAuto()
fig.cxSize[drow] = csAuto()
fig.box = initBox(0, 0, 480, 300)

var frame = newAppFrame(fig, size=(480'ui, 300'ui))
startFiguro(frame)
