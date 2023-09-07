
import figuro/widgets/button
import figuro/widget
import figuro

import print
const hasGaps = false


type
  GridApp = ref object of Figuro
    ## this creates a new ref object type name using the
    ## capitalized proc name which is `ExampleApp` in this example. 
    ## This will be customizable in the future. 
    count: int
    value: float

proc draw*(self: GridApp) {.slot.} =
  withDraw(self):
    rectangle "autoLayout":
      # font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
      box 0, 0, 480, 300
      fill rgb(224, 239, 255).to(Color)

      rectangle "css grid area":
        # if current.gridTemplate != nil:
        #   echo "grid template: ", repr current.gridTemplate
        # setup frame for css grid
        box 10, 10, 400, 240
        fill "#FFFFFF"
        cornerRadius 3
        clipContent true
        
        # Setup CSS Grid Template
        gridTemplateColumns 60'ux 60'ux 60'ux 60'ux 60'ux
        gridTemplateRows 90'ux 90'ux
        justifyContent CxCenter

        rectangle "item a":
          # Setup CSS Grid Template
          cornerRadius 3
          gridColumn 1 // 2
          gridRow 1 // 3
          # some color stuff
          fill rgba(245, 129, 49, 123).to(Color)
          boxSizeOf current.parent

        for i in 1..4:
          rectangle "items b":
            # Setup CSS Grid Template
            size 30'ux, 30'ux
            cornerRadius 3
            
            # some color stuff
            fill rgba(66, 177, 44, 167).to(Color).spin(i.toFloat*50)

        rectangle "item e":
          # Setup CSS Grid Template
          size 30'ux, 30'ux
          cornerRadius 3
          gridColumn 5 // 6
          gridRow 1 // 3
          # some color stuff
          fill rgba(245, 129, 49, 123).to(Color)

        # draw debug lines
        gridTemplateDebugLines true


var fig = GridApp.new()

connect(fig, onDraw, fig, GridApp.draw)
connect(fig, onTick, fig, GridApp.tick)

fig.cxSize[dcol] = csAuto()
fig.cxSize[drow] = csAuto()

app.width = 480
app.height = 300

startFiguro(fig)