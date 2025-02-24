
import figuro/widgets/[button, griddebug]
import figuro
import cssgrid/prettyprints

type
  GridApp = ref object of Figuro
    ## this creates a new ref object type name using the
    ## capitalized proc name which is `ExampleApp` in this example. 
    ## This will be customizable in the future. 
    count: int
    value: float

proc draw*(self: GridApp) {.slot.} =
  withRootWidget(self):
    rectangle "autoLayout":
      GridDebug.new "debug-grid":
        this.state = (blackColor, "css grid area")
      # font "IBM Plex Sans", 16, 400, 16, hLeft, vCenter
      with this:
        box 10'pp, 10'pp, 80'pp, 80'pp
        fill rgb(224, 239, 255).to(Color)

      rectangle "css grid area":
        # if current.gridTemplate != nil:
        #   echo "grid template: ", repr current.gridTemplate
        # setup frame for css grid
        box 5'pp, 5'pp, 90'pp, 90'pp
        # size 100'pp, 100'pp
        fill css"#FFFFFF"
        cornerRadius 10
        clipContent true
        
        # Setup CSS Grid Template
        gridCols 1'fr 1'fr 1'fr 1'fr 1'fr
        gridRows 1'fr 1'fr
        justifyItems CxStart

        rectangle "item a":
          # Setup CSS Grid Template
          with this:
            cornerRadius 10
            gridCol 1 // 2
            gridRow 1 // 3
            # some color stuff
            fill rgba(245, 129, 49, 123).to(Color)

        for i in 1..4:
          capture i:
            rectangle "items b":
              # Setup CSS Grid Template
              with this:
                cornerRadius 6
                # some color stuff
                fill rgba(66, 177, 44, 167).to(Color).spin(i.toFloat*50)

        rectangle "item e":
          # Setup CSS Grid Template
          with this:
            cornerRadius 6
            gridCol 5 // 6
            gridRow 1 // 3
            # some color stuff
            fill rgba(245, 129, 49, 123).to(Color)



var fig = GridApp.new()
var frame = newAppFrame(fig, size=(480'ui, 300'ui))
startFiguro(frame)
