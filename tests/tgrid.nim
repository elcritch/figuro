import std/[math, strformat]

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
  frame "main":
    # setWindowBounds(vec2(400, 200), vec2(800, 600))
    fill "#F7F7F9"
    cornerRadius 10

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

      # self.value = (self.count.toFloat * 0.10) mod 1.0001

      # ProgressBar:
      #   value: self.value

    rectangle "btn":
      # currently rendering sub-text with css grids
      # is a bit broken due to the order constraints
      # are computed. There's a fix for this 
      # that should simplify this. 
      gridRow "middle" // "bottom"
      gridColumn "button-la" // "button-lb"

      button "btn", (self):
        # label fmt"Clicked1: {self.count:4d}"
        # size csAuto(), csAuto()
        fill "#A00000"

        # onClick:
        #   self.count.inc()

    button "grid", (self):
      gridRow "middle" // "bottom"
      gridColumn "button-ra" // "button-rb"
      # label fmt"Clicked2: {self.count:4d}"
      # onClick: self.count.inc()
  
    # gridTemplateDebugLines true

var fig = GridApp.new()

connect(fig, onDraw, fig, GridApp.draw)
# connect(fig, onTick, fig, GridApp.tick)

app.width = 480
app.height = 300

startFiguro(fig)
