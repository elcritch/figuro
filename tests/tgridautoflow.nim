
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
    box 0, 0, 100'vw, 100'vh
    rectangle "autoLayout":
      # font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
      # box 0, 0, 100'vh, 100'vw
      box 10'pw, 10'ph, 80'pw, 80'ph
      fill rgb(224, 239, 255).to(Color)

      rectangle "css grid area":
        # if current.gridTemplate != nil:
        #   echo "grid template: ", repr current.gridTemplate
        # setup frame for css grid
        # box 10, 10, 400, 240
        box 0, 0, 100'pw, 100'ph
        fill "#FFFFFF"
        cornerRadius 3
        clipContent true
        
        # Setup CSS Grid Template
        setGridCols 20'pp 20'pp 20'pp 20'pp 20'pp
        setGridRows 40'pp 40'pp
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
          rectangle "items b", captures(i):
            # Setup CSS Grid Template
            size 20'pp, 20'pp
            cornerRadius 3

            # some color stuff
            fill rgba(66, 177, 44, 167).to(Color).spin(i.toFloat*50)

        rectangle "item e":
          # Setup CSS Grid Template
          size 20'pp, 20'pp
          cornerRadius 3
          gridColumn 5 // 6
          gridRow 1 // 3
          # some color stuff
          fill rgba(245, 129, 49, 123).to(Color)

        # draw debug lines
        # gridTemplateDebugLines true


var fig = GridApp.new()

connect(fig, doDraw, fig, GridApp.draw)
connect(fig, doTick, fig, GridApp.tick)

fig.cxSize[dcol] = csAuto()
fig.cxSize[drow] = csAuto()

app.width = 480
app.height = 300

startFiguro(fig)