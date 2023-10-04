
import figuro/widgets/button
import figuro/widget
import figuro

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
    box 0'pp, 0'pp, 100'pp, 100'pp
    rectangle "autoLayout":
      # font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
      box 10'pp, 10'pp, 80'pp, 80'pp
      fill rgb(224, 239, 255).to(Color)

      rectangle "css grid area":
        # if current.gridTemplate != nil:
        #   echo "grid template: ", repr current.gridTemplate
        # setup frame for css grid
        box 5'pp, 5'pp, 90'pp, 90'pp
        # size 100'pp, 100'pp
        fill "#FFFFFF"
        cornerRadius 6
        clipContent true
        
        # Setup CSS Grid Template
        setGridCols 1'fr  1'fr  1'fr  1'fr  1'fr
        # setGridCols 20'pp 20'pp 20'pp 20'pp 20'pp
        setGridRows 1'fr 1'fr
        # setGridRows 40'pp 40'pp
        justifyItems CxCenter

        rectangle "item a":
          # Setup CSS Grid Template
          cornerRadius 3
          gridColumn 1 // 2
          gridRow 1 // 3
          # some color stuff
          fill rgba(245, 129, 49, 123).to(Color)

        for i in 1..4:
          rectangle "items b", captures(i):
            # Setup CSS Grid Template
            cornerRadius 6

            # some color stuff
            fill rgba(66, 177, 44, 167).to(Color).spin(i.toFloat*50)

        rectangle "item e":
          # Setup CSS Grid Template
          cornerRadius 6
          gridColumn 5 // 6
          gridRow 1 // 3
          # some color stuff
          fill rgba(245, 129, 49, 123).to(Color)

        # draw debug lines
        # gridTemplateDebugLines true


var fig = GridApp.new()

connect(fig, doDraw, fig, GridApp.draw)

fig.cxSize[dcol] = csAuto()
fig.cxSize[drow] = csAuto()

app.width = 480
app.height = 300

startFiguro(fig)